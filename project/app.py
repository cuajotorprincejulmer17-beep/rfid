import config  # noqa: F401  (loads .env before anything reads the environment)
from flask import Flask, request, jsonify
import database as db
from api import init_api, purge_user_data
from api.common import connect
from services import cards, devices

app = Flask(__name__)

LOCAL_ADDRESSES = {"127.0.0.1", "::1", "localhost"}


@app.before_request
def legacy_admin_local_only():
    """The keyless card-management routes answer the server PC only (see config)."""
    if not config.LEGACY_ADMIN_LOCAL_ONLY:
        return None
    path = request.path
    if (path == "/users" or path.startswith("/users/") or path in ("/logs", "/today-count")) \
            and request.remote_addr not in LOCAL_ADDRESSES:
        return jsonify({"success": False, "message": "Use the admin console at /admin from other computers."}), 403
    return None

# The keys the original ESP32 sketch and kiosk expect from /tap. Firmware v2
# uses /api/v1/device/tap, which adds `lcd` and `event_id`.
LEGACY_TAP_KEYS = ("status", "result", "name", "role", "action", "message")


@app.route("/tap", methods=["POST"])
def tap():
    """The original reader route: no key, taps belong to the DEFAULT reader."""
    if not config.ALLOW_LEGACY_TAP:
        return jsonify({"status": "error", "message": "Legacy /tap is disabled. Update the reader firmware."}), 403
    data = request.get_json(silent=True) or {}
    uid = str(data.get("uid", "")).strip().upper()

    if not uid:
        return jsonify({"status": "error", "message": "No UID received"})

    with connect() as c:
        device = devices.default_device(c)
    result = devices.process_tap(device, uid)
    return jsonify({k: result[k] for k in LEGACY_TAP_KEYS})


@app.route("/timeout-arm", methods=["POST"])
def timeout_arm():
    """Arm one time-out tap on the DEFAULT reader for a short interval."""
    with connect() as c:
        seconds = devices.arm_timeout(c, devices.default_device(c)["id"])
    return jsonify({"success": True, "seconds": seconds})


@app.route("/last-tap", methods=["GET"])
def last_tap_route():
    with connect() as c:
        return jsonify(devices.last_tap(c))


@app.route("/display-event", methods=["GET"])
def display_event_route():
    """Return only the latest tap result for the public-facing kiosk display."""
    with connect() as c:
        return jsonify(devices.display_event(c, devices.default_device(c)["id"]))


@app.route("/users", methods=["GET"])
def users_list():
    return jsonify(db.get_all_users())

@app.route("/users", methods=["POST"])
def users_create():
    data = request.get_json(silent=True) or {}
    ok, message, _ = cards.register_card(data.get("uid"), data.get("name"), data.get("role"),
                                         data.get("time_limit_minutes"))
    return jsonify({"success": ok, "message": message})

@app.route("/users/<uid>", methods=["DELETE"])
def users_delete(uid):
    existing = db.uid_exists(uid.upper())
    db.delete_user(uid.upper())
    if existing:
        purge_user_data(existing["id"])  # remove mobile accounts/tokens/notifications for this user
    return jsonify({"success": True})

@app.route("/logs", methods=["GET"])
def logs_route():
    return jsonify(db.get_recent_logs())


@app.route("/today-count", methods=["GET"])
def today_count_route():
    return jsonify({"count": db.count_today()})


init_api(app)  # registers /api/v1, the admin console, and runs migrations


if __name__ == "__main__":
    db.init_db()
    print("Server running! Keep this window open.")
    app.run(host=config.HOST, port=config.PORT)
