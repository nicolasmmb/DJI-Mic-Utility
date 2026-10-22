#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${1:-release}"
cd "$ROOT"

swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"
APP="$ROOT/Release/DJIMic.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_DIR/DJIMicApp" "$APP/Contents/MacOS/DJIMicApp"
cp "$ROOT/Packaging/Info.plist" "$APP/Contents/Info.plist"

shopt -s nullglob
for bundle in "$BIN_DIR"/*.bundle; do
    cp -R "$bundle" "$APP/Contents/Resources/"
done

cp -R "$ROOT/Packaging/en.lproj" "$APP/Contents/Resources/"
cp -R "$ROOT/Packaging/pt-BR.lproj" "$APP/Contents/Resources/"

chmod +x "$APP/Contents/MacOS/DJIMicApp"
xattr -cr "$APP" 2>/dev/null || true
codesign --force --deep --sign - "$APP"

echo "Built $APP"
