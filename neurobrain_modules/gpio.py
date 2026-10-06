import gpiod
from gpiod.line import Direction, Value

CHIP = "/dev/gpiochip0"

# BCM numbering.
# 0/1 = HAT ID EEPROM
# 2/3 = NeuroBrain I2C / OLED
PROTECTED_GPIO = {0, 1, 2, 3}

MIN_GPIO = 4
MAX_GPIO = 27

# NeuroBrain çalıştığı sürece sahip olduğumuz GPIO request'leri.
_requests = {}


def _validate(pin):
    pin = int(pin)

    if pin < MIN_GPIO or pin > MAX_GPIO:
        raise ValueError(f"GPIO{pin} genel erişime açık değil.")

    if pin in PROTECTED_GPIO:
        raise PermissionError(
            f"GPIO{pin} NeuroBrain/sistem tarafından korunuyor."
        )

    return pin


def _parse_state(state):
    if isinstance(state, str):
        s = state.strip().upper()

        if s in ("HIGH", "1", "ON"):
            return Value.ACTIVE

        if s in ("LOW", "0", "OFF"):
            return Value.INACTIVE

        raise ValueError("state HIGH veya LOW olmalı.")

    return Value.ACTIVE if bool(state) else Value.INACTIVE


def _release(pin):
    req = _requests.pop(pin, None)

    if req is not None:
        try:
            req.release()
        except Exception:
            pass


def gpio_write(pin, state):
    """BCM GPIO pinini OUTPUT yap ve HIGH/LOW sür."""

    pin = _validate(pin)
    value = _parse_state(state)

    req = _requests.get(pin)

    if req is None:
        req = gpiod.request_lines(
            CHIP,
            consumer="NeuroBrain",
            config={
                pin: gpiod.LineSettings(
                    direction=Direction.OUTPUT,
                    output_value=value,
                )
            },
        )
        _requests[pin] = req

    else:
        req.reconfigure_lines(
            {
                pin: gpiod.LineSettings(
                    direction=Direction.OUTPUT,
                    output_value=value,
                )
            }
        )
        req.set_value(pin, value)

    # Gerçek request üzerinden tekrar oku.
    actual = req.get_value(pin)

    return {
        "success": True,
        "pin": pin,
        "mode": "OUTPUT",
        "state": "HIGH" if actual == Value.ACTIVE else "LOW",
        "value": 1 if actual == Value.ACTIVE else 0,
    }


def gpio_read(pin):
    """GPIO'nun gerçek seviyesini oku; mevcut OUTPUT'u bozma."""

    pin = _validate(pin)
    req = _requests.get(pin)

    if req is None:
        # NeuroBrain bu pine daha önce sahip olmadıysa INPUT olarak al.
        req = gpiod.request_lines(
            CHIP,
            consumer="NeuroBrain",
            config={
                pin: gpiod.LineSettings(
                    direction=Direction.INPUT,
                )
            },
        )
        _requests[pin] = req
        mode = "INPUT"

    else:
        # Mevcut request'i değiştirmeden oku.
        mode = "MANAGED"

    value = req.get_value(pin)

    return {
        "success": True,
        "pin": pin,
        "mode": mode,
        "state": "HIGH" if value == Value.ACTIVE else "LOW",
        "value": 1 if value == Value.ACTIVE else 0,
    }


def gpio_release(pin):
    """Bir GPIO üzerindeki NeuroBrain sahipliğini bırak."""

    pin = _validate(pin)
    _release(pin)

    return {
        "success": True,
        "pin": pin,
        "released": True,
    }


def gpio_cleanup():
    """NeuroBrain kapanırken bütün GPIO request'lerini bırak."""

    for pin in list(_requests):
        _release(pin)
