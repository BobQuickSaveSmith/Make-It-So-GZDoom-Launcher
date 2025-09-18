#!/bin/bash
# Make It So_V3 — Friendly.command
# One‑file, double‑clickable packager for macOS apps (friendly prompts)
# Contact: makeitsoapp@proton.me
# Compatible with macOS bash 3.2

set -euo pipefail

# ---------- UI helpers ----------
bold() { printf "\033[1m%s\033[0m\n" "$*"; }
ok()   { printf "✅ %s\n" "$*"; }
info() { printf "• %s\n" "$*"; }
warn() { printf "\033[33m⚠ %s\033[0m\n" "$*"; }
error(){ printf "\033[31m✖ %s\033[0m\n" "$*"; }
ask()  { read -r -p "$1 " _ans; [[ "${_ans:-}" =~ ^[Yy]$ || "${_ans:-}" =~ ^[Yy][Ee][Ss]$ ]]; }
die()  { error "$1"; exit 1; }
abspath() { (cd "$(dirname "$1")" >/dev/null 2>&1 && printf "%s/%s\n" "$PWD" "$(basename "$1")"); }
expand_tilde() {
  case "$1" in "~/"*) printf "%s" "${HOME}/${1#~/}" ;; "~") printf "%s" "${HOME}" ;; *) printf "%s" "$1" ;; esac
}
trim_all() { printf "%s" "$1" | tr -d '\r' | awk '{ gsub(/^[ \t]+|[ \t]+$/, "", $0); print }'; }
normalize_path() { local p="$1"; p="${p%\"}"; p="${p#\"}"; p="$(trim_all "$p")"; case "$p" in */) p="${p%/}";; esac; p="$(expand_tilde "$p")"; printf "%s" "$p"; }

