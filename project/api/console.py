"""Serves the browser admin console at /admin (static files, no build step).

The console is a single page that talks to /api/v1/admin/* with a staff
token, so it needs no server-side sessions. Everything is bundled locally:
it works on a school LAN with no internet.
"""
import os

from flask import send_from_directory

import config

WEB_DIR = os.path.join(config.BASE_DIR, "admin_web")


def register(app):
    @app.route("/admin")
    @app.route("/admin/")
    def admin_console():
        resp = send_from_directory(WEB_DIR, "index.html")
        resp.headers["Cache-Control"] = "no-store"
        return resp

    @app.route("/admin/assets/<path:name>")
    def admin_assets(name):
        resp = send_from_directory(WEB_DIR, name)
        resp.headers["Cache-Control"] = "no-cache"
        return resp
