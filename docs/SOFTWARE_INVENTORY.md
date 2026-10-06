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
