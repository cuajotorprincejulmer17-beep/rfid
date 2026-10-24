"""Registering RFID cards to people. Shared by the legacy /users route and the admin API."""
import database as db


def register_card(uid, name, role, time_limit_minutes=None):
    """Applies the card rules. Returns (success, message, user_id or None).

    Temporary cards are upgraded, visitor cards are reusable (the previous
    holder is archived with their history), student cards are permanent.
    """
    uid = str(uid or "").strip().upper()
    name = str(name or "").strip()
    role = str(role or "").strip().lower()
    if not uid or not name or role not in ("student", "visitor"):
        return False, "Missing or invalid fields", None

    if time_limit_minutes is not None:
        try:
            time_limit_minutes = int(time_limit_minutes)
        except (TypeError, ValueError):
            return False, "Invalid time limit", None
        if time_limit_minutes < 1:
            return False, "Time limit must be at least 1 minute", None

    existing = db.uid_exists(uid)
    if existing:
        if existing["is_temp"]:
            db.upgrade_temp_user(uid, name, role, time_limit_minutes)
            return True, f"{name} registered ({role}) - temp card upgraded", existing["id"]
        if existing["role"] == "visitor":
            if db.re_register_visitor_card(uid, name, role, time_limit_minutes):
                return True, f"{name} registered as {role} - card reused", db.uid_exists(uid)["id"]
            return False, "Could not re-register this card", None
        return False, "Student cards are permanent. Delete this card first to reuse it.", None

    user_id = db.add_user(uid, name, role, time_limit_minutes=time_limit_minutes)
    return True, f"{name} registered as {role}", user_id
