#!/bin/bash
# macOS-friendly; resolves icon path relative to this script's folder
set -euo pipefail

say()  { printf "\n\033[1m%s\033[0m\n" "$*"; }
note() { printf "• %s\n" "$*"; }
ok()   { printf "\033[32m✔ %s\033[0m\n" "$*"; }
warn() { printf "\033[33m⚠ %s\033[0m\n" "$*"; }
err()  { printf "\033[31m✖ %s\033[0m\n" "$*"; }

usage() {
cat <<'HELP'
Change App Icon — V3
Looks for your icon next to this script, not your current Terminal folder.
Checks (in order):
  1) <script folder>/art/icon.png   ← preferred
  2) <script folder>/icon.png
  3) ./art/icon.png (current folder)
  4) ./icon.png (current folder)
Or you can drag a PNG path when prompted.
HELP
}

usage

# Resolve script directory (works for paths with spaces)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
note "Script folder: $SCRIPT_DIR"

# Try standard locations relative to the script, then current dir
CANDIDATES=(
  "$SCRIPT_DIR/art/icon.png"
  "$SCRIPT_DIR/icon.png"
  "./art/icon.png"
  "./icon.png"
)

ICON=""
for p in "${CANDIDATES[@]}"; do
  if [ -f "$p" ]; then ICON="$p"; break; fi
done

if [ -z "$ICON" ]; then
  warn "No icon found in: ${CANDIDATES[*]}"
  printf "Drag a PNG here or type a path, then press Return: "
  IFS= read -r ICON || true
  ICON="${ICON%\"}"; ICON="${ICON#\"}"
fi

if [ -z "$ICON" ] || [ ! -f "$ICON" ]; then
  err "Icon file not found. Please place it at <project>/art/icon.png or provide a valid path."
  exit 1
fi

say "Using icon: $ICON"

# Validate tools
if ! command -v sips >/dev/null 2>&1; then
  err "'sips' missing (macOS built-in). Cannot continue."
  exit 1
fi
if ! command -v iconutil >/dev/null 2>&1; then
  err "'iconutil' missing. Install Xcode Command Line Tools: xcode-select --install"
  exit 1
fi

W=$(sips -g pixelWidth "$ICON" 2>/dev/null | awk '/pixelWidth/{print $2}')
H=$(sips -g pixelHeight "$ICON" 2>/dev/null | awk '/pixelHeight/{print $2}')
note "PNG dimensions: ${W}x${H} (square & 1024×1024 recommended)"

# Choose app (prefer most recent in dist under script folder)
DEFAULT_APP=""
if ls -td "$SCRIPT_DIR"/dist/*/app/*.app >/dev/null 2>&1; then
  DEFAULT_APP=$(ls -td "$SCRIPT_DIR"/dist/*/app/*.app 2>/dev/null | head -n1)
elif ls -td dist/*/app/*.app >/dev/null 2>&1; then
  DEFAULT_APP=$(ls -td dist/*/app/*.app 2>/dev/null | head -n1)
fi

printf "\nTarget .app (drag here or press Return to use: %s): " "${DEFAULT_APP:-none}"
IFS= read -r APP || true
APP="${APP%\"}"; APP="${APP#\"}"
[ -z "$APP" ] && APP="$DEFAULT_APP"

if [ -z "$APP" ] || [ ! -d "$APP" ]; then
  err "App bundle not found. Please provide a valid .app path."
  exit 1
fi

say "Embedding icon into: $APP"

TMP=$(mktemp -d "/tmp/makeitso_icon.XXXXXX")
ICONSET="$TMP/AppIcon.iconset"
ICNS_OUT="$TMP/AppIcon.icns"
mkdir -p "$ICONSET"

for s in 16 32 64 128 256 512 1024; do
  sips -z "$s" "$s" "$ICON" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
done
cp "$ICONSET/icon_32x32.png"     "$ICONSET/icon_16x16@2x.png"
cp "$ICONSET/icon_64x64.png"     "$ICONSET/icon_32x32@2x.png"
cp "$ICONSET/icon_128x128.png"   "$ICONSET/icon_64x64@2x.png"
cp "$ICONSET/icon_256x256.png"   "$ICONSET/icon_128x128@2x.png"
cp "$ICONSET/icon_512x512.png"   "$ICONSET/icon_256x256@2x.png"
cp "$ICONSET/icon_1024x1024.png" "$ICONSET/icon_512x512@2x.png"

if ! iconutil -c icns "$ICONSET" -o "$ICNS_OUT" >/dev/null 2>&1; then
  err "iconutil failed to create .icns from your PNG."
  rm -rf "$TMP"
  exit 1
fi
ok ".icns created → $ICNS_OUT"

RES="$APP/Contents/Resources"
PLIST="$APP/Contents/Info.plist"
mkdir -p "$RES"
cp -f "$ICNS_OUT" "$RES/AppIcon.icns"

/usr/libexec/PlistBuddy -c "Delete :CFBundleIcons" "$PLIST" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" "$PLIST" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$PLIST" >/dev/null 2>&1 \
  || /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$PLIST" >/dev/null 2>&1

ok "Info.plist updated (CFBundleIconFile = AppIcon)"

if command -v codesign >/dev/null 2>&1; then
  if codesign --force -s - --deep --timestamp=none "$APP" >/dev/null 2>&1; then
    ok "App re-signed locally (ad-hoc)."
  else
    warn "codesign failed (non-fatal)."
  fi
else
  warn "codesign not found; skipping re-sign."
fi

touch "$APP" || true
open -R "$APP" >/dev/null 2>&1 || true

say "Done. If Finder still shows the old icon:"
note "1) Move/rename the .app, then move it back."
note "2) Or relaunch Finder (⌥ Right‑click Finder in Dock → Relaunch)."

rm -rf "$TMP" || true
exit 0
