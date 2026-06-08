#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$SCRIPT_DIR/MemoryGuard.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"

# Build
swift build --configuration debug 2>&1
BIN_PATH="$(swift build --configuration debug --show-bin-path)"

# Bundle structure
rm -rf "$APP_DIR"
mkdir -p "$MACOS"
mkdir -p "$CONTENTS/Resources"

# Copy binary
cp "$BIN_PATH/MemoryGuard" "$MACOS/MemoryGuard"

# Copy Info.plist
cp "$SCRIPT_DIR/Sources/MemoryGuard/Info.plist" "$CONTENTS/Info.plist"

# Ad-hoc sign
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true

echo "Built: $APP_DIR"
echo "Run:   open '$APP_DIR'"
