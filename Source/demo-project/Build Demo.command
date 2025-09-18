#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Hello Make It So"
ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/Sources"
BUILD="$ROOT/build"
APP="$BUILD/${APP_NAME}.app"

echo "🔧 Building demo app with swiftc (no Xcode project needed)…"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Hello Make It So</string>
  <key>CFBundleExecutable</key><string>HelloMakeItSo</string>
  <key>CFBundleIdentifier</key><string>com.example.hello-makeitso</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>11.0</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

# Compile SwiftUI app
swiftc -target x86_64-apple-macos11 -sdk "$(xcrun --show-sdk-path --sdk macosx)" \
  -framework AppKit -framework SwiftUI -framework Combine \
  "$SRC/main.swift" "$SRC/ContentView.swift" \
  -o "$APP/Contents/MacOS/HelloMakeItSo"

# Ad-hoc sign for easy launch
codesign -s - --force --timestamp=none "$APP" >/dev/null 2>&1 || true

echo "✅ Demo app built → $APP"
open "$BUILD" >/dev/null 2>&1 || true
