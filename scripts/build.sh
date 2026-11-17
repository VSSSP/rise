#!/bin/bash
# Builds build/Rise.app and the drag-to-install dist/Rise-<version>.dmg: scripts/build.sh
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
APP=build/Rise.app
DMG=dist/Rise-$VERSION.dmg

swift test
swift build -c release --product Rise
rm -rf "$APP" build/AppIcon.iconset build/dmg
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/AppIcon.iconset dist
cp "$(swift build -c release --show-bin-path)/Rise" "$APP/Contents/MacOS/Rise"
cp Resources/Info.plist "$APP/Contents/Info.plist"

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

mkdir -p build/dmg
cp -R "$APP" build/dmg/
ln -s /Applications build/dmg/Applications
cp "$APP/Contents/Resources/AppIcon.icns" build/dmg/.VolumeIcon.icns
SetFile -c icnC build/dmg/.VolumeIcon.icns
SetFile -a C build/dmg
rm -f "$DMG"
hdiutil create -volname Rise -srcfolder build/dmg -ov -format UDZO "$DMG" >/dev/null
hdiutil verify "$DMG" >/dev/null
echo "$DMG"
