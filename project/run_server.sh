#!/bin/sh
# Starts the RFID attendance server.
cd "$(dirname "$0")"
if [ -x .venv/bin/python ]; then exec .venv/bin/python run_server.py; fi
exec python3 run_server.py
