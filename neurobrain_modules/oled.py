import time
import random
import threading

from luma.core.interface.serial import i2c
from luma.oled.device import sh1106
from luma.core.render import canvas


# ============================================================
# NeuroBrain OLED Eyes
# SH1106 128x64 @ I2C 0x3C
# ============================================================

_device = None
_thread = None
_stop_event = threading.Event()
_lock = threading.Lock()

_state = "idle"

# Kamera/motion sistemi daha sonra bunları güncelleyebilir.
_motion_x = 0.0
_motion_y = 0.0
_motion_seen = False

eyes = [(33, 32), (95, 32)]


def _ensure_device():
    global _device

    if _device is None:
        serial = i2c(port=1, address=0x3C)
        _device = sh1106(serial, width=128, height=64)


def set_motion(x, y, seen=True):
    """Kamera modülü gözlerin bakacağı hedefi buradan verecek."""
    global _motion_x, _motion_y, _motion_seen

    with _lock:
        _motion_x = max(-16, min(16, float(x)))
        _motion_y = max(-12, min(12, float(y)))
        _motion_seen = bool(seen)


def clear_motion():
    global _motion_seen

    with _lock:
        _motion_seen = False


def _eye_loop():
    global _state

    _ensure_device()

    px = 0.0
    py = 0.0

    idle_x = 0.0
    idle_y = 0.0
    next_idle = time.time() + 1

    next_blink = time.time() + random.uniform(3, 6)
    blink_start = None

    while not _stop_event.is_set():

        now = time.time()

        with _lock:
            state = _state
            mx = _motion_x
            my = _motion_y
            motion = _motion_seen

        # ----------------------------------------------------
        # Bakış hedefi
        # ----------------------------------------------------

        if state == "thinking":

            # Düşünürken hafif yukarı/yan tarafa bak.
            target_x = 9
            target_y = -7

        elif state == "error":

            target_x = 0
            target_y = 7

        elif motion:

            # Kamera hareket takibi öncelikli.
            target_x = mx
            target_y = my

        elif state == "listening":

            # Kullanıcıyı dinlerken dikkatli biçimde merkeze bak.
            target_x = 0
            target_y = 0

        elif state == "speaking":

            # Konuşurken küçük canlı hareketler.
            target_x = 4 * random.uniform(-1, 1)
            target_y = 2 * random.uniform(-1, 1)

        else:

            # IDLE: eski motion_eyes davranışı.
            if now >= next_idle:
                idle_x = random.uniform(-10, 10)
                idle_y = random.uniform(-7, 7)
                next_idle = now + random.uniform(1, 2.5)

            target_x = idle_x
            target_y = idle_y

        # Eski çalışan sürümdeki hızlı/yumuşak hareket.
        px += (target_x - px) * 0.75
        py += (target_y - py) * 0.75

        # ----------------------------------------------------
        # Blink
        # ----------------------------------------------------

        openness = 1.0

        if blink_start is None and now >= next_blink:
            blink_start = now

        if blink_start is not None:

            t = now - blink_start

            if t < 0.08:
                openness = 1 - t / 0.08

            elif t < 0.14:
                openness = 0.05

            elif t < 0.22:
                openness = (t - 0.14) / 0.08

            else:
                blink_start = None
                next_blink = now + random.uniform(3, 6)

        # ----------------------------------------------------
        # Çizim
        # ----------------------------------------------------

        try:

            with canvas(_device) as draw:

                for cx, cy in eyes:

                    eh = max(2, int(23 * openness))

                    draw.ellipse(
                        (cx - 25, cy - eh, cx + 25, cy + eh),
                        outline="white",
                        width=2
                    )

                    if openness > 0.30:

                        gx = int(cx + px)
                        gy = int(cy + py * openness)

                        r = 7

                        draw.ellipse(
                            (gx - r, gy - r, gx + r, gy + r),
                            fill="white"
                        )

        except Exception as e:
            print("OLED HATASI:", e)
            time.sleep(0.2)

        time.sleep(0.02)


# ============================================================
# Public API
# ============================================================

def oled_start():
    global _thread

    if _thread is not None and _thread.is_alive():
        return

    _stop_event.clear()

    _thread = threading.Thread(
        target=_eye_loop,
        daemon=True,
        name="NeuroBrainOLED"
    )

    _thread.start()


def _set_state(state):
    global _state

    with _lock:
        _state = state


def oled_idle():
    _set_state("idle")


def oled_listening():
    _set_state("listening")


def oled_thinking():
    _set_state("thinking")


def oled_speaking():
    _set_state("speaking")


def oled_error():
    _set_state("error")


def oled_stop():

    _stop_event.set()

    if _thread is not None:
        _thread.join(timeout=1)

    if _device is not None:
        try:
            _device.clear()
        except Exception:
            pass
