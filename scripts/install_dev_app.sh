#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_APP="$ROOT_DIR/dist/Pifagor Switcher.app"
TARGET_APP="/Applications/Pifagor Switcher.app"
BUNDLE_ID="app.pifagor.switcher"
RESET_PERMISSIONS="${1:-}"
SIGNING_REQUIREMENT='=designated => identifier "app.pifagor.switcher"'

"$ROOT_DIR/scripts/package_app.sh"

pkill -f "$TARGET_APP/Contents/MacOS/PifagorSwitcher" 2>/dev/null || true
pkill -f "$SOURCE_APP/Contents/MacOS/PifagorSwitcher" 2>/dev/null || true

rm -rf "$TARGET_APP"
ditto "$SOURCE_APP" "$TARGET_APP"

xattr -cr "$TARGET_APP" 2>/dev/null || true

codesign --force --deep --sign - --requirements="$SIGNING_REQUIREMENT" "$TARGET_APP" >/dev/null

if [[ "$RESET_PERMISSIONS" == "--reset-permissions" ]]; then
    tccutil reset Accessibility "$BUNDLE_ID" >/dev/null 2>&1 || true
    tccutil reset ListenEvent "$BUNDLE_ID" >/dev/null 2>&1 || true
fi

echo "Installed: $TARGET_APP"
echo "Next: open the app, then grant Accessibility and Input Monitoring in System Settings."
