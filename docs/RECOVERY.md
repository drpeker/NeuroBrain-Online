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
