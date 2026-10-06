# Current State

Documented baseline: 2026-10-06.

## Identity

Repository: `drpeker/NeuroBrain-Online`.

This is the current **online Groq-backed** NeuroBrain. It is not the older local/offline `drpeker/NeuroBrain` project.

## Verified Git baseline

`74802c4` — `Initial NeuroBrain Online working multimodal system`

At that baseline the repository contains:

- `neurobrain.py`
- `neurobrain_modules/camera.py`
- `neurobrain_modules/oled.py`
- `neurobrain_modules/motors.py`
- `.gitignore`

## Host

```text
Raspberry Pi 4 Model B
RAM: 4 GB
OS: Debian 13 (trixie), aarch64
hostname: neurobrain
user: drpeker
current venv: /home/drpeker/oledtest
Python observed in this venv: 3.13.5
```

## Live paths

```text
/home/drpeker/neurobrain.py
/home/drpeker/neurobrain_modules/camera.py
/home/drpeker/neurobrain_modules/oled.py
/home/drpeker/neurobrain_modules/motors.py
```

Git copy:

```text
/home/drpeker/projects/NeuroBrain-Online
```

## Voice pipeline

```text
C270 mic -> arecord -> adaptive VAD -> WAV -> Groq Whisper
-> GPT-OSS -> Edge-TTS -> ffmpeg WAV -> aplay -> analog output
```

Microphone: `hw:1,0`, 16 kHz, mono, S16_LE.

Audio output: `hw:0,0`.

## VAD known-good values

```text
RATE = 16000
CHUNK_MS = 20
SAMPLES = 320
BYTES = 640
CALIBRATION_SEC = 2.0
START_RATIO = 3.0
START_MIN_ABOVE = 180
START_HITS = 5
END_RATIO = 1.7
END_MIN_ABOVE = 80
END_SILENCE_MS = 300
MIN_SPEECH_MS = 300
prebuffer maxlen = 15
```

Startup includes approximately 1 second of microphone AGC warmup followed by 2 seconds of calibration. Noise floor adapts slowly during silence.

## AI models

STT: `whisper-large-v3-turbo`.

Main brain: `openai/gpt-oss-20b`:

```text
temperature = 0.6
max_completion_tokens = 200
reasoning_effort = low
include_reasoning = false
```

Vision: `qwen/qwen3.8-27b`:

```text
temperature = 0.2
max_completion_tokens = 300
reasoning_effort = none
```

## TTS

```text
engine: Edge-TTS
binary: /home/drpeker/oledtest/bin/edge-tts
Turkish: tr-TR-EmelNeural
English: en-US-JennyNeural
MP3: /tmp/neuro_tts.mp3
WAV: /tmp/neuro_tts.wav
```

Automatic language handling is based on Whisper. Do not add a keyword language router merely because of an occasional recognition anomaly.

## Camera

```text
Logitech C270
video: /dev/video0
320x240
requested 30 FPS
buffer size 1
```

`camera.py` owns the only `cv2.VideoCapture(0)`. It continuously stores the latest frame and performs local motion analysis for the OLED eyes.

AI vision is on demand. GPT-OSS receives `get_camera_view` with `tool_choice="auto"`; if it calls the tool, the current frame is sent to Qwen Vision and the returned visual facts are supplied back to GPT-OSS for the final response.

## OLED

```text
SH1106 128x64
I2C address: 0x3C
```

Module states include idle, listening, thinking, speaking, error, plus local motion-directed gaze.

## Motors

`motors.py` exposes left/right forward/reverse and aggregate forward/reverse/stop functions, but hardware actions are intentionally `pass`/inactive. Do not treat this as missing functionality during recovery.

## Critical reliability fix

`groq_with_mic_drain()` executes blocking Groq work in a worker thread while the main thread consumes the continuously running `arecord` pipe. This eliminated ALSA `overrun!!!` during long vision calls. TTS generation/conversion/playback also drains microphone input and includes a short acoustic tail (~0.12 s) to avoid the robot hearing itself.

## Known limitation / next planned change

A moving subject can produce a blurred latest frame. Planned improvement: sample several frames locally, calculate Laplacian sharpness, choose the sharpest, and send **one** JPEG to Qwen. Do not send every frame to the cloud.
