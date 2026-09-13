#!/bin/bash
#
# Build Vigil.app from source. No Xcode needed — just Command Line Tools.
#
#   ./build.sh            -> build/Vigil.app
#   ./build.sh --dmg      -> build/Vigil.app + build/Vigil.dmg
#
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Vigil.app"
VERSION="${VERSION:-1.2.0}"

echo "› Compiling…"
mkdir -p build
swiftc -parse-as-library -O -target arm64-apple-macosx14.0 \
       App/Sources/*.swift -o build/Vigil
swiftc -O -target arm64-apple-macosx14.0 \
       App/Sources/Sensors.swift App/SensorsCLI/main.swift -o build/vigil-sensors

echo "› Rendering icon…"
swiftc scripts/make_icon.swift -o build/make_icon
build/make_icon build/icon-1024.png >/dev/null
ICONSET="build/Vigil.iconset"
rm -rf "$ICONSET" && mkdir -p "$ICONSET"
for s in 16 32 64 128 256 512; do
    sips -z $s $s build/icon-1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    d=$((s * 2))
    sips -z $d $d build/icon-1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o build/Vigil.icns

echo "› Assembling bundle…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/daemon"
cp build/Vigil "$APP/Contents/MacOS/Vigil"
cp build/Vigil.icns "$APP/Contents/Resources/Vigil.icns"
cp daemon/vigild.py daemon/thermal.py daemon/com.vigil.daemon.plist build/vigil-sensors "$APP/Contents/Resources/daemon/"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>             <string>Vigil</string>
    <key>CFBundleDisplayName</key>      <string>守夜</string>
    <key>CFBundleIdentifier</key>       <string>app.vigil.Vigil</string>
    <key>CFBundleExecutable</key>       <string>Vigil</string>
    <key>CFBundleIconFile</key>         <string>Vigil</string>
    <key>CFBundlePackageType</key>      <string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key>          <string>1</string>
    <key>LSMinimumSystemVersion</key>   <string>14.0</string>
    <key>LSUIElement</key>              <true/>
    <key>NSHumanReadableCopyright</key> <string>MIT License</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP" >/dev/null 2>&1
echo "✅ Built $APP"

if [ "${1:-}" = "--dmg" ]; then
    echo "› Packaging DMG…"
    STAGE="build/dmg"
    rm -rf "$STAGE" build/Vigil.dmg && mkdir -p "$STAGE"
    cp -R "$APP" "$STAGE/"
    ln -s /Applications "$STAGE/Applications"
    hdiutil create -volname "守夜 Vigil" -srcfolder "$STAGE" -ov -format UDZO build/Vigil.dmg >/dev/null
    rm -rf "$STAGE"
    echo "✅ Built build/Vigil.dmg"
fi
