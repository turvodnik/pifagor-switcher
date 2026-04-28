#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/release"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="Pifagor Switcher"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
EXECUTABLE_NAME="PifagorSwitcher"
APP_VERSION="0.2.1"
BUNDLE_VERSION="3"
SIGNING_REQUIREMENT='=designated => identifier "app.pifagor.switcher"'
ICON_SOURCE="$ROOT_DIR/Assets/AppIcon.png"
ICONSET_DIR="$DIST_DIR/AppIcon.iconset"

swift build --configuration release --product "$EXECUTABLE_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$EXECUTABLE_NAME" "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"

if [[ -f "$ICON_SOURCE" ]]; then
    rm -rf "$ICONSET_DIR"
    mkdir -p "$ICONSET_DIR"
    sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
    sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
    sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
    sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
    sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
    sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
    sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
    sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
    sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
    cp "$ICON_SOURCE" "$ICONSET_DIR/icon_512x512@2x.png"
    iconutil -c icns "$ICONSET_DIR" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    cp "$ICON_SOURCE" "$APP_BUNDLE/Contents/Resources/AppIcon.png"
    sips -z 44 44 "$ICON_SOURCE" --out "$APP_BUNDLE/Contents/Resources/StatusIcon.png" >/dev/null
    rm -rf "$ICONSET_DIR"
fi

cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>ru</string>
    <key>CFBundleDisplayName</key>
    <string>Pifagor Switcher</string>
    <key>CFBundleExecutable</key>
    <string>PifagorSwitcher</string>
    <key>CFBundleIdentifier</key>
    <string>app.pifagor.switcher</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleGetInfoString</key>
    <string>Pifagor Switcher by Pifagor Apps. https://pifagor.studio</string>
    <key>CFBundleName</key>
    <string>Pifagor Switcher</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>__APP_VERSION__</string>
    <key>CFBundleVersion</key>
    <string>__BUNDLE_VERSION__</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSAccessibilityUsageDescription</key>
    <string>Pifagor Switcher использует Accessibility, чтобы безопасно исправлять последнее слово и отменять исправление.</string>
    <key>NSInputMonitoringUsageDescription</key>
    <string>Pifagor Switcher использует Input Monitoring, чтобы локально определять неправильную RU/EN раскладку во время набора.</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Pifagor Apps.</string>
    <key>PifagorDeveloperName</key>
    <string>Pifagor Apps</string>
    <key>PifagorDeveloperURL</key>
    <string>https://pifagor.studio</string>
</dict>
</plist>
PLIST

perl -0pi -e "s/__APP_VERSION__/$APP_VERSION/g; s/__BUNDLE_VERSION__/$BUNDLE_VERSION/g" "$APP_BUNDLE/Contents/Info.plist"

if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - --requirements="$SIGNING_REQUIREMENT" "$APP_BUNDLE" >/dev/null
fi

mkdir -p "$DIST_DIR"
ZIP_PATH="$DIST_DIR/PifagorSwitcher-v$APP_VERSION.zip"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

echo "$APP_BUNDLE"
echo "$ZIP_PATH"
