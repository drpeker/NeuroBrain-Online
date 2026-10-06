#!/usr/bin/env bash
set -euo pipefail

REPO="${1:-$HOME/projects/NeuroBrain-Online}"
cd "$REPO"
mkdir -p docs

cat > README.md <<'EOF'
# NeuroBrain Online

NeuroBrain Online is the current Groq-backed multimodal robot system running on a Raspberry Pi 4.

> **Repository identity:** `drpeker/NeuroBrain-Online`
>
> This repository is completely separate from the older `drpeker/NeuroBrain` local/offline experimental project. Never mix their source trees, Git histories, recovery instructions, or runtime assumptions.

## Known working baseline

Initial verified checkpoint: `74802c4` — **Initial NeuroBrain Online working multimodal system**.

Current architecture includes Raspberry Pi 4 local hardware control, adaptive VAD, Logitech C270 microphone/camera, Groq Whisper STT, GPT-OSS main reasoning, model-selected camera access, Qwen Vision, Edge-TTS, SH1106 animated OLED eyes, continuous local motion tracking, and an intentionally inactive motor API.

## High-level architecture

```text
Human speech
   |
C270 microphone -> arecord/VAD -> Groq Whisper
   |                              |
   |                              v
   |                         GPT-OSS-20B
   |                              |
   |                 +------------+------------+
   |                 |                         |
   |            normal answer          get_camera_view
   |                                           |
   |                                     camera.py
   |                                           |
   |                                     current frame
   |                                           |
   |                                    Qwen Vision 27B
   |                                           |
   |                                      visual facts
   |                                           |
   +-------------------------------------------+
                                               |
                                         GPT final answer
                                               |
                                           Edge-TTS
                                               |
                                            speaker

C270 camera -> camera.py -> local motion -> oled.py -> SH1106 eyes
                    |
                    +-> latest frame for AI vision only when requested
```

The camera remains locally open for motion tracking but is **not continuously uploaded**. GPT-OSS decides when current visual information is useful and may call `get_camera_view` on its own initiative.

## Repository layout

```text
NeuroBrain-Online/
├── neurobrain.py
├── neurobrain_modules/
│   ├── camera.py
│   ├── oled.py
│   └── motors.py
├── docs/
│   ├── CURRENT_STATE.md
│   ├── ARCHITECTURE.md
│   ├── SYSTEM_DIAGRAMS.md
│   ├── HARDWARE.md
│   ├── MODELS.md
│   ├── INSTALL.md
│   ├── RECOVERY.md
│   ├── DESIGN_DECISIONS.md
│   ├── SOFTWARE_INVENTORY.md
│   ├── AUDIO_PIPELINE.md
│   ├── CAMERA_VISION.md
│   └── SD_CARD_DISASTER_RECOVERY.md
├── requirements.txt
├── install_neurobrain_online_project_memory.sh
└── .gitignore
```

## Runtime versus Git

Known live runtime:

```text
/home/drpeker/neurobrain.py
/home/drpeker/neurobrain_modules/
```

Known Python environment:

```text
/home/drpeker/oledtest/
```

Git working copy:

```text
/home/drpeker/projects/NeuroBrain-Online/
```

This separation is deliberate. A Git operation must not casually overwrite a physically verified robot.

## Recovery reading order

If all ChatGPT conversations are lost, read:

1. `docs/SD_CARD_DISASTER_RECOVERY.md`
2. `docs/CURRENT_STATE.md`
3. `docs/SYSTEM_DIAGRAMS.md`
4. `docs/ARCHITECTURE.md`
5. `docs/HARDWARE.md`
6. `docs/SOFTWARE_INVENTORY.md`
7. `docs/MODELS.md`
8. `docs/AUDIO_PIPELINE.md`
9. `docs/CAMERA_VISION.md`
10. `docs/INSTALL.md`
11. `docs/RECOVERY.md`
12. `docs/DESIGN_DECISIONS.md`

## Golden rules

