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
