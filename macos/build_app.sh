#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/dist/CodeTouchBar.app"

mkdir -p "$ROOT/dist"
BUILD_DIR="$(mktemp -d "$ROOT/dist/CodeTouchBar-build.XXXXXX")"
trap 'rm -rf "$BUILD_DIR"' EXIT
BUILD_APP="$BUILD_DIR/CodeTouchBar.app"
CONTENTS="$BUILD_APP/Contents"

mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources/scripts" "$CONTENTS/Resources/assets" "$BUILD_DIR/module-cache"
cp "$ROOT/macos/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT/assets/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"
cp "$ROOT/scripts/"*_status.py "$CONTENTS/Resources/scripts/"
cp "$ROOT/scripts/metric.py" "$CONTENTS/Resources/scripts/"
cp "$ROOT/assets/"*.png "$CONTENTS/Resources/assets/"
clang -fobjc-arc -O2 -framework AppKit -framework Foundation -framework ServiceManagement -framework Security -framework CoreGraphics -framework CoreAudio \
    "$ROOT/macos/Sources/CodeTouchBarApp.m" \
    -o "$CONTENTS/MacOS/CodeTouchBar"

codesign --force --deep --sign - "$BUILD_APP"

if [ -e "$APP" ]; then
    rm -rf "$APP"
fi

mv "$BUILD_APP" "$APP"
printf 'App gerado com sucesso em: %s\n' "$APP"
