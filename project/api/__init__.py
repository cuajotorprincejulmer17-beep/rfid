"""Mobile/student API (/api/v1). The ESP32 /tap endpoint is NOT part of this package."""
import database as db
import migrations

from . import (admin, admin_school, auth, device, inbox, push, staff_auth,  # noqa: F401  (registers routes)
               student, student_school)
from jobs import scheduler
from . import console
from .common import bp
from .notifier import notify_after_tap
from .schema import init_api_schema, purge_user_data


def init_api(app):
    db.init_db()
    init_api_schema()
    migrations.migrate()
    app.register_blueprint(bp)
    console.register(app)
    push.ensure_started()
    scheduler.ensure_started()


__all__ = ["init_api", "notify_after_tap", "purge_user_data"]