outside_root(){
  local root="$1"; local path="$2"
  local dir="$(cd "$(dirname "$path")" 2>/dev/null && pwd)"
  local base="$(basename "$path")"
  local abs="$dir/$base"
  local root_abs="$(cd "$root" && pwd)"
  case "$abs" in "$root_abs"|"$root_abs"/*) return 1;; *) return 0;; esac
}

WRITE_HELPERS=false  # set true to copy helper templates into your project root

# ---------- Preflight ----------
bold "Welcome! This will build your macOS app, package it, and create shareable files."
info "It explains each step in plain English and suggests safe defaults."

bold "Step 0 — Checking your tools"
NEEDED_TOOLS=("xcodebuild" "rsync" "zip" "shasum" "xattr" "spctl" "/usr/libexec/PlistBuddy" "sips" "iconutil" "hdiutil" "codesign")
MISSING=0
for t in "${NEEDED_TOOLS[@]}"; do
  if [[ "$t" == "/usr/libexec/PlistBuddy" ]]; then
    [[ -x "$t" ]] || { warn "Missing: $t (we'll skip Info.plist edits if needed)"; MISSING=1; }
  else
    command -v "$t" >/dev/null 2>&1 || { warn "Missing tool: $t"; MISSING=1; }
  fi
done
if [[ $MISSING -ne 0 ]]; then
  warn "Some Apple tools are missing. If you see icon or plist warnings later, run: xcode-select --install"
else
  ok "Tools look good."
fi

# ---------- Workspace & project detection ----------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

bold "Step 1 — Finding your Xcode project"
PROJECTS=( *.xcodeproj )
if [[ ${#PROJECTS[@]} -eq 0 || "${PROJECTS[0]}" == "*.xcodeproj" ]]; then
  die "No .xcodeproj found here: $(pwd)
Place this file in the SAME folder as your Xcode project and run it again."
elif [[ ${#PROJECTS[@]} -gt 1 ]]; then
  echo "I see multiple Xcode projects:"
  i=1; for p in "${PROJECTS[@]}"; do echo "  $i) $p"; i=$((i+1)); done
  read -r -p "Type the number to use (default 1): " idx
  idx="${idx:-1}"
  PROJECT="${PROJECTS[$((idx-1))]}"
else
  PROJECT="${PROJECTS[0]}"
fi
ok "Using project: $PROJECT"

PRODUCT_NAME="${PROJECT%.xcodeproj}"

bold "Step 2 — Picking a build scheme"
SCHEMES_RAW="$(xcodebuild -list -project "$PROJECT" 2>/dev/null || true)"
SCHEMES=()
if [[ -n "$SCHEMES_RAW" ]]; then
  grab=0
  while IFS= read -r line; do
    [[ "$line" =~ Schemes: ]] && { grab=1; continue; }
    [[ $grab -eq 1 && -z "$line" ]] && break
    if [[ $grab -eq 1 ]]; then
      s="$(echo "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
      [[ -n "$s" ]] && SCHEMES+=("$s")
    fi
  done <<< "$SCHEMES_RAW"
fi
if [[ ${#SCHEMES[@]} -eq 0 ]]; then
  warn "No shared schemes detected; I'll try '$PRODUCT_NAME'."
  SCHEME="$PRODUCT_NAME"
elif [[ ${#SCHEMES[@]} -eq 1 ]]; then
  SCHEME="${SCHEMES[0]}"
else
  echo "Available schemes:"
  i=1; for s in "${SCHEMES[@]}"; do echo "  $i) $s"; i=$((i+1)); done
  read -r -p "Type the number to use (default 1): " idx
  idx="${idx:-1}"
  SCHEME="${SCHEMES[$((idx-1))]}"
fi
ok "Using scheme: $SCHEME"

CONFIG="Release"
OUT_ROOT="dist"
PKG_NAME="MakeItSo_Package_$(date +%Y-%m-%d_%H-%M-%S)"
PROTON_EMAIL="makeitsoapp@proton.me"

mkdir -p "$OUT_ROOT"
WORK="$OUT_ROOT/$PKG_NAME"
SRC_DIR="$WORK/source"
BIN_DIR="$WORK/build"
APP_DIR="$WORK/app"
mkdir -p "$SRC_DIR" "$BIN_DIR" "$APP_DIR"

# ---------- Optional safety backup (single ZIP) ----------
bold "Step 3 — Optional safety backup (recommended)"
echo "I can save a ZIP of your current project BEFORE we change anything."
echo "This is useful if you want a point-in-time snapshot."
if ask "Create a safety backup ZIP now? [Y/n]:"; then
  ICLOUD_DEFAULT="$HOME/Library/Mobile Documents/com~apple~CloudDocs/MakeItSo-Backups"
  echo "Where should the backup ZIP be saved?"
  echo "Default is your iCloud Drive folder:"
  echo "  $ICLOUD_DEFAULT"
  read -r -p "Press Return to use the default, or type another folder path: " CHOICE || true
  if [[ -z "${CHOICE:-}" ]]; then
    BASE="$ICLOUD_DEFAULT"
  else
    BASE="$(normalize_path "$CHOICE")"
  fi
  if ! outside_root "$SCRIPT_DIR" "$BASE"; then
    warn "That folder is INSIDE the project. Backups must be outside so they aren't included."
    read -r -p "Enter a different folder path (or press Return for the default): " BASE2 || true
    BASE="$(normalize_path "${BASE2:-$ICLOUD_DEFAULT}")"
  fi
  if [[ ! -d "$BASE" ]]; then
    warn "That folder does not exist yet."
    if ask "Create it now? [Y/n]:"; then
      mkdir -p "$BASE" && ok "Created: $BASE"
    else
      warn "Skipping backups and continuing."
      DO_BACKUP="no"
    fi
  fi
  DO_BACKUP="${DO_BACKUP:-yes}"
  if [[ "$DO_BACKUP" = "yes" ]]; then
    TS="$(date +%Y%m%d_%H%M%S)"
    BACKUP_ZIP="$BASE/MakeItSo_build_files_backup_${TS}.zip"
    bold "Creating backup ZIP (this may take a moment)…"
    /usr/bin/zip -r -q "$BACKUP_ZIP" . \
      -x "dist/*" ".git/*" "*DerivedData/*" "*.xcarchive" \
         "*.xcodeproj/project.xcworkspace/xcuserdata/*" "*.xcuserdatad/*" "*.xcuserdata/*"
    ok "Backup created → $BACKUP_ZIP"
  fi
else
  info "Okay, skipping the optional backup."
fi

# ---------- LICENSE & README ----------
[[ -f LICENSE ]] || cat > LICENSE <<'MIT'
MIT License

Copyright (c) 2025 Make It So

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the “Software”), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
MIT

[[ -f README.md ]] || cat > README.md <<EOF
# $PRODUCT_NAME

Support: $PROTON_EMAIL
EOF

# ---------- Copy source ----------
bold "Step 4 — Copying your source (excluding build/derived folders)"
rsync -a \
  --exclude ".git" \
  --exclude "$OUT_ROOT" \
  --exclude "DerivedData" \
  --exclude "build" \
  --exclude "*.xcarchive" \
  --exclude "*.xcuserdatad" \
  --exclude "*.xcuserdata" \
  ./ "$SRC_DIR/"
cp LICENSE README.md "$WORK/" 2>/dev/null || true
ok "Source copied into: $SRC_DIR"

# ---------- Build with Xcode ----------
bold "Step 5 — Building your app in Release"
ARCHIVE_PATH="$BIN_DIR/${PRODUCT_NAME}.xcarchive"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" \
           -archivePath "$ARCHIVE_PATH" -destination "generic/platform=macOS" \
           clean archive || die "Xcode build failed"

APP_PATH_IN_ARCHIVE="$(/usr/bin/find "$ARCHIVE_PATH/Products/Applications" -maxdepth 1 -type d -name "*.app" | head -n 1)"
[[ -d "$APP_PATH_IN_ARCHIVE" ]] || die "Build archive did not contain an .app"
APP_PATH="$APP_DIR/$(basename "$APP_PATH_IN_ARCHIVE")"
rsync -a "$APP_PATH_IN_ARCHIVE/" "$APP_PATH/"
ok "App built: $APP_PATH"

# ---------- Icon handling ----------
bold "Step 6 — App icon (optional)"
echo "If you provide a PNG icon, I'll convert it and embed it in your app."
echo "Looking for: art/icon.png (preferred) or ./icon.png (or you can drag one in when prompted)."

# Resolve icon candidates relative to the script folder first
CANDIDATES=(
  "$SCRIPT_DIR/art/icon.png"
  "$SCRIPT_DIR/icon.png"
  "./art/icon.png"
  "./icon.png"
)

ICON_SRC=""
for p in "${CANDIDATES[@]}"; do
  if [ -f "$p" ]; then ICON_SRC="$p"; break; fi
done

if [[ -z "$ICON_SRC" ]]; then
  read -r -p "No icon found. Drag a PNG here or press Return to skip: " ICON_SRC || true
  ICON_SRC="${ICON_SRC%\"}"; ICON_SRC="${ICON_SRC#\"}"
fi

embed_icon_cleanup_and_set() {
  local app="$1" icns="$2"
  local RES="$app/Contents/Resources"
  local PLIST="$app/Contents/Info.plist"
  mkdir -p "$RES"
  cp -f "$icns" "$RES/AppIcon.icns"
  /usr/libexec/PlistBuddy -c "Delete :CFBundleIcons" "$PLIST" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" "$PLIST" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$PLIST" >/dev/null 2>&1 \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$PLIST" >/dev/null 2>&1
}

if [[ -n "${ICON_SRC:-}" && -f "${ICON_SRC:-}" ]]; then
  info "Using icon: $ICON_SRC"
  if ! command -v sips >/dev/null 2>&1; then
    warn "'sips' not available; skipping icon conversion."
  elif ! command -v iconutil >/dev/null 2>&1; then
    warn "'iconutil' not available. Install Command Line Tools: xcode-select --install"
  else
    TMPICON="$(mktemp -d "/tmp/makeitso_icon.XXXXXX")"
    ICONSET="$TMPICON/AppIcon.iconset"
    ICNS_OUT="$TMPICON/AppIcon.icns"
    mkdir -p "$ICONSET"
    for s in 16 32 64 128 256 512 1024; do
      sips -z "$s" "$s" "$ICON_SRC" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    done
    cp "$ICONSET/icon_32x32.png"     "$ICONSET/icon_16x16@2x.png"
    cp "$ICONSET/icon_64x64.png"     "$ICONSET/icon_32x32@2x.png"
    cp "$ICONSET/icon_128x128.png"   "$ICONSET/icon_64x64@2x.png"
    cp "$ICONSET/icon_256x256.png"   "$ICONSET/icon_128x128@2x.png"
    cp "$ICONSET/icon_512x512.png"   "$ICONSET/icon_256x256@2x.png"
    cp "$ICONSET/icon_1024x1024.png" "$ICONSET/icon_512x512@2x.png" 2>/dev/null || true
    if iconutil -c icns "$ICONSET" -o "$ICNS_OUT" >/dev/null 2>&1; then
      embed_icon_cleanup_and_set "$APP_PATH" "$ICNS_OUT"
      ok "Icon embedded."
      if command -v codesign >/dev/null 2>&1; then
        codesign --force -s - --deep --timestamp=none "$APP_PATH" >/dev/null 2>&1 || true
      fi
    else
      warn "iconutil failed; skipping icon embedding."
    fi
    rm -rf "$TMPICON" || true
  fi
else
  info "Skipping icon step."
fi

# ---------- Packaging ----------
bold "Step 7 — Create a ZIP you can share"
ZIP_PATH="$OUT_ROOT/${PKG_NAME}.zip"
( cd "$OUT_ROOT" && zip -r -q "$(basename "$ZIP_PATH")" "$(basename "$WORK")" )
ok "ZIP ready: $ZIP_PATH"

# ---------- Security checks ----------
bold "Step 8 — Quick security checks"
GATEKEEPER="unknown"
QUAR="unknown"
if spctl --assess --type execute "$APP_PATH" >/dev/null 2>&1; then
  GATEKEEPER="allowed"
else
  GATEKEEPER="blocked (normal for unsigned)"
fi
if xattr -p com.apple.quarantine "$APP_PATH" >/dev/null 2>&1; then
  QUAR="present"
else
  QUAR="not present"
fi
info "Gatekeeper: $GATEKEEPER"
info "Download flag: $QUAR"

if [[ "$QUAR" == "present" ]]; then
  echo "Removing the 'downloaded from Internet' flag can reduce first‑run warnings."
  if ask "Remove that flag on your built app now? [y/N]:"; then
    xattr -dr com.apple.quarantine "$APP_PATH" && ok "Flag removed" || warn "Could not remove flag"
    QUAR="not present"
  fi
fi

echo "Local signing adds a simple signature so your Mac shows fewer warnings."
echo "This is NOT notarized and does not replace Developer ID signing."
if ask "Apply local (ad‑hoc) signing now? [y/N]:"; then
  if codesign --force --deep --sign - "$APP_PATH"; then ok "Signed locally"; else warn "Signing failed"; fi
fi

if ask "Open the app now to test it? [y/N]:"; then
  open "$APP_PATH" || warn "Could not open the app automatically"
fi

# ---------- DMG & Release Notes ----------
echo "A DMG is a neat, drag‑and‑drop disk image for sharing your build."
if ask "Create a DMG file and Release Notes? [y/N]:"; then
  DMG_PATH="$OUT_ROOT/${PKG_NAME}.dmg"
  if hdiutil create -volname "$PRODUCT_NAME" -srcfolder "$WORK" -ov -format UDZO "$DMG_PATH" >/dev/null; then
    ok "DMG ready: $DMG_PATH"
  else
    warn "Could not create DMG"; DMG_PATH=""
  fi

  NOTES="$OUT_ROOT/${PKG_NAME}_RELEASE_NOTES.md"
  ZIP_SHA=""; APP_SHA=""; DMG_SHA=""
  [[ -f "$ZIP_PATH" ]] && ZIP_SHA="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
  TMP_APP_ZIP="$(mktemp -t appzip).zip"
  (cd "$(dirname "$APP_PATH")" && zip -r -q "$TMP_APP_ZIP" "$(basename "$APP_PATH")")
  APP_SHA="$(shasum -a 256 "$TMP_APP_ZIP" | awk '{print $1}')"; rm -f "$TMP_APP_ZIP"
  [[ -n "${DMG_PATH:-}" && -f "$DMG_PATH" ]] && DMG_SHA="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')" || true

  {
    echo "# $PRODUCT_NAME — Release Notes"
    echo
    echo "**Package:** $(basename "$WORK")"
    echo
    echo "## Downloads"
    echo "- ZIP: $(basename "$ZIP_PATH")"
    [[ -n "${DMG_PATH:-}" && -f "$DMG_PATH" ]] && echo "- DMG: $(basename "$DMG_PATH")"
    echo
    echo "## Checksums (SHA‑256)"
    [[ -n "$ZIP_SHA" ]] && echo "- $(basename "$ZIP_PATH"): \`$ZIP_SHA\`"
    [[ -n "$APP_SHA" ]] && echo "- $(basename "$APP_PATH").zip: \`$APP_SHA\`"
    [[ -n "$DMG_SHA" ]] && echo "- $(basename "$DMG_PATH"): \`$DMG_SHA\`"
    echo
    echo "## Notes"
    echo "- First run: Right‑click the app → Open → Open (if macOS warns)."
    echo "- Local signing reduces warnings on your Mac only (not notarized)."
  } > "$NOTES"
  ok "Release Notes written: $NOTES"
fi

# ---------- Final Report ----------
REPORT="$OUT_ROOT/${PKG_NAME}_AUDIT_REPORT.md"
ICON_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$APP_PATH/Contents/Info.plist" 2>/dev/null || true)"
RES="$APP_PATH/Contents/Resources"
ICON_OK="no"
[[ -n "$ICON_NAME" && ( -f "$RES/${ICON_NAME}.icns" || -f "$RES/$ICON_NAME" ) ]] && ICON_OK="yes"

{
  echo "# $PRODUCT_NAME — Final Report"
  echo
  echo "## Package"
  echo "- Folder: $(basename "$WORK")"
  echo "- ZIP: $(basename "$ZIP_PATH")"
  [[ -n "${DMG_PATH:-}" && -f "$DMG_PATH" ]] && echo "- DMG: $(basename "$DMG_PATH")"
  echo
  echo "## App"
  echo "- Location: $APP_PATH"
  echo "- Gatekeeper: $GATEKEEPER"
  echo "- Download flag: $QUAR"
  echo "- Icon set in Info.plist: ${ICON_NAME:-'(none)'}"
  echo "- Icon file present: $([[ "$ICON_OK" == "yes" ]] && echo 'yes' || echo 'no')"
  echo
  echo "## What to share"
  echo "- ZIP for source + app bundle"
  [[ -n "${DMG_PATH:-}" && -f "$DMG_PATH" ]] && echo "- DMG for a simple install experience"
  echo
  echo "## Next steps (optional)"
  echo "- For external distribution: consider Developer ID signing + notarization."
  echo "- If the icon didn't show up immediately, re-open Finder (icon caches can delay)."
  echo
  echo "## Support"
  echo "- Email: makeitsoapp@proton.me"
} > "$REPORT"
ok "Report saved: $REPORT"

# ---------- End-of-run Summary ----------
bold "Step 9 — Where everything is (copy/paste paths):"
echo "• Package folder:  $(abspath "$WORK")"
echo "• App bundle:      $(abspath "$APP_PATH")"
echo "• ZIP archive:     $(abspath "$ZIP_PATH")"
[[ -n "${DMG_PATH:-}" && -f "${DMG_PATH:-}" ]] && echo "• DMG image:       $(abspath "$DMG_PATH")"
echo "• Final report:    $(abspath "$REPORT")"
[[ -n "${NOTES:-}" && -f "${NOTES:-}" ]] && echo "• Release notes:   $(abspath "$NOTES")"
[[ -n "${BACKUP_ZIP:-}" && -f "${BACKUP_ZIP:-}" ]] && echo "• Safety backup:   $(abspath "$BACKUP_ZIP")"

echo ""
if ask "Open the package folder in Finder now? [y/N]:"; then open "$(abspath "$WORK")"; fi
if ask "Open the final report now? [y/N]:"; then open "$(abspath "$REPORT")"; fi
if [[ -n "${NOTES:-}" && -f "${NOTES:-}" ]]; then
  if ask "Open the release notes now? [y/N]:"; then open "$(abspath "$NOTES")"; fi
fi

bold "All done. You can close this window."
read -n 1 -s -r -p "Press any key to close…" 2>/dev/null || true

# ===== Helpers deployment (GitHub-friendly files) =====
bold "Optional — Preparing helper files for GitHub (skipped by default)"
HELPERS_DIR="$WORK/helpers"
mkdir -p "$HELPERS_DIR/.github/ISSUE_TEMPLATE"

cat > "$HELPERS_DIR/.gitignore" <<'GITIGN'
# macOS
.DS_Store
.AppleDouble
.LSOverride

# Xcode
DerivedData/
build/
*.xcworkspace/xcuserdata
*.xcodeproj/project.xcworkspace/xcuserdata
*.xcodeproj/xcuserdata
*.xcuserdatad
*.xccheckout
*.moved-aside
*.xcarchive
*.xcuserstate

# SwiftPM
.build/
.swiftpm/

# Archives/Artifacts
dist/
*.dmg
*.zip

# Logs
*.log
GITIGN

cat > "$HELPERS_DIR/.gitattributes" <<'GATTR'
* text=auto eol=lf
*.sh text eol=lf
*.command text eol=lf
*.md text eol=lf
*.swift text eol=lf
GATTR

cat > "$HELPERS_DIR/CONTRIBUTING.md" <<'CONTRI'
# Contributing

Thanks for considering a contribution!

1. Open an issue describing your change.
2. Fork, create a feature branch, and make commits.
3. Open a Pull Request linking the issue.
4. Include `dist/..._AUDIT_REPORT.md` if packaging changed.
CONTRI

cat > "$HELPERS_DIR/CODE_OF_CONDUCT.md" <<'COC'
# Code of Conduct

Be kind and respectful. No harassment or hate speech.
Report issues to: makeitsoapp@proton.me
COC

cat > "$HELPERS_DIR/SECURITY.md" <<'SEC'
# Security Policy

Please do not open public issues for security problems.
Email: makeitsoapp@proton.me
SEC

cat > "$HELPERS_DIR/CHANGELOG.md" <<'CHG'
# Changelog

## v3.0 — Friendly
- Plain‑English prompts & defaults
- Optional safety backup (single .zip, iCloud default)
- Clear end-of-run summary paths
- Same reliable build/packaging under the hood

## v2.0
- Adds helpers: .gitignore, templates, release tools
- New flag: --write-helpers (copies helpers into your project)
- Auto-opens Finder when done by default
- Keeps everything in one place

## v1.0
- One-file builder/packager
- Icon to .icns, ZIP/DMG, ad-hoc sign
- Audit + release notes, optional notarize/GitHub
CHG

mkdir -p "$HELPERS_DIR/.github/ISSUE_TEMPLATE"
cat > "$HELPERS_DIR/.github/ISSUE_TEMPLATE/bug_report.md" <<'BUG'
---
name: Bug report
about: Help improve Make It So
labels: bug
---

**Describe the bug**

**Steps to reproduce**

**Expected behavior**

**Logs / reports**
Attach: `dist/..._AUDIT_REPORT.md`

**Environment**
- macOS version:
- Xcode / CLT version:
BUG

cat > "$HELPERS_DIR/.github/ISSUE_TEMPLATE/feature_request.md" <<'FEAT'
---
name: Feature request
about: Suggest an enhancement
labels: enhancement
---

**Problem**

**Proposed solution**

**Alternatives**

**Additional context**
FEAT

cat > "$HELPERS_DIR/.github/PULL_REQUEST_TEMPLATE.md" <<'PRT'
## Summary

## Testing
Attach `AUDIT_REPORT.md` if packaging changed.

## Notes
PRT

# Include release helper & template in helpers if they exist beside this script
cp -f "Post To GitHub Release.command" "$HELPERS_DIR/" 2>/dev/null || true
cp -f "RELEASE_NOTES_TEMPLATE.md" "$HELPERS_DIR/" 2>/dev/null || true

# Optionally copy helpers into the user's project root (only if WRITE_HELPERS=true)
if $WRITE_HELPERS; then
  bold "Writing helpers into project root…"
  cp -n "$HELPERS_DIR/.gitignore" ".gitignore" 2>/dev/null || true
  cp -n "$HELPERS_DIR/.gitattributes" ".gitattributes" 2>/dev/null || true
  mkdir -p ".github/ISSUE_TEMPLATE"
  for f in "CONTRIBUTING.md" "CODE_OF_CONDUCT.md" "SECURITY.md" "CHANGELOG.md"; do
    [[ -f "$f" ]] || cp "$HELPERS_DIR/$f" "./$f"
  done
  for f in "bug_report.md" "feature_request.md"; do
    [[ -f ".github/ISSUE_TEMPLATE/$f" ]] || cp "$HELPERS_DIR/.github/ISSUE_TEMPLATE/$f" ".github/ISSUE_TEMPLATE/$f"
  done
  [[ -f ".github/PULL_REQUEST_TEMPLATE.md" ]] || cp "$HELPERS_DIR/.github/PULL_REQUEST_TEMPLATE.md" ".github/PULL_REQUEST_TEMPLATE.md"
  [[ -f "Post To GitHub Release.command" ]] || cp "$HELPERS_DIR/Post To GitHub Release.command" "Post To GitHub Release.command"
  [[ -f "RELEASE_NOTES_TEMPLATE.md" ]] || cp "$HELPERS_DIR/RELEASE_NOTES_TEMPLATE.md" "RELEASE_NOTES_TEMPLATE.md"
fi
