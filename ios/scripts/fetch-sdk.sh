#!/bin/sh
# Download only iPhoneOS9.3.sdk (Apple headers and .tbd link stubs, no executables) from the
# community repository theos/sdks, pinned to a known commit, into ios/.sdk/ (ignored by git).
# Linking against the 9.3 stubs proves that the binary uses no API newer than iOS 9.3.
set -eu
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
DEST="$ROOT/ios/.sdk"
COMMIT=0222fd5413cf4b9af096f37b4621afa2688572f7
if [ -d "$DEST/iPhoneOS9.3.sdk" ]; then echo "SDK ja present: $DEST/iPhoneOS9.3.sdk"; exit 0; fi
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
git -C "$WORK" init -q
git -C "$WORK" remote add origin https://github.com/theos/sdks.git
git -C "$WORK" config core.sparseCheckout true
echo "iPhoneOS9.3.sdk/" > "$WORK/.git/info/sparse-checkout"
git -C "$WORK" fetch -q --depth 1 --filter=blob:none origin "$COMMIT"
git -C "$WORK" checkout -q FETCH_HEAD
mkdir -p "$DEST"
mv "$WORK/iPhoneOS9.3.sdk" "$DEST/"
# libSystem re-exports liblaunch, but this SDK copy lacks its stub; the app uses none of its symbols.
cat > "$DEST/iPhoneOS9.3.sdk/usr/lib/system/liblaunch.tbd" <<'EOF'
---
archs:                 [ armv7, armv7s, arm64 ]
platform:              ios
install-name:          /usr/lib/system/liblaunch.dylib
current-version:       765.1.8
compatibility-version: 1
exports:
  - archs:             [ armv7, armv7s, arm64 ]
    symbols:           [ _launch_activate_socket ]
...
EOF
# Modern ld reads stubs that also list i386/x86_64 as simulator stubs; keep only device architectures.
find "$DEST/iPhoneOS9.3.sdk" -name "*.tbd" -type f -exec sed -i '' 's/, i386, x86_64 \]/ ]/' {} +
echo "SDK instal·lat a $DEST/iPhoneOS9.3.sdk"
