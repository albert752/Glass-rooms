#!/bin/sh
# Read-only API preview on loopback for the iPad app's Mac preview (no Home Assistant, no actions).
set -eu
cd "$(dirname "$0")/.."
exec python3 glass_rooms/server.py --preview --port "${1:-8099}"
