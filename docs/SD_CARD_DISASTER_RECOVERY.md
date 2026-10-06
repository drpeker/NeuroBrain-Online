# SD Card Disaster Recovery

## Scenario

Assume all of the following are gone:

- Raspberry Pi SD card
- `/home/drpeker` contents
- virtual environments
- installed packages
- local checkpoints
- all ChatGPT conversations

Assume only these remain:

- Raspberry Pi 4 hardware
- C270 camera/microphone
- SH1106 OLED and wiring
- other robot hardware
- GitHub repository `drpeker/NeuroBrain-Online`
- access to a valid Groq API key

The purpose of this repository is to make that scenario recoverable.

## Phase A — rebuild the host

Install a current 64-bit Raspberry Pi OS/Debian-compatible system. The known system was Debian 13 trixie aarch64.

Create/use user `drpeker` and hostname `neurobrain` if reproducing the original layout exactly.

Update packages:

```bash
sudo apt update
sudo apt upgrade -y
```

Install recovery dependencies:

```bash
sudo apt install -y \
  git \
  python3-venv \
  python3-pip \
  python3-opencv \
  alsa-utils \
  ffmpeg \
  i2c-tools \
  v4l-utils
```

Enable I2C using the current Raspberry Pi OS configuration mechanism and reboot if necessary.

## Phase B — verify hardware before application software

### Camera

```bash
v4l2-ctl --list-devices
ls -l /dev/video*
```

The original C270 camera was `/dev/video0`.

### Microphone and speaker

```bash
arecord -l
aplay -l
```

The original configuration used:

```text
C270 microphone: hw:1,0
analog playback: hw:0,0
```

ALSA card numbers can change after reinstall. If they differ, identify the correct C270 and analog devices rather than assuming the old numbers.

Record test:

```bash
arecord -D hw:1,0 -f S16_LE -r 16000 -c 1 -d 5 /tmp/mic.wav
aplay /tmp/mic.wav
```

### OLED

```bash
i2cdetect -y 1
```

Expected SH1106 address: `0x3C`.

## Phase C — recover Git repository

```bash
mkdir -p ~/projects
cd ~/projects
git clone https://github.com/drpeker/NeuroBrain-Online.git
cd NeuroBrain-Online
git log --oneline --decorate -10
```

Known initial working online commit:

```text
74802c4 Initial NeuroBrain Online working multimodal system
```

Do not clone `drpeker/NeuroBrain` by mistake. That is a different project.

## Phase D — rebuild Python environment

Preserve the original venv path:

```bash
python3 -m venv --system-site-packages ~/oledtest
source ~/oledtest/bin/activate
python -m pip install --upgrade pip
python -m pip install -r ~/projects/NeuroBrain-Online/requirements.txt
```

Verify imports:

```bash
python - <<'PY'
import cv2
import groq
import luma.core
import luma.oled
print("Core Python imports OK")
PY
```

Verify Edge-TTS:

```bash
~/oledtest/bin/edge-tts --help >/dev/null && echo "Edge-TTS OK"
```

## Phase E — restore the secret

Obtain/create a valid Groq API key and export it externally:

```bash
export GROQ_API_KEY="YOUR_GROQ_API_KEY"
```

Never add the key to Git, `.py`, README, shell script or documentation.

## Phase F — recreate live runtime

```bash
cp ~/projects/NeuroBrain-Online/neurobrain.py ~/neurobrain.py
cp -a ~/projects/NeuroBrain-Online/neurobrain_modules ~/neurobrain_modules
```

Compile before running:

```bash
python -m py_compile \
  ~/neurobrain.py \
  ~/neurobrain_modules/camera.py \
  ~/neurobrain_modules/oled.py \
  ~/neurobrain_modules/motors.py
```

## Phase G — understand the expected behavior before troubleshooting

On startup the expected architecture is:

1. OLED starts.
2. Camera manager starts and owns `/dev/video0`.
3. `arecord` starts on the configured microphone.
4. microphone receives AGC warmup.
5. VAD calibrates ambient noise.
6. robot waits for speech.
7. speech is transcribed by Groq Whisper.
8. GPT-OSS produces a response or autonomously requests camera vision.
9. if camera requested, one current frame goes to Qwen Vision and visual facts return to GPT.
10. Edge-TTS generates Turkish or English speech.
11. robot drains microphone input while speaking so it does not trigger itself.
12. Ctrl+C cleanly stops motors, camera, OLED and `arecord`.

## Phase H — run

```bash
source ~/oledtest/bin/activate
export GROQ_API_KEY="YOUR_GROQ_API_KEY"
python ~/neurobrain.py
```

## Phase I — acceptance tests

A recovered system is not accepted merely because Python starts.

Verify all of these:

- OLED eyes animate.
- Camera remains continuously available.
- Local motion moves OLED gaze.
- VAD waits quietly in room noise.
- Turkish speech transcribes correctly.
- English speech transcribes correctly.
- response language follows user language.
- Edge-TTS speaks with Emel/Jenny voices.
- robot does not immediately hear its own speech as a new command.
- ordinary knowledge questions do not unnecessarily invoke camera vision.
- an implicit visual question can cause GPT to call `get_camera_view`.
- GPT does not claim current sight when the camera was not called.
- long vision calls do not produce `ALSA overrun!!!`.
- Ctrl+C exits cleanly.
- motor functions remain physically inactive until deliberately implemented.

## Critical known-good constants

### VAD

```text
RATE 16000
CHUNK_MS 20
SAMPLES 320
BYTES 640
CALIBRATION_SEC 2.0
START_RATIO 3.0
START_MIN_ABOVE 180
START_HITS 5
END_RATIO 1.7
END_MIN_ABOVE 80
END_SILENCE_MS 300
MIN_SPEECH_MS 300
prebuffer 15 chunks
```

### Models

```text
STT: whisper-large-v3-turbo
Brain: openai/gpt-oss-20b
Vision: qwen/qwen3.8-27b
TR TTS: tr-TR-EmelNeural
EN TTS: en-US-JennyNeural
```

### GPT settings

```text
temperature 0.6
max_completion_tokens 200
reasoning_effort low
include_reasoning false
```

### Vision settings

```text
temperature 0.2
max_completion_tokens 300
reasoning_effort none
```

### Camera

```text
/dev/video0
320x240
30 FPS requested
buffer 1
```

### OLED

```text
SH1106
128x64
0x3C
```

## What must NOT be reconstructed from guesswork

Do not invent:

- motor GPIO pin numbers
- new OLED wiring
- alternate model names
- a different TTS voice
- a keyword-based camera router
- hard-coded API credentials
- a second camera owner

If a detail is absent from Git and cannot be measured from hardware, mark it unknown and recover it experimentally rather than fabricating it.

## Final principle

The repository is the engineering memory. After every physically verified architectural change, update the source and these documents in the same development cycle.