1. Never mix `NeuroBrain` and `NeuroBrain-Online`.
2. `main` should represent a physically verified working baseline.
3. Never commit `GROQ_API_KEY` or other secrets.
4. `camera.py` is the single owner of the physical camera.
5. Never claim current physical sight without a current camera-tool result.
6. Preserve microphone draining around blocking cloud/TTS operations.
7. Keep motors inactive until deterministic safety logic is physically tested.
8. Preserve recovery information before cosmetic refactoring.
9. Test on the actual Pi before promoting risky changes to `main`.
10. A working physical robot is more important than a cleaner source tree.
EOF

cat > docs/CURRENT_STATE.md <<'EOF'
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
EOF

cat > docs/ARCHITECTURE.md <<'EOF'
# Architecture

## Responsibility split

The Raspberry Pi owns real-time physical I/O and lifecycle management. Cloud models provide speech recognition, reasoning and visual interpretation.

### Local Pi responsibilities

- continuous microphone process
- VAD and noise calibration
- WAV capture
- camera ownership
- frame buffering
- local motion detection
- OLED animation
- TTS process orchestration
- audio playback
- GPIO/motor boundary
- clean shutdown
- microphone-pipe draining

### Groq responsibilities

- Whisper STT
- GPT-OSS conversation/reasoning/tool selection
- Qwen visual perception

## End-to-end flow

```text
SPEECH
  |
  v
C270 microphone
  |
  v
arecord hw:1,0
  |
  v
adaptive VAD
  |
  v
speech WAV
  |
  v
whisper-large-v3-turbo
  |
  v
transcript + language
  |
  v
openai/gpt-oss-20b
  |
  +---- no visual context needed ----> final text
  |
  +---- visual context useful
            |
            v
      get_camera_view
            |
            v
       camera manager
            |
            v
       current JPEG
            |
            v
     qwen/qwen3.8-27b
            |
            v
       grounded facts
            |
            v
       GPT-OSS second pass
            |
            v
          final text
            |
            v
         Edge-TTS
            |
            v
          speaker
```

## Camera ownership rule

Exactly one long-lived component should open `/dev/video0`: `neurobrain_modules/camera.py`.

Vision requests consume a snapshot from the manager. They must not create a second `VideoCapture(0)` while the manager is running.

## Sensory tool philosophy

Camera access is a model-selected tool rather than a hard-coded phrase router. GPT-OSS may decide to look when a request implicitly depends on something physically visible, held, displayed, positioned, illuminated or occurring around the robot.

The main system prompt must also prohibit claims of physical sight unless the camera tool was actually called for the current request.

## Concurrency

Long network operations must not block consumption of the `arecord` stdout pipe. `groq_with_mic_drain()` therefore moves the blocking network operation to a worker thread while the main thread drains PCM data.

This architecture is intentional, not merely an optimization.

## Hardware action boundary

Language-model reasoning should not directly become unrestricted motor GPIO commands. The current motor API is deliberately inactive until a deterministic local action/safety layer is designed and physically tested.
EOF

cat > docs/HARDWARE.md <<'EOF'
# Hardware

## Computer

- Raspberry Pi 4 Model B
- 4 GB RAM
- aarch64
- Debian 13 trixie

## Logitech C270

Used for both camera and microphone.

Known devices:

```text
video: /dev/video0
ALSA microphone: hw:1,0
```

Direct microphone test:

```bash
arecord -D hw:1,0 -f S16_LE -r 16000 -c 1 -d 5 /tmp/mic.wav
```

## Audio output

Known playback device:

```text
hw:0,0
```

Test example:

```bash
aplay -D hw:0,0 /tmp/test.wav
```

## OLED

```text
controller: SH1106
resolution: 128x64
I2C address: 0x3C
```

Check I2C after installing `i2c-tools`:

```bash
i2cdetect -y 1
```

Expected visible address: `3c`.

## Camera configuration

The current camera manager requests:

```text
320 x 240
30 FPS
buffer size = 1
```

Local motion algorithm derives from the previously verified motion-eyes implementation:

- MOG2 history 100
- varThreshold 30
- shadows disabled
- analysis resized to 160x120
- Gaussian blur 5x5
- contour area threshold >120
- largest moving object drives gaze
- approximate eye target limits x ±16, y ±12
- idle random movement approximately x ±10, y ±7
- smoothing approximately 0.75
- blink interval approximately 3–6 s

