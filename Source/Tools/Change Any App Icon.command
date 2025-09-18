#!/bin/bash
# Change Any App Icon.command
# A friendly utility to set a custom icon on ANY .app bundle.
# - Lets you pick the PNG via a file dialog (or --icon <path>).
# - Validates PNG and can resize to 1024 if needed (with a warning).
# - Converts PNG -> .icns with macOS tools (sips + iconutil).
# - Lets you pick the target .app via a file dialog (or --app <path>).
# - Cleans Info.plist override keys, sets CFBundleIconFile, and re‑signs ad‑hoc.
# No README needed—this script explains itself in the comments and output.
#
# Contact: makeitsoapp@proton.me

set -euo pipefail

# ----------------------------- Styling helpers ---------------------------------
say()  { printf "\n\033[1m%s\033[0m\n" "$*"; }
note() { printf "• %s\n" "$*"; }
ok()   { printf "\033[32m✔ %s\033[0m\n" "$*"; }
warn() { printf "\033[33m⚠ %s\033[0m\n" "$*"; }
err()  { printf "\033[31m✖ %s\033[0m\n" "$*"; }

# ----------------------------- Usage / flags -----------------------------------
usage() {
  cat <<'HELP'
Change Any App Icon — How to use
--------------------------------
Double‑click to run interactively, or pass flags:

  --icon <path>      PNG to use (square, ideally 1024×1024)
  --app  <path>      Target .app
  --force-resize     If PNG is not 1024×1024, resize to 1024 (may squish if not square)
  --help             Show this help

No flags? The script will open a macOS file picker for the PNG and then for the .app.
HELP
}

ICON_ARG=""
APP_ARG=""
FORCE_RESIZE=false

# Show help if no args and running in Terminal is fine—still interactive later
if [[ $# -gt 0 ]]; then
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h) usage; exit 0;;
      --icon) ICON_ARG="${2:-}"; shift 2;;
      --app)  APP_ARG="${2:-}"; shift 2;;
      --force-resize) FORCE_RESIZE=true; shift;;
      *) warn "Unknown arg: $1"; usage; exit 1;;
    esac
  done
fi

# ----------------------------- Tool checks -------------------------------------
need() { command -v "$1" >/dev/null 2>&1 || { err "Missing: $1"; return 1; }; }

# sips and iconutil are required
need sips || { err "'sips' is a macOS tool (should be present)."; exit 1; }
need iconutil || { err "'iconutil' missing. Install Command Line Tools: xcode-select --install"; exit 1; }

# Optional: osascript for dialogs; script still works without it
HAVE_OSASCRIPT=false
if command -v osascript >/dev/null 2>&1; then HAVE_OSASCRIPT=true; fi

# ----------------------------- Pick PNG ----------------------------------------
PNG="$ICON_ARG"

if [[ -z "$PNG" ]]; then
  if $HAVE_OSASCRIPT; then
    say "Pick a PNG to use as the app icon…"
    # Ask for a file; constrain to public.png if available
    PNG=$(osascript <<'APPLESCRIPT' 2>/dev/null || true)
try
  set f to choose file with prompt "Select a PNG icon" of type {"public.png"}
  POSIX path of f
on error
  ""
end try
APPLESCRIPT
    )
    # osascript sometimes returns with a trailing newline
    PNG="$(printf "%s" "$PNG")"
  fi
fi

# Fallback to prompt if no osascript or cancelled
if [[ -z "$PNG" ]]; then
  printf "Drag a PNG here (or type a path), then press Return: "
  IFS= read -r PNG || true
fi

# Clean quotes
PNG="${PNG%\"}"; PNG="${PNG#\"}"

# Validate PNG presence
if [[ -z "$PNG" || ! -f "$PNG" ]]; then
  err "PNG not provided or not found."
  usage
  exit 1
fi

say "Using PNG: $PNG"

# Quick type check
FILETYPE=$(file -b "$PNG" || true)
if ! echo "$FILETYPE" | grep -qi "png"; then
  err "Selected file does not look like a PNG (detected: $FILETYPE)."
  exit 1
fi

# Get dimensions
W=$(sips -g pixelWidth "$PNG" 2>/dev/null | awk '/pixelWidth/{print $2}')
H=$(sips -g pixelHeight "$PNG" 2>/dev/null | awk '/pixelHeight/{print $2}')
note "PNG dimensions: ${W}x${H}"

# Validate dimensions; offer resize if needed
if [[ -z "$W" || -z "$H" ]]; then
  err "Could not read PNG dimensions with 'sips'."
  exit 1
fi

