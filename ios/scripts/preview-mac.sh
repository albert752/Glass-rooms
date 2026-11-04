#!/bin/sh
# Development aid: build the same UIKit sources as a Mac Catalyst app to look at the interface on
# this Mac. It is NOT the iOS 9 build and proves nothing about the iPad; use ios/scripts/build.sh.
#   ios/scripts/preview-mac.sh                       # build ios/build/preview/GlassRooms.app
#   GR_SNAPSHOT_DIR=/tmp/shots ios/scripts/preview-mac.sh -glass-rooms-server http://127.0.0.1:8099
set -eu
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
SRC="$ROOT/ios/GlassRooms"
OUT="$ROOT/ios/build/preview"
MACSDK=$(xcrun --sdk macosx --show-sdk-path)
APP="$OUT/GlassRooms.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
clang -target arm64-apple-ios15.0-macabi -isysroot "$MACSDK" \
  -iframework "$MACSDK/System/iOSSupport/System/Library/Frameworks" -F "$MACSDK/System/iOSSupport/System/Library/Frameworks" \
  -L "$MACSDK/System/iOSSupport/usr/lib" -fobjc-arc -Wno-deprecated-declarations -DGR_VERSION='"preview"' -I "$SRC" \
  "$SRC"/*.m "$ROOT/ios/Preview/GRSnapshot.m" -framework UIKit -framework Foundation -framework CoreGraphics -framework QuartzCore -framework Security \
  -o "$APP/Contents/MacOS/GlassRooms"
cp "$SRC"/Resources/*.png "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>GlassRooms</string>
<key>CFBundleIdentifier</key><string>cat.glassrooms.preview</string>
<key>CFBundleName</key><string>Glass Rooms Preview</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0</string>
<key>LSMinimumSystemVersion</key><string>12.0</string>
<key>UIDeviceFamily</key><array><integer>2</integer></array>
<key>NSAppTransportSecurity</key><dict><key>NSAllowsArbitraryLoads</key><true/></dict>
</dict></plist>
EOF
xattr -cr "$APP"
codesign --force --sign - "$APP" 2>/dev/null
echo "$APP"
if [ -n "${GR_SNAPSHOT_DIR:-}" ]; then
  mkdir -p "$GR_SNAPSHOT_DIR"
  "$APP/Contents/MacOS/GlassRooms" "$@"
fi