## Motor driver

Planned/available driver: MX1508 dual DC motor driver (2 x 1.5 A class).

No GPIO pin mapping is declared here because the current known-good online source intentionally leaves motor-driving functions inactive. Do not invent pin assignments during disaster recovery.
EOF

cat > docs/MODELS.md <<'EOF'
# Models and AI Services

## Provider

Current online AI provider: **Groq / GroqCloud**.

The secret is supplied through the environment:

```bash
export GROQ_API_KEY="..."
```

Never place the actual key in Git.

## Speech-to-text

```text
whisper-large-v3-turbo
```

Responsibilities:

- speech transcription
- automatic language detection

## Main brain

```text
openai/gpt-oss-20b
```

Known settings:

```text
temperature = 0.6
max_completion_tokens = 200
reasoning_effort = low
include_reasoning = false
```

Responsibilities:

- conversation
- reasoning
- same-language replies
- silent correction of obvious minor STT errors from context
- deciding whether the camera is useful
- tool invocation
- integrating visual facts into the final response

## Vision specialist

```text
qwen/qwen3.8-27b
```

Known settings:

```text
temperature = 0.2
max_completion_tokens = 300
reasoning_effort = none
```

Vision should describe only information supported by the current image and state uncertainty instead of inventing details.

## TTS

Current active system: Edge-TTS.

```text
Turkish voice: tr-TR-EmelNeural
English voice: en-US-JennyNeural
```

Known executable:

```text
/home/drpeker/oledtest/bin/edge-tts
```

Legacy Piper constants/models may remain in historical source but are not the active TTS path of this baseline.

## Local models are not part of the active online chain

Historical local GGUF models on the former SD card included Qwen and Phi variants, but the current online runtime does not depend on them. In particular, `qwen/qwen3.8-27b` is a Groq cloud vision model, not a model stored on the Pi.
EOF

cat > docs/AUDIO_PIPELINE.md <<'EOF'
# Audio Pipeline

## Capture

Known microphone:

```text
ALSA device: hw:1,0
format: S16_LE
rate: 16000 Hz
channels: 1
```

The runtime keeps `arecord` alive and reads exact 20 ms PCM chunks.

Known robust chunk-read pattern:

```python
data = proc.stdout.read(BYTES - 0)
while len(data) < BYTES:
    more = proc.stdout.read(BYTES - len(data))
    if not more:
        break
    data += more
if len(data) != BYTES:
    continue
```

Do not replace this casually with a single read and assume the requested byte count always arrives.

## VAD

Known-good values are recorded in `CURRENT_STATE.md`.

The design uses:

1. microphone AGC warmup
2. room-noise calibration
3. speech start thresholds requiring repeated hits
4. prebuffer so initial phonemes are retained
5. silence duration to terminate utterance
6. slow noise-floor adaptation while silent

## Self-hearing prevention

While the robot generates and plays its own TTS, microphone PCM is drained/discarded. After playback there is a short acoustic-tail interval (~0.12 s) before normal listening resumes.

## ALSA overrun prevention

A blocking Groq request cannot be allowed to leave the `arecord` stdout pipe unread.

Known solution:

```text
Groq call
   |
worker thread ------> network
   |
main thread --------> continuously drains microphone pipe
```

Implemented by `groq_with_mic_drain()`.

This was physically verified to eliminate the observed `overrun!!!` during long vision operations.
EOF

cat > docs/CAMERA_VISION.md <<'EOF'
# Camera and Vision

## Camera manager

Module: `neurobrain_modules/camera.py`.

Public API includes:

```text
camera_start()
capture_image(filename="/tmp/neurobrain_camera.jpg")
get_latest_frame()
camera_stop()
```

The manager continuously owns the C270 camera, stores the latest frame and performs local motion analysis.

## OLED motion path

```text
camera frame
   |
local motion analysis
   |
(x,y target)
   |
set_motion(...)
   |
OLED eyes
```

This path is local and does not consume cloud vision tokens.

## AI camera tool

Tool name:

```text
get_camera_view
```

GPT-OSS receives the tool with automatic tool selection. The user does not need to say an explicit camera keyword.

