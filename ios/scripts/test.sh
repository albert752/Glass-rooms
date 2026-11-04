#!/bin/sh
# Compile the Foundation-only parts of the iOS app for macOS and test them against the real
# Glass Rooms server running on loopback with a synthetic Home Assistant (no network, no HA).
set -eu
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=${TMPDIR:-/tmp}/glass-rooms-ios-tests
mkdir -p "$OUT"
SRC="$ROOT/ios/GlassRooms"
clang -fobjc-arc -Wall -Wextra -Werror -Wno-unused-parameter -mmacosx-version-min=10.13 \
  -I "$SRC" "$ROOT/ios/Tests/GRClientTests.m" "$SRC/GRAPIClient.m" "$SRC/GRLogic.m" "$SRC/GRPanelModel.m" "$SRC/GRUtil.m" \
  -framework Foundation -framework Security -o "$OUT/GRClientTests"
FIFO="$OUT/fake-panel.fifo"
# Remove the previous run's port and token before the new server writes its own.
rm -f "$FIFO" "$OUT/fake-panel.out"; mkfifo "$FIFO"
python3 "$ROOT/ios/Tests/fake_panel.py" < "$FIFO" > "$OUT/fake-panel.out" &
SERVER=$!
exec 3> "$FIFO"
trap 'exec 3>&-; wait $SERVER 2>/dev/null || true; rm -f "$FIFO"' EXIT
i=0
while [ ! -s "$OUT/fake-panel.out" ] && [ $i -lt 100 ]; do sleep 0.1; i=$((i+1)); done
PORT=$(python3 -c 'import json,sys; print(json.loads(open(sys.argv[1]).readline())["port"])' "$OUT/fake-panel.out")
TOKEN=$(python3 -c 'import json,sys; print(json.loads(open(sys.argv[1]).readline())["token"])' "$OUT/fake-panel.out")
"$OUT/GRClientTests" "$PORT" "$TOKEN"