if [[ "$W" != "$H" ]]; then
  warn "Icon is not square. macOS icons are square."
  if $FORCE_RESIZE; then
    warn "Proceeding with a forced resize to 1024×1024 (image may look stretched)."
  else
    printf "Resize to 1024×1024 now? (may stretch) [y/N]: "
    read -r ans; if [[ ! "${ans:-}" =~ ^[Yy]$ ]]; then
      err "Aborting. Please provide a square PNG (e.g., 1024×1024)."
      exit 1
    fi
    FORCE_RESIZE=true
  fi
fi

if [[ "$W" -lt 256 || "$H" -lt 256 ]]; then
  warn "Icon is very small (<256). It may look blurry after scaling."
fi

# If forced or not 1024, make a copy at 1024×1024
WORK_DIR=$(mktemp -d "/tmp/change_any_icon.XXXXXX")
PNG_WORK="$WORK_DIR/icon_1024.png"
if $FORCE_RESIZE || [[ "$W" -ne 1024 || "$H" -ne 1024 ]]; then
  note "Creating a 1024×1024 copy (original remains unchanged)…"
  if sips -z 1024 1024 "$PNG" --out "$PNG_WORK" >/dev/null 2>&1; then
    ok "Resized copy created at: $PNG_WORK"
  else
    err "Failed to resize the PNG."
    rm -rf "$WORK_DIR"
    exit 1
  fi
else
  cp "$PNG" "$PNG_WORK"
fi

# ----------------------------- Convert to .icns --------------------------------
ICONSET="$WORK_DIR/AppIcon.iconset"
ICNS="$WORK_DIR/AppIcon.icns"
mkdir -p "$ICONSET"

for s in 16 32 64 128 256 512 1024; do
  sips -z "$s" "$s" "$PNG_WORK" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
done
cp "$ICONSET/icon_32x32.png"     "$ICONSET/icon_16x16@2x.png"
cp "$ICONSET/icon_64x64.png"     "$ICONSET/icon_32x32@2x.png"
cp "$ICONSET/icon_128x128.png"   "$ICONSET/icon_64x64@2x.png"
cp "$ICONSET/icon_256x256.png"   "$ICONSET/icon_128x128@2x.png"
cp "$ICONSET/icon_512x512.png"   "$ICONSET/icon_256x256@2x.png"
cp "$ICONSET/icon_1024x1024.png" "$ICONSET/icon_512x512@2x.png" 2>/dev/null || true

if ! iconutil -c icns "$ICONSET" -o "$ICNS" >/dev/null 2>&1; then
  err "iconutil failed to create .icns. Is your PNG valid?"
  rm -rf "$WORK_DIR"
  exit 1
fi
ok ".icns created → $ICNS"

# ----------------------------- Pick target .app --------------------------------
APP="$APP_ARG"

if [[ -z "$APP" ]]; then
  if $HAVE_OSASCRIPT; then
    say "Pick the target .app to receive the new icon…"
    APP=$(osascript <<'APPLESCRIPT' 2>/dev/null || true)
try
  set f to choose file with prompt "Select the .app bundle" of type {"com.apple.application-bundle"}
  POSIX path of f
on error
  ""
end try
APPLESCRIPT
    )
    APP="$(printf "%s" "$APP")"
  fi
fi

if [[ -z "$APP" ]]; then
  printf "Drag a .app here (or type a path), then press Return: "
  IFS= read -r APP || true
fi

APP="${APP%\"}"; APP="${APP#\"}"

if [[ -z "$APP" || ! -d "$APP" || "${APP##*.}" != "app" ]]; then
  err "Target is not a valid .app bundle."
  rm -rf "$WORK_DIR"
  exit 1
fi

say "Embedding icon into: $APP"

RES="$APP/Contents/Resources"
PLIST="$APP/Contents/Info.plist"
mkdir -p "$RES"
cp -f "$ICNS" "$RES/AppIcon.icns"

/usr/libexec/PlistBuddy -c "Delete :CFBundleIcons" "$PLIST" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" "$PLIST" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$PLIST" >/dev/null 2>&1 \
  || /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$PLIST" >/dev/null 2>&1

ok "Info.plist updated (CFBundleIconFile = AppIcon)"
if command -v codesign >/dev/null 2>&1; then
  if codesign --force -s - --deep --timestamp=none "$APP" >/dev/null 2>&1; then
    ok "App re-signed locally (ad‑hoc)."
  else
    warn "codesign failed (non‑fatal)."
  fi
else
  warn "codesign not found; skipping re‑sign."
fi

touch "$APP" || true
open -R "$APP" >/dev/null 2>&1 || true

say "Done. If Finder still shows the old icon:"
note "1) Move/rename the .app, then move it back."
note "2) Or relaunch Finder (⌥ Right‑click Finder in Dock → Relaunch)."

# Clean temp
rm -rf "$WORK_DIR" || true
exit 0