If GPT requests vision:

1. parse tool arguments, including its visual question
2. call local `get_camera_view(question)`
3. capture the current managed frame
4. base64 encode the JPEG
5. send it to `qwen/qwen3.8-27b`
6. return concise grounded visual facts as tool output
7. call GPT-OSS again with the tool result and `tool_choice="none"`
8. speak the final answer

## Grounding rule

GPT-OSS must not claim to see the current physical environment unless the camera tool was actually invoked for that request.

Qwen Vision must not invent unsupported objects or details.

## Known limitation

The latest frame can be blurred if the subject or camera is moving.

Planned improvement:

```text
vision requested
  |
sample 3-5 local frames
  |
Laplacian variance sharpness score
  |
select sharpest
  |
send ONE JPEG to Qwen
```

This improves input quality without continuously streaming frames or multiplying cloud-image calls.
EOF

cat > docs/SOFTWARE_INVENTORY.md <<'EOF'
# Software Inventory

This file distinguishes verified runtime facts from packages that may need to be reinstalled after SD-card loss.

## Verified host facts

```text
Debian 13 trixie aarch64
Python environment: /home/drpeker/oledtest
Python observed: 3.13.5
```

## Python functionality required by source

The current source requires the functionality provided by:

- `groq`
- OpenCV (`cv2`; on Raspberry Pi preferably install Debian `python3-opencv` first)
- `luma.core`
- `luma.oled`
- Edge-TTS

Standard-library modules are not listed as pip requirements.

## System commands used by runtime

- `arecord` / ALSA utilities
- `aplay`
- `ffmpeg`
- camera/V4L2 support
- I2C support

Useful recovery packages:

```text
alsa-utils
ffmpeg
python3-venv
python3-pip
python3-opencv
i2c-tools
v4l-utils
git
```

Package names can evolve between Debian releases; if one is unavailable, use the current Debian equivalent rather than changing application architecture.

## Source of truth

The checked-in Python source is authoritative for imports and runtime behavior. After cloning on a new SD card, inspect imports before adding unnecessary dependencies.
EOF

cat > requirements.txt <<'EOF'
groq
edge-tts
luma.core
luma.oled
EOF

cat > docs/INSTALL.md <<'EOF'
# Installation

This is the normal reconstruction procedure for the known Raspberry Pi architecture. For complete SD-card loss, start with `SD_CARD_DISASTER_RECOVERY.md`.

## 1. OS

Use a current 64-bit Raspberry Pi OS/Debian-compatible installation. The known working host was Debian 13 trixie aarch64 on Raspberry Pi 4 4 GB.

## 2. System packages

Example:

```bash
sudo apt update
sudo apt install -y git python3-venv python3-pip python3-opencv alsa-utils ffmpeg i2c-tools v4l-utils
```

Enable I2C using the Raspberry Pi configuration mechanism appropriate to the installed OS, then reboot if required.

## 3. Clone

```bash
mkdir -p ~/projects
cd ~/projects
git clone git@github.com:drpeker/NeuroBrain-Online.git
cd NeuroBrain-Online
```

HTTPS may be used instead if SSH has not yet been configured.

## 4. Virtual environment

To preserve the known path:

```bash
python3 -m venv --system-site-packages ~/oledtest
source ~/oledtest/bin/activate
python -m pip install --upgrade pip
python -m pip install -r ~/projects/NeuroBrain-Online/requirements.txt
```

`--system-site-packages` permits the venv to use Debian's `python3-opencv` package.

## 5. Hardware checks

Camera:

```bash
v4l2-ctl --list-devices
ls -l /dev/video0
```

Audio:

```bash
arecord -l
aplay -l
arecord -D hw:1,0 -f S16_LE -r 16000 -c 1 -d 5 /tmp/mic.wav
aplay /tmp/mic.wav
```

OLED:

```bash
i2cdetect -y 1
```

Expected OLED address: `0x3C`.

## 6. Groq secret

Set outside Git:

```bash
export GROQ_API_KEY="YOUR_KEY"
```

Verify it exists without printing it:

