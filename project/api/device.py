"""RFID reader routes (firmware v2 and the kiosk display). Auth: X-Device-Key."""
import time
from functools import wraps

from flask import g, jsonify, request

from services import devices
from .common import ApiError, bp, client_ip, connect, limiter


def require_device(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        limiter.check(f"device-fail:{client_ip()}", 20, 600)
        with connect() as c:
            device = devices.by_key(c, request.headers.get("X-Device-Key", ""))
        if device is None:
            limiter.add(f"device-fail:{client_ip()}")
            raise ApiError(401, "unknown_device", "Unknown or disabled reader key.")
        g.device = device
        return fn(*args, **kwargs)
    return wrapper


def _body():
    data = request.get_json(silent=True)
    return data if isinstance(data, dict) else {}


@bp.post("/device/tap")
@require_device
def device_tap():
    d = _body()
    uid = str(d.get("uid", "")).strip()
    if not uid or len(uid) > 32 or not uid.isalnum():
        raise ApiError(400, "invalid_uid", "'uid' must be the card's hex UID.")
    result = devices.process_tap(g.device, uid, client_event_id=d.get("client_event_id"),
                                 tapped_at=d.get("tapped_at"), debounce=True)
    return jsonify(result)


@bp.post("/device/arm-timeout")
@require_device
def device_arm_timeout():
    if g.device["mode"] != "KIOSK":
        raise ApiError(409, "not_kiosk", "Only a KIOSK reader uses the TIME OUT button.")
    with connect(write=True) as c:
        seconds = devices.arm_timeout(c, g.device["id"])
    return jsonify(success=True, seconds=seconds, lcd=["TIME OUT ready", "Tap your card"])


@bp.post("/device/heartbeat")
@require_device
def device_heartbeat():
    d = _body()

    def num(key):
        v = d.get(key)
        return v if isinstance(v, int) and not isinstance(v, bool) else None

    firmware = d.get("firmware") if isinstance(d.get("firmware"), str) else None
    with connect(write=True) as c:
        devices.heartbeat(c, g.device["id"], ip=client_ip(), rssi=num("rssi"),
                          firmware=(firmware or "")[:40] or None, queue_len=num("queue_len"))
    # The reader sets its clock from this, so offline-queued taps carry their
    # real time even on a LAN with no internet for NTP.
    return jsonify(success=True, mode=g.device["mode"], name=g.device["name"], epoch=int(time.time()))


@bp.get("/device/display-event")
@require_device
def device_display_event():
    with connect() as c:
        return jsonify(devices.display_event(c, g.device["id"]))
