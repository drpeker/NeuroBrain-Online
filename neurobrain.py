import subprocess
import struct
import time
import signal
import sys
import wave
import os
import json
import base64
import threading
from groq import Groq
from collections import deque

from neurobrain_modules.oled import (
    oled_start,
    oled_idle,
    oled_listening,
    oled_thinking,
    oled_speaking,
    oled_error,
    oled_stop,
)

from neurobrain_modules.camera import (
    camera_start,
    camera_stop,
    capture_image,
)

from neurobrain_modules.motors import (
    motor_left_forward,
    motor_left_reverse,
    motor_right_forward,
    motor_right_reverse,
    motors_forward,
    motors_reverse,
    motors_stop,
)

MIC = "hw:1,0"
RATE = 16000

PIPER = "/home/drpeker/neurobrain/venv/bin/piper"
PIPER_TR = "/home/drpeker/neurobrain/tts/tr_TR-dfki-medium.onnx"
PIPER_EN = "/home/drpeker/neurobrain/tts/en_US-lessac-medium.onnx"
TTS_WAV = "/tmp/neuro_tts.wav"

EDGE_TTS = "/home/drpeker/oledtest/bin/edge-tts"
EDGE_VOICE_TR = "tr-TR-EmelNeural"
EDGE_VOICE_EN = "en-US-JennyNeural"
EDGE_MP3 = "/tmp/neuro_tts.mp3"
EDGE_WAV = "/tmp/neuro_tts.wav"



def groq_with_mic_drain(callable_func):
    """
    Bloklayan Groq çağrısını worker thread'de çalıştırır.
    Ana thread bu sırada arecord pipe'ını boşaltır.
    Böylece ALSA overrun oluşmaz.
    """
    result = {}
    error = {}

    def worker():
        try:
            result["value"] = callable_func()
        except Exception as e:
            error["value"] = e

    thread = threading.Thread(target=worker)
    thread.start()

    while thread.is_alive():
        data = proc.stdout.read(BYTES)
        if not data:
            break

    thread.join()

    if "value" in error:
        raise error["value"]

    return result["value"]