```bash
[ -n "${GROQ_API_KEY:-}" ] && echo "GROQ_API_KEY set" || echo "GROQ_API_KEY missing"
```

## 7. Install live runtime safely

On a fresh SD card there is no old runtime to preserve:

```bash
cp ~/projects/NeuroBrain-Online/neurobrain.py ~/neurobrain.py
rm -rf ~/neurobrain_modules
cp -a ~/projects/NeuroBrain-Online/neurobrain_modules ~/neurobrain_modules
```

On an existing working system, back up the live files before doing this.

## 8. Syntax check

```bash
python -m py_compile \
  ~/neurobrain.py \
  ~/neurobrain_modules/camera.py \
  ~/neurobrain_modules/oled.py \
  ~/neurobrain_modules/motors.py
```

## 9. Run

```bash
source ~/oledtest/bin/activate
export GROQ_API_KEY="YOUR_KEY"
python ~/neurobrain.py
```

Use `Ctrl+C` for clean shutdown.
EOF

cat > docs/RECOVERY.md <<'EOF'
# Recovery Guide

## First rule

Confirm the repository name before doing anything destructive:

```bash
pwd
git remote -v
git log --oneline -5
```

Expected project: `drpeker/NeuroBrain-Online`.

Do not substitute the older `drpeker/NeuroBrain` repository.

## Known baseline

Initial online baseline:

`74802c4` — `Initial NeuroBrain Online working multimodal system`

## Failure isolation

### Microphone not detected

```bash
arecord -l
arecord -D hw:1,0 -f S16_LE -r 16000 -c 1 -d 5 /tmp/mic.wav
```

If card numbering changed after reinstall, identify the C270 again. Do not blindly assume a new ALSA card number.

### Robot triggers on its own speech

Verify `speak()` still drains the microphone during Edge-TTS generation, ffmpeg conversion and `aplay`, and retains the short post-playback acoustic tail.

### ALSA `overrun!!!`

Verify blocking Groq calls still use `groq_with_mic_drain()`. Do not simply increase buffers and remove the drain architecture.

### Camera unavailable

```bash
v4l2-ctl --list-devices
fuser /dev/video0
```

There should be one application-level camera owner: `camera.py`.

### Vision answers without actually looking

Verify the system prompt still forbids claims of current physical sight without a current camera-tool call.

### OLED missing

```bash
i2cdetect -y 1
```

Expected: `0x3C`.

### Groq authentication failure

Verify the environment variable exists. Never solve this by hard-coding the secret into `neurobrain.py`.

## Safe source recovery on an existing installation

Before replacing live source:

```bash
cp ~/neurobrain.py ~/neurobrain_before_recovery.py
cp -a ~/neurobrain_modules ~/neurobrain_modules_before_recovery
```

Then copy from a known Git commit and test.

## Engineering recovery order

1. recover OS and hardware visibility
2. recover Python environment
3. clone exact repository
4. restore secret externally
5. syntax-check source
6. test microphone alone
7. test OLED alone
8. test camera alone
9. run full robot with motors still inactive
10. verify voice loop
11. verify camera tool
12. verify no ALSA overrun
13. only then continue development
EOF

cat > docs/DESIGN_DECISIONS.md <<'EOF'
# Design Decisions

## Separate online repository

The online Groq-backed robot is maintained as `NeuroBrain-Online` rather than being folded into the older offline/experimental `NeuroBrain` repository. This prevents incompatible architectures and recovery instructions from becoming mixed.

## Live runtime separate from Git working tree

The robot runs from `/home/drpeker/neurobrain.py` and `/home/drpeker/neurobrain_modules`, while Git lives under `/home/drpeker/projects/NeuroBrain-Online`. This makes accidental Git operations less likely to destroy a physically working state.

## Local hardware, cloud cognition

Time-sensitive hardware ownership remains local. Cloud services provide STT, reasoning and vision rather than owning continuous camera/audio streams.

## Model-selected camera tool

The main model decides whether current visual information is useful. This is more general than a list of phrases such as "look" or "camera" and permits implicit visual references.

## One camera owner

A single continuous camera manager avoids device contention and simultaneously supports local OLED motion tracking and on-demand AI snapshots.

