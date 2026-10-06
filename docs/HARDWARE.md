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
