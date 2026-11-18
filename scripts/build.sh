#!/bin/bash
# Builds dist/Rise-<version>.dmg, no stray Rise.app; --install swaps the installed app in place
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
DMG=dist/Rise-$VERSION.dmg
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/rise-build.XXXXXX")
APP=$STAGE/Rise.app
forget() { [ -d "$1" ] && "$LSREGISTER" -u "$1" >/dev/null 2>&1; rm -rf "$1"; }
trap 'forget "$APP"; forget "$STAGE/dmg/Rise.app"; rm -rf "$STAGE"' EXIT

forget build/Rise.app
forget build/dmg/Rise.app
rm -rf build/dmg

swift test
swift build -c release --product Rise --triple arm64-apple-macosx14.0
swift build -c release --product Rise --triple x86_64-apple-macosx14.0
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build dist
lipo -create .build/arm64-apple-macosx/release/Rise .build/x86_64-apple-macosx/release/Rise \
  -output "$APP/Contents/MacOS/Rise"
cp Resources/Info.plist "$APP/Contents/Info.plist"

rm -rf build/AppIcon.iconset
mkdir -p build/AppIcon.iconset
swift scripts/make-icon.swift build/icon-1024.png
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" build/icon-1024.png --out "build/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" build/icon-1024.png --out "build/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
"$APP/Contents/MacOS/Rise" --self-test

mkdir -p "$STAGE/dmg"
cp -R "$APP" "$STAGE/dmg/"
ln -s /Applications "$STAGE/dmg/Applications"
cp "$APP/Contents/Resources/AppIcon.icns" "$STAGE/dmg/.VolumeIcon.icns"
SetFile -c icnC "$STAGE/dmg/.VolumeIcon.icns"
SetFile -a C "$STAGE/dmg"
rm -f "$DMG"
hdiutil create -volname Rise -srcfolder "$STAGE/dmg" -ov -format UDZO "$DMG" >/dev/null
hdiutil verify "$DMG" >/dev/null
echo "$DMG"

if [ "${1:-}" = "--install" ]; then
  osascript -e 'tell application id "com.vsssp.rise" to quit' >/dev/null 2>&1 || true
  for _ in $(seq 20); do pgrep -f /Applications/Rise.app/Contents/MacOS/Rise >/dev/null || break; sleep 0.5; done
  rm -rf /Applications/Rise.app
  ditto "$APP" /Applications/Rise.app
  open /Applications/Rise.app
  echo "installed /Applications/Rise.app $VERSION"
fi