def speak(text, language):
    """Edge-TTS üretirken ve çalarken mikrofon pipe'ını sürekli boşalt."""

    if not text or not text.strip():
        print("UYARI: Boş cevap; TTS atlandı.")
        return

    lang = (language or "").lower()

    if lang.startswith("turkish") or lang.startswith("tr"):
        voice = EDGE_VOICE_TR
    else:
        voice = EDGE_VOICE_EN

    oled_speaking()
    print(f"KONUŞUYOR... ({voice})")

    # Edge-TTS'yi arka planda çalıştır.
    # Ana thread bu sırada arecord pipe'ını tüketmeye devam eder.
    tts = subprocess.Popen(
        [
            EDGE_TTS,
            "--voice", voice,
            "--text", text,
            "--write-media", EDGE_MP3
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=False
    )

    while tts.poll() is None:
        data = proc.stdout.read(BYTES)
        if not data:
            break

    _, err = tts.communicate()

    if tts.returncode != 0:
        msg = err.decode(errors="replace").strip() if err else "bilinmeyen hata"
        print("EDGE-TTS HATASI:", msg)
        return

    # MP3 -> WAV
    conv = subprocess.Popen(
        [
            "ffmpeg",
            "-y",
            "-loglevel", "quiet",
            "-i", EDGE_MP3,
            "-ar", "48000",
            "-ac", "2",
            EDGE_WAV
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )

    while conv.poll() is None:
        data = proc.stdout.read(BYTES)
        if not data:
            break

    conv.wait()

    if conv.returncode != 0:
        print("FFMPEG HATASI: TTS sesi dönüştürülemedi.")
        return

    # Ses çalarken de mikrofonu VAD'a vermeden tüket.
    player = subprocess.Popen(
        ["aplay", "-q", "-D", "hw:0,0", EDGE_WAV],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )

    while player.poll() is None:
        data = proc.stdout.read(BYTES)
        if not data:
            break

    player.wait()

    # Hoparlörün çok kısa akustik kuyruğunu at.
    tail_end = time.monotonic() + 0.12
    while time.monotonic() < tail_end:
        proc.stdout.read(BYTES)



CHUNK_MS = 20
SAMPLES = RATE * CHUNK_MS // 1000
BYTES = SAMPLES * 2

# VAD ayarları
CALIBRATION_SEC = 2.0

# Konuşma başlaması için:
START_RATIO = 3.0
START_MIN_ABOVE = 180
START_HITS = 5          # 5 x 20 ms = 100 ms

# Konuşma bittikten sonra:
END_RATIO = 1.7
END_MIN_ABOVE = 80
END_SILENCE_MS = 300

# Çok kısa tetiklemeleri konuşma sayma:
MIN_SPEECH_MS = 300

proc = None
client = Groq(api_key=os.environ["GROQ_API_KEY"])


# ============================================================
# NEUROBRAIN CAMERA TOOL
# ============================================================

CAMERA_TOOL = {
    "type": "function",
    "function": {
        "name": "get_camera_view",
        "description": (
            "Look through NeuroBrain's physical camera when current visual "
            "information from the robot's surroundings would help answer the "
            "user. You may use this tool on your own initiative. The user does "
            "not need to explicitly say camera, look, see, or similar words. "
            "Use it for questions involving visible objects, people, text, "
            "screens, LEDs, connections, colors, positions, quantities, "
            "appearance, damage, surroundings, or anything else that requires "
            "seeing the robot's current environment. Do not use it for ordinary "
            "knowledge, conversation, calculations, coding, or questions that "
            "do not require current visual information."
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "question": {
                    "type": "string",
                    "description": (
                        "What visual information should be determined from "
                        "the current camera view."
                    )
                }
            },
            "required": ["question"]
        }
    }
}


def get_camera_view(question):
    """Inspect the robot's current camera frame using Groq Vision."""

    print(f"KAMERAYA BAKIYOR... [{question}]")

    image_path = capture_image("/tmp/neurobrain_camera.jpg")

    with open(image_path, "rb") as f:
        image_b64 = base64.b64encode(f.read()).decode("ascii")

    vision = groq_with_mic_drain(
        lambda: client.chat.completions.create(
        model="qwen/qwen3.8-27b",
        messages=[
            {
                "role": "system",
                "content": (
                    "You are NeuroBrain's visual perception system. "
                    "Analyze only what is actually supported by the current "
                    "camera image. Do not invent objects or details. "
                    "If something cannot be determined reliably, say so. "
                    "Return concise but sufficiently detailed visual "
                    "information to NeuroBrain's main reasoning model."
                )
            },
            {
                "role": "user",
                "content": [
                    {
                        "type": "text",
                        "text": question
                    },
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": "data:image/jpeg;base64," + image_b64
                        }
                    }
                ]
            }
        ],
        temperature=0.2,
        max_completion_tokens=300,
        reasoning_effort="none"
        )
    )

    result = vision.choices[0].message.content.strip()

    print(f"GÖRÜNTÜ ALGILANDI: {result}")

    return result


def rms(data):
    if not data:
        return 0

    n = len(data) // 2
    samples = struct.unpack("<%dh" % n, data)

    return int(
        (sum(s * s for s in samples) / max(n, 1)) ** 0.5
    )


def stop(*_):
    global proc

    print("\n\nNeuroBrain durduruluyor...")

    try:
        motors_stop()
    except Exception:
        pass

    try:
        camera_stop()
    except Exception:
        pass

    try:
        oled_stop()
    except Exception:
        pass

    if proc:
        try:
            proc.terminate()
            proc.wait(timeout=0.5)
        except:
            try:
                proc.kill()
            except:
                pass

    sys.exit(0)


signal.signal(signal.SIGINT, stop)
signal.signal(signal.SIGTERM, stop)


print("\n=== NeuroBrain Voice ===")
print("VAD + Whisper + NeuroBrain hazır.")
print("Ctrl+C ile çıkış.\n")

print("OLED başlatılıyor...")
oled_start()
oled_idle()

print("Kamera başlatılıyor...")
camera_start()

