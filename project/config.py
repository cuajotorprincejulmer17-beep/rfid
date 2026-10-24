"""Server configuration.

Settings come from environment variables. A `.env` file next to this file is
read first (it is git-ignored; copy `.env.example`). Values already set in
the environment win over the file, so a one-off `set X=...` still works.
"""
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))


def load_env(path=os.path.join(BASE_DIR, ".env")):
    """Reads KEY=VALUE lines into os.environ without overriding real env vars."""
    if not os.path.exists(path):
        return
    with open(path, encoding="utf-8") as fh:
        for raw in fh:
            line = raw.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            key, value = key.strip(), value.strip().strip('"').strip("'")
            if key and key not in os.environ:
                os.environ[key] = value


load_env()


def env(key, default=""):
    return os.environ.get(key, default)


def env_flag(key, default=False):
    raw = os.environ.get(key)
    if raw is None:
        return default
    return raw.strip().lower() in ("1", "true", "yes", "on")


def env_int(key, default):
    try:
        return int(os.environ.get(key, default))
    except (TypeError, ValueError):
        return default


# The database lives next to the code, wherever the server is started from.
DB_PATH = env("RFID_DB", os.path.join(BASE_DIR, "rfid_system.db"))
HOST = env("HOST", "0.0.0.0")
PORT = env_int("PORT", 5001)

# The original ESP32 sketch posts to /tap with no key. Turn this off once
# every reader runs firmware v2 with a device key.
ALLOW_LEGACY_TAP = env_flag("ALLOW_LEGACY_TAP", True)

# The desktop admin (app_ui.py) uses the original /users and /logs routes,
# which have no password. By default only the server PC itself may call them.
# Set to 0 only if app_ui.py runs on a different PC on a trusted network.
LEGACY_ADMIN_LOCAL_ONLY = env_flag("LEGACY_ADMIN_LOCAL_ONLY", True)

# Background jobs (end-of-day close, absence notices). Tests turn this off.
JOBS_ENABLED = env_flag("JOBS_ENABLED", True)

# Guardian SMS: none | log | semaphore | http
SMS_PROVIDER = env("SMS_PROVIDER", "none")

# Where migrate.py writes the pre-migration copy of the database.
BACKUP_DIR = env("BACKUP_DIR", os.path.join(BASE_DIR, "backups"))
