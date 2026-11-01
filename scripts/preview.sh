#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
exec python3 glass_rooms/server.py --preview --port "${1:-8099}"