proc = subprocess.Popen(
    [
        "arecord",
        "-q",
        "-D", MIC,
        "-f", "S16_LE",
        "-r", str(RATE),
        "-c", "1",
        "-t", "raw"
    ],
    stdout=subprocess.PIPE,
    bufsize=0
)

# --------------------------------------------------
# 1. ORTAM GÜRÜLTÜSÜNÜ ÖLÇ
# --------------------------------------------------

print("Mikrofon AGC hazırlanıyor...")

# İlk saniyeyi çöpe at
warmup_end = time.monotonic() + 1.0
while time.monotonic() < warmup_end:
    proc.stdout.read(BYTES)

print("2 saniye sessiz kalın. Ortam ölçülüyor...")

levels = []

end_time = time.monotonic() + CALIBRATION_SEC

while time.monotonic() < end_time:
    data = proc.stdout.read(BYTES)

    if len(data) != BYTES:
        continue

    levels.append(rms(data))

levels.sort()

# En yüksek ani sesleri kalibrasyondan dışla.
if levels:
    noise = levels[int(len(levels) * 0.60)]
else:
    noise = 100

noise = max(noise, 30)

print(f"\nNoise floor : {noise}")
print("Hazır. Normal şekilde konuşun.\n")


# --------------------------------------------------
# 2. ADAPTİF VAD
# --------------------------------------------------

speaking = False
start_hits = 0
silent_ms = 0
speech_ms = 0
recording = []

# Noise floor'u yalnızca sessizlikte yavaşça güncelle.
noise_history = deque(maxlen=100)
prebuffer = deque(maxlen=15)