## GPT main model + Qwen specialist

GPT-OSS remains the conversational/reasoning authority. Qwen Vision returns visual observations to GPT rather than replacing the main conversational model.

## No hallucinated physical sight

Current environmental claims require an actual camera-tool result for the current request.

## Microphone draining is architectural

Continuous `arecord` plus blocking network calls produced ALSA overruns. The solution is to keep consuming PCM while the network request runs in a worker thread. This behavior must survive refactoring.

## Edge-TTS is the active voice path

Historical Piper-related material may remain for experimentation, but Edge-TTS with Emel/Jenny is the known current online voice configuration.

## Automatic language handling

Whisper language detection drives Turkish/English response behavior. An isolated misclassification should not trigger replacement with a brittle keyword router.

## Motor API before motor activation

The interface exists before physical actuation. This allows future reasoning/action architecture to be designed while keeping current hardware safe.

## Recovery before refactoring

A documented, restorable working robot is more valuable than source cleanup. Preserve a checkpoint before major architectural changes.
EOF

cat > docs/SYSTEM_DIAGRAMS.md <<'EOF'
# NeuroBrain Online — Complete System Diagrams and Engineering Map

This document is intended to remain useful even if the original SD card and all ChatGPT conversations disappear.

## 1. Complete working system

```text
                         RASPBERRY PI 4 / 4 GB
+-------------------------------------------------------------------+
|                                                                   |
|  Logitech C270                                                    |
|   microphone                                                      |
|      |                                                            |
|      v                                                            |
|  arecord hw:1,0 ----> exact 20 ms PCM chunks                      |
|      |                         |                                   |
|      |                         +--> adaptive VAD                   |
|      |                                  |                          |
|      |                                  v                          |
|      |                           speech WAV                        |
|      |                                  |                          |
|      |                                  +----------------------+   |
|      |                                                         |   |
|      |   C270 camera                                           |   |
|      |      |                                                  |   |
|      |      v                                                  |   |
|      |  camera.py                                              |   |
|      |      |                                                  |   |
|      |      +--> latest frame                                  |   |
|      |      |                                                  |   |
|      |      +--> motion detector --> oled.py --> SH1106 eyes   |   |
|      |                                                         |   |
|      +---------------------------------------------------------|---+
|                                                                |   |
+----------------------------------------------------------------|---+
                                                                 |
                                                                 v
                         GROQ CLOUD
                  +-----------------------+
                  | Whisper Large V3 Turbo|
                  +-----------+-----------+
                              |
                              v
                     transcript/language
                              |
                              v
                  +-----------------------+
                  |     GPT-OSS-20B       |
                  |       MAIN BRAIN      |
                  +----+-------------+----+
                       |             |
                  no vision       vision useful
                       |             |
                       |             v
                       |       get_camera_view
                       |             |
                       |       current local frame
                       |             |
                       |             v
                       |     +-------------------+
                       |     | Qwen Vision 27B   |
                       |     +---------+---------+
                       |               |
                       |          visual facts
                       |               |
                       +-------+-------+
                               |
                               v
                        GPT final answer
                               |
                               v
                         Raspberry Pi
                               |
                            Edge-TTS
                               |
                             ffmpeg
                               |
                         aplay hw:0,0
                               |
                            speaker
```

## 2. VAD state flow

```text
boot
 |
 v
arecord starts
 |
 v
~1 s AGC warmup
 |
 v
2 s noise calibration
 |
 v
SILENT <-------------------------------------+
 |                                           |
 | repeated start-threshold hits             |
 v                                           |
SPEECH                                       |
 |                                           |
 | append PCM + prebuffer                    |
 |                                           |
 | end threshold below for 300 ms            |
 v                                           |
utterance complete                           |
 |                                           |
 +--> if >= 300 ms -> Whisper/GPT/TTS -------+
```

## 3. Camera decision flow

```text
user transcript
      |
      v
   GPT-OSS
      |
      +--> answerable without current sight? --> answer
      |
      +--> current visual information useful?
                       |
                       v
                 get_camera_view
                       |
                       v
               camera manager snapshot
                       |
                       v
                   Qwen Vision
                       |
                       v
                  visual facts
                       |
                       v
                 GPT-OSS final
```

