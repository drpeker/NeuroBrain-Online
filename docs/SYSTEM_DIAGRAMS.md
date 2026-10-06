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