while True:

    data = proc.stdout.read(BYTES - 0)

    while len(data) < BYTES:
        more = proc.stdout.read(BYTES - len(data))
        if not more:
            break
        data += more

    if len(data) != BYTES:
        continue

    level = rms(data)

    if not speaking:
        prebuffer.append(data)

    start_threshold = max(
        noise * START_RATIO,
        noise + START_MIN_ABOVE
    )

    end_threshold = max(
        noise * END_RATIO,
        noise + END_MIN_ABOVE
    )

    if not speaking:

        # Gürültü tabanını sadece threshold altındayken öğren.
        if level < start_threshold:
            noise_history.append(level)

            if len(noise_history) >= 20:
                sorted_noise = sorted(noise_history)
                target = sorted_noise[len(sorted_noise) // 2]

                # Çok yavaş adaptasyon
                noise = int(noise * 0.98 + target * 0.02)

        if level >= start_threshold:
            start_hits += 1
        else:
            start_hits = 0

        if start_hits >= START_HITS:
            speaking = True
            recording = list(prebuffer)
            speech_ms = START_HITS * CHUNK_MS
            silent_ms = 0
            start_hits = 0

            oled_listening()

            print(
                f"VOICE START   "
                f"(level={level}, threshold={int(start_threshold)})"
            )

    else:

        recording.append(data)
        speech_ms += CHUNK_MS

        if level < end_threshold:
            silent_ms += CHUNK_MS
        else:
            silent_ms = 0

        if silent_ms >= END_SILENCE_MS:

            actual_ms = speech_ms - silent_ms

            if actual_ms >= MIN_SPEECH_MS:
                oled_thinking()

                print(
                    f"VOICE END     "
                    f"({actual_ms/1000:.2f} sec)"
                )

                with wave.open("/tmp/neuro_speech.wav", "wb") as wf:
                    wf.setnchannels(1)
                    wf.setsampwidth(2)
                    wf.setframerate(RATE)
                    wf.writeframes(b"".join(recording))

                print("KAYDEDİLDİ: /tmp/neuro_speech.wav")

                # -------------------------------
                # WHISPER: otomatik TR / EN
                # -------------------------------
                try:
                    print("ANLIYOR...")

                    with open("/tmp/neuro_speech.wav", "rb") as audio:
                        stt = client.audio.transcriptions.create(
                            file=audio,
                            model="whisper-large-v3-turbo",
                            response_format="verbose_json"
                        )

                    user_text = stt.text.strip()
                    language = stt.language

                    print(f"DİL       : {language}")
                    print(f"SEN       : {user_text}")

                    # -------------------------------
                    # GPT
                    # -------------------------------
                    print("DÜŞÜNÜYOR...")

                    messages = [
                        {
                            "role": "system",
                            "content": """Your name is NeuroBrain.
You are a small, cheerful, friendly and natural conversational robot.

You have a physical camera available through the get_camera_view tool.

Use the camera tool whenever current visual information from your physical surroundings would materially help answer the user. You may decide to look through the camera on your own initiative. The user does not need to explicitly ask you to use the camera.

Do not claim to see the physical environment unless you have actually called the camera tool for the current request.

If the request refers implicitly to something physically present, visible, being held, shown, displayed, connected, illuminated, positioned, written, or happening around you, use your camera when useful.

Do not use the camera unnecessarily for ordinary conversation, general knowledge, calculations, coding, or other questions answerable without seeing the current environment.

Never invent current sensor, visual, weather, location, or environmental information.

If the user asks your name, clearly say that your name is NeuroBrain.
If the user speaks Turkish, reply in Turkish.
If the user speaks English, reply in English.
Keep answers short, natural and conversational.
Do not address the user by name or title.
Do not introduce yourself unless relevant or asked.
Silently infer and correct obvious minor speech-recognition errors from context."""
                        },
                        {
                            "role": "user",
                            "content":
                                f"Algılanan dil: {language}\nKullanıcı: {user_text}"
                        }
                    ]

                    reply = groq_with_mic_drain(
                        lambda: client.chat.completions.create(
                        model="openai/gpt-oss-20b",
                        messages=messages,
                        tools=[CAMERA_TOOL],
                        tool_choice="auto",
                        temperature=0.6,
                        max_completion_tokens=200,
                        reasoning_effort="low",
                        include_reasoning=False
                        )
                    )

                    assistant_message = reply.choices[0].message

                    # GPT-OSS kamerayı kullanmak isterse:
                    if assistant_message.tool_calls:

                        messages.append(assistant_message)

                        for tool_call in assistant_message.tool_calls:

                            if tool_call.function.name == "get_camera_view":

                                args = json.loads(
                                    tool_call.function.arguments or "{}"
                                )

                                question = args.get(
                                    "question",
                                    "Describe the current camera view."
                                )

                                visual_result = get_camera_view(question)

                                messages.append(
                                    {
                                        "role": "tool",
                                        "tool_call_id": tool_call.id,
                                        "name": "get_camera_view",
                                        "content": visual_result
                                    }
                                )

                        # Kamera sonucunu gördükten sonra nihai cevabı üret.
                        final_reply = groq_with_mic_drain(
                            lambda: client.chat.completions.create(
                            model="openai/gpt-oss-20b",
                            messages=messages,
                            tools=[CAMERA_TOOL],
                            tool_choice="none",
                            temperature=0.6,
                            max_completion_tokens=200,
                            reasoning_effort="low",
                            include_reasoning=False
                            )
                        )

                        answer = final_reply.choices[0].message.content.strip()

                    else:

                        answer = assistant_message.content.strip()

                    print(f"NEUROBRAIN: {answer}\n")

                    # Robot konuşurken ana döngü burada bekler.
                    # Bu sırada VAD mikrofon verisini işlemez.
                    speak(answer, language)
                    oled_idle()

                    # Robotun sesinden kalan VAD durumunu temizle.
                    prebuffer.clear()
                    start_hits = 0
                    silent_ms = 0

                    print("DİNLİYOR...\n")

                except Exception as e:
                    oled_error()
                    print(f"GROQ HATASI: {e}\n")
                    time.sleep(0.5)
                    oled_idle()
                print(
                    f"Noise={noise} | "
                    f"Start={int(start_threshold)} | "
                    f"End={int(end_threshold)}\n"
                )
            else:
                print(
                    f"IGNORED       "
                    f"({actual_ms/1000:.2f} sec)\n"
                )

            speaking = False
            speech_ms = 0
            silent_ms = 0
