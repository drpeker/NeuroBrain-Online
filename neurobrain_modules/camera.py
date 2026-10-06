import cv2
import time
import threading

from neurobrain_modules.oled import set_motion, clear_motion


_lock = threading.Lock()
_stop_event = threading.Event()
_thread = None
_cap = None
_latest_frame = None


def _camera_loop():
    global _cap, _latest_frame

    _cap = cv2.VideoCapture(0)
    _cap.set(cv2.CAP_PROP_FRAME_WIDTH, 320)
    _cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 240)
    _cap.set(cv2.CAP_PROP_FPS, 30)
    _cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)

    if not _cap.isOpened():
        print("KAMERA HATASI: /dev/video0 açılamadı.")
        return

    backsub = cv2.createBackgroundSubtractorMOG2(
        history=100,
        varThreshold=30,
        detectShadows=False
    )

    last_motion = 0.0

    while not _stop_event.is_set():

        ok, frame = _cap.read()

        if not ok:
            time.sleep(0.02)
            continue

        # AI görüntü istediğinde kullanacağımız temiz son kare.
        with _lock:
            _latest_frame = frame.copy()

        # Hareket analizi için küçült.
        small = cv2.resize(frame, (160, 120))
        small = cv2.GaussianBlur(small, (5, 5), 0)

        mask = backsub.apply(small)

        mask = cv2.threshold(
            mask, 200, 255, cv2.THRESH_BINARY
        )[1]

        contours, _ = cv2.findContours(
            mask,
            cv2.RETR_EXTERNAL,
            cv2.CHAIN_APPROX_SIMPLE
        )

        candidates = []

        for c in contours:
            area = cv2.contourArea(c)

            if area > 120:
                candidates.append((area, c))

        if candidates:

            _, c = max(candidates, key=lambda z: z[0])

            x, y, w, h = cv2.boundingRect(c)

            cx = x + w / 2
            cy = y + h / 2

            nx = (cx / 160.0) - 0.5
            ny = (cy / 120.0) - 0.5

            tx = nx * 36
            ty = -ny * 28

            tx = max(-16, min(16, tx))
            ty = max(-12, min(12, ty))

            set_motion(tx, ty, True)
            last_motion = time.monotonic()

        elif time.monotonic() - last_motion > 0.7:

            clear_motion()

    clear_motion()

    if _cap is not None:
        _cap.release()

    _cap = None


def camera_start():
    global _thread

    if _thread is not None and _thread.is_alive():
        return

    _stop_event.clear()

    _thread = threading.Thread(
        target=_camera_loop,
        daemon=True,
        name="NeuroBrainCamera"
    )

    _thread.start()


def capture_image(filename="/tmp/neurobrain_camera.jpg"):
    """
    Kamerayı yeniden açmaz.
    Sürekli çalışan kameranın en son temiz karesini kaydeder.
    """

    with _lock:
        if _latest_frame is None:
            raise RuntimeError("Kameradan henüz görüntü gelmedi.")

        frame = _latest_frame.copy()

    if not cv2.imwrite(filename, frame):
        raise RuntimeError("Kamera görüntüsü kaydedilemedi.")

    return filename


def get_latest_frame():
    with _lock:
        if _latest_frame is None:
            return None

        return _latest_frame.copy()


def camera_stop():
    _stop_event.set()

    if _thread is not None:
        _thread.join(timeout=2)
