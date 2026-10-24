"""Production entry point for the school PC.

    python run_server.py

Uses waitress (multi-threaded, works on Windows) when it is installed and
falls back to Flask's development server otherwise. `python app.py` still
works for development.
"""
import logging

import config
import database as db
from app import app

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")


def main():
    db.init_db()
    print(f"Database: {db.DB_NAME}")
    print(f"Server running on http://{config.HOST}:{config.PORT}  (admin console: /admin)")
    print("Keep this window open.")
    try:
        from waitress import serve
    except ImportError:
        print("waitress is not installed; using the Flask development server.")
        app.run(host=config.HOST, port=config.PORT, threaded=True)
        return
    serve(app, host=config.HOST, port=config.PORT, threads=8)


if __name__ == "__main__":
    main()
