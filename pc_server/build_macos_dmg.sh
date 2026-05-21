#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
export SCRIPT_DIR

sanitize_output() {
  perl -pe 's/\Q$ENV{SCRIPT_DIR}\E/<PROJECT_ROOT>\/pc_server/g; s/\Q$ENV{HOME}\E/<HOME>/g; s#/Users/[^[:space:]]+#<HOME>#g; s#/Applications/[^[:space:]]+#<APPLICATIONS_PATH>#g'
}

PYTHON="${PYTHON:-python3}"
APP_NAME="SoloDrop"
APP_VERSION="0.3.0"
APP_BUNDLE="dist/${APP_NAME}.app"
DMG_ROOT="build/macos/dmg-root"
ICONSET="build/macos/${APP_NAME}.iconset"
ICON_ICNS="build/macos/${APP_NAME}.icns"
DMG_PATH="installer/${APP_NAME}Setup-macOS.dmg"
ICON_SOURCE="static/icons/app-icon-1024.png"

echo "SoloDrop macOS packaging"

if [ ! -d ".venv" ]; then
  "$PYTHON" -m venv .venv
fi

.venv/bin/python -m pip install --upgrade pip >/dev/null
.venv/bin/python -m pip install -r requirements-macos.txt "pyinstaller==6.20.0" >/dev/null

rm -rf "build/${APP_NAME}" "dist/${APP_NAME}" "$APP_BUNDLE" "$DMG_ROOT" "$ICONSET" "$ICON_ICNS" "$DMG_PATH"
mkdir -p build/macos dist installer "$ICONSET"

if [ -f "$ICON_SOURCE" ]; then
  sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET/icon_16x16.png" >/dev/null
  sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET/icon_32x32.png" >/dev/null
  sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET/icon_128x128.png" >/dev/null
  sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET/icon_256x256.png" >/dev/null
  sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
  iconutil -c icns "$ICONSET" -o "$ICON_ICNS"
fi

PYINSTALLER_ARGS=(
  --noconfirm
  --clean
  --log-level WARN
  --windowed
  --name "$APP_NAME"
  --osx-bundle-identifier "app.solodrop.desktop"
  --add-data "static:static"
  --add-data "config.example.json:."
  --hidden-import "webview.platforms.cocoa"
  --collect-submodules "webview"
)

if [ -f "$ICON_ICNS" ]; then
  PYINSTALLER_ARGS+=(--icon "$ICON_ICNS")
fi

.venv/bin/python -m PyInstaller "${PYINSTALLER_ARGS[@]}" macos_app.py 2>&1 | sanitize_output

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${APP_VERSION}" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${APP_VERSION}" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string ${APP_VERSION}" "$APP_BUNDLE/Contents/Info.plist"

find "$APP_BUNDLE" -path "*.dist-info/RECORD" -delete
find "$APP_BUNDLE" -type d -name "__pycache__" -prune -exec rm -rf {} +

if [ -e "$APP_BUNDLE/Contents/Resources/config.json" ] || [ -e "$APP_BUNDLE/Contents/Resources/data" ] || [ -e "$APP_BUNDLE/Contents/Resources/logs" ]; then
  echo "Packaging check failed: runtime files were copied into the app bundle." >&2
  exit 1
fi

codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null

mkdir -p "$DMG_ROOT"
cp -R "$APP_BUNDLE" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_ROOT" -ov -format UDZO "$DMG_PATH" >/dev/null
hdiutil verify "$DMG_PATH" >/dev/null

echo "Built <PROJECT_ROOT>/pc_server/${APP_BUNDLE}"
echo "Built <PROJECT_ROOT>/pc_server/${DMG_PATH}"