## 4. Anti-hallucination boundary

```text
No camera tool this turn
        |
        +--> GPT may reason generally
        +--> GPT MUST NOT claim current physical sight

Camera tool called
        |
        v
Qwen returns image-grounded facts
        |
        v
GPT may describe current scene within those facts
```

## 5. ALSA overrun protection

```text
BAD OLD FLOW
arecord -> pipe -> main thread blocks on cloud -> pipe fills -> overrun

CURRENT FLOW
                     +--> worker thread -> Groq request
arecord -> pipe -----|
                     +--> main thread -> continuously drains PCM
```

## 6. OLED state map

```text
startup -> idle
voice detected -> listening
utterance ends -> thinking
TTS -> speaking
exception -> error -> idle
camera motion -> local gaze target
```

The OLED worker is independent of the cloud reasoning loop.

## 7. File responsibility map

```text
neurobrain.py
  orchestration, VAD, Groq, STT, tool calling, TTS, shutdown

neurobrain_modules/camera.py
  sole VideoCapture owner, latest frame, motion tracking, snapshot API

neurobrain_modules/oled.py
  SH1106 thread, eye animation, state changes, motion gaze

neurobrain_modules/motors.py
  motor API boundary; physical actuation intentionally inactive
```

## 8. Recovery map

```text
GitHub repo only
   |
   v
new SD card + 64-bit Debian/Raspberry Pi OS
   |
   v
system packages + I2C + audio/video visibility
   |
   v
clone NeuroBrain-Online
   |
   v
create ~/oledtest venv
   |
   v
pip requirements
   |
   v
external GROQ_API_KEY
   |
   v
copy source to live paths
   |
   v
syntax tests
   |
   v
mic -> OLED -> camera tests
   |
   v
full voice test
   |
   v
camera-tool test
   |
   v
verify no ALSA overrun
   |
   v
RECOVERED BASELINE
```

## 9. Development rule

```text
verified main
   |
new branch
   |
change one subsystem
   |
syntax/static checks
   |
physical Pi test
   |
update docs
   |
merge only after known-good verification
```

## 10. Future motor boundary

```text
GPT intent / high-level request
       |
       v
local deterministic action validator
       |
       +--> unsafe/invalid -> reject/stop
       |
       v
bounded motor command
       |
       v
motors.py
       |
       v
MX1508 / physical motors
```

Do not bypass the deterministic local validator when motor actuation is implemented.
EOF

cat > docs/SD_CARD_DISASTER_RECOVERY.md <<'EOF'
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
EOF

# Preserve this generator itself in the repository when it is being run from elsewhere.
SELF="$(readlink -f "$0" 2>/dev/null || true)"
TARGET="$REPO/install_neurobrain_online_project_memory.sh"
if [[ -n "$SELF" && -f "$SELF" && "$SELF" != "$TARGET" ]]; then
  cp "$SELF" "$TARGET"
  chmod +x "$TARGET"
fi

# Safety checks: documentation generator must not alter application Python source.
echo
echo "===== PROJECT MEMORY CREATED ====="
find docs -maxdepth 1 -type f -printf '%f\n' | sort

echo
echo "===== PYTHON SOURCE SYNTAX ====="
python -m py_compile neurobrain.py neurobrain_modules/camera.py neurobrain_modules/oled.py neurobrain_modules/motors.py
echo "Python syntax OK"

echo
echo "===== SECRET SCAN ====="
if grep -RInE --exclude-dir=.git --exclude='install_neurobrain_online_project_memory.sh' 'gsk_[A-Za-z0-9_-]{10,}' .; then
  echo "ERROR: Possible Groq key found. Nothing will be committed automatically."
  exit 2
else
  echo "No embedded Groq key found."
fi

echo
echo "===== GIT STATUS ====="
git status --short

echo
echo "Documentation generation complete."
echo "Review if desired, then commit with:"
echo "  git add README.md requirements.txt docs install_neurobrain_online_project_memory.sh"
echo "  git commit -m 'Add complete NeuroBrain Online engineering memory and disaster recovery'"
echo "  git push"
