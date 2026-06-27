#!/bin/bash
# Builds CyberTranslate.app (a native macOS app bundle) from the Swift package.
# Usage: ./build.sh        -> builds dist/CyberTranslate.app
#        ./build.sh run    -> builds and launches it
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="CyberTranslate"
BUNDLE_ID="com.cyber.translate"
DIST="dist"
APP="$DIST/$APP_NAME.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RES="$CONTENTS/Resources"

echo "▸ Building release binary…"
swift build -c release

echo "▸ Assembling app bundle…"
rm -rf "$APP"
mkdir -p "$MACOS" "$RES"
cp ".build/release/$APP_NAME" "$MACOS/$APP_NAME"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>     <string>Cyber·Translate</string>
    <key>CFBundleIdentifier</key>      <string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key>      <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>1.0</string>
    <key>CFBundleVersion</key>         <string>1</string>
    <key>LSMinimumSystemVersion</key>  <string>14.0</string>
    <key>NSHighResolutionCapable</key> <true/>
    <key>NSPrincipalClass</key>        <string>NSApplication</string>
    <key>NSHumanReadableCopyright</key><string>Local build — personal use.</string>
</dict>
</plist>
PLIST

echo "▸ Code signing (ad-hoc)…"
# Ad-hoc signing gives a stable identity so Accessibility permission sticks.
codesign --force --deep --sign - "$APP" 2>/dev/null || \
  echo "  (codesign skipped — app still runs; you may re-grant Accessibility after rebuilds)"

echo "✓ Built: $APP"

if [[ "${1:-}" == "run" ]]; then
    echo "▸ Launching…"
    open "$APP"
fi
