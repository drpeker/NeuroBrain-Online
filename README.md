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
