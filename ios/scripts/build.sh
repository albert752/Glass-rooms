#!/bin/sh
# Build Glass Rooms for iPad (iOS 9.0+, armv7 for the iPad mini 1 plus arm64) without Xcode:
# Command Line Tools clang/ld + iPhoneOS9.3.sdk. Output: ios/build/GlassRooms.ipa (ad hoc signed,
# ready to re-sign with a sideloading tool).
#   BUNDLE_ID=cat.exemple.glassrooms ios/scripts/build.sh
set -eu
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
SRC="$ROOT/ios/GlassRooms"
SDK=${GR_IOS_SDK:-"$ROOT/ios/.sdk/iPhoneOS9.3.sdk"}
BUILD="$ROOT/ios/build"
# Sign in a temporary folder: synced folders (iCloud Documents) re-add Finder metadata that codesign rejects.
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
BUNDLE_ID=${BUNDLE_ID:-cat.glassrooms.panel}
VERSION=$(sed -n 's/^version: "\(.*\)"$/\1/p' "$ROOT/glass_rooms/config.yaml")
[ -n "$VERSION" ] || { echo "No s'ha trobat la versió a glass_rooms/config.yaml" >&2; exit 1; }
[ -d "$SDK" ] || "$ROOT/ios/scripts/fetch-sdk.sh"

rm -rf "$BUILD"
mkdir -p "$BUILD/obj" "$STAGE/Payload/GlassRooms.app"
APP="$STAGE/Payload/GlassRooms.app"
compile() {
  clang -arch "$1" -isysroot "$SDK" -miphoneos-version-min=9.0 -fobjc-arc -Os -g0 -Wall -Wextra -Wno-unused-parameter \
    -Werror -Werror=unguarded-availability -fno-objc-msgsend-selector-stubs -fno-exceptions -fno-objc-exceptions -DGR_VERSION="\"$VERSION\"" -c "$2" -o "$3"
}

for ARCH in armv7 arm64; do
  for FILE in "$SRC"/*.m; do
    compile "$ARCH" "$FILE" "$BUILD/obj/$ARCH-$(basename "$FILE" .m).o"
  done
  # Old .tbd stubs do not say device or simulator; ld warns about it, harmlessly.
  clang -arch "$ARCH" -isysroot "$SDK" -miphoneos-version-min=9.0 "$BUILD/obj/$ARCH-"*.o \
    -framework UIKit -framework Foundation -framework CoreGraphics -framework QuartzCore \
    -framework CFNetwork -framework Security -dead_strip \
    -o "$BUILD/obj/GlassRooms-$ARCH" 2>"$BUILD/obj/ld-$ARCH.log" || { cat "$BUILD/obj/ld-$ARCH.log" >&2; exit 1; }
  if grep -v "built for iOS Simulator" "$BUILD/obj/ld-$ARCH.log" | grep -q .; then
    grep -v "built for iOS Simulator" "$BUILD/obj/ld-$ARCH.log" >&2
  fi
done
lipo -create "$BUILD/obj/GlassRooms-armv7" "$BUILD/obj/GlassRooms-arm64" -output "$APP/GlassRooms"

sed -e "s/__VERSION__/$VERSION/g" -e "s/__BUNDLE_ID__/$BUNDLE_ID/g" "$SRC/Info.plist" > "$APP/Info.plist"
plutil -lint "$APP/Info.plist" >/dev/null
plutil -convert binary1 "$APP/Info.plist"
printf 'APPL????' > "$APP/PkgInfo"
cp "$SRC"/Resources/*.png "$APP/"
# Ad hoc signature with SHA-1 and SHA-256 code directories (iOS 9 checks SHA-1).
xattr -cr "$APP"
codesign --force --sign - --digest-algorithm=sha1,sha256 --timestamp=none "$APP" 2>&1 | grep -v "signing with SHA1 will be deprecated" >&2 || true
codesign --verify --strict "$APP"
(cd "$STAGE" && zip -qry -X "$BUILD/GlassRooms.ipa" Payload)
echo "Glass Rooms $VERSION · $BUILD/GlassRooms.ipa"
