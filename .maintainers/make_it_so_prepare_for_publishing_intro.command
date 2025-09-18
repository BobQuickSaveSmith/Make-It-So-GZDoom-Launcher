#!/bin/bash
# make_it_so_prepare_for_publishing_intro.command
# macOS /bin/bash 3.2 compatible

set -euo pipefail
VER="2025-09-13.m8"

title(){ printf "\n\033[1m%s\033[0m\n" "$*"; }
ok(){ printf "✅ %s\n" "$*"; }
warn(){ printf "\033[33m⚠ %s\033[0m\n" "$*"; }
err(){ printf "\033[31m✖ %s\033[0m\n" "$*"; }
info(){ printf "• %s\n" "$*"; }

# ---------- Flags ----------
OVERRIDE_ROOT=""
KEEP_WORK=false
QUIET=false
while [ $# -gt 0 ]; do
  case "$1" in
    --root) shift; OVERRIDE_ROOT="${1:-}";;
    --keep-work) KEEP_WORK=true;;
    -q|--quiet) QUIET=true;;
    -h|--help)
      cat <<EOF
MakeItSo Publisher ($VER)

Usage:
  ./make_it_so_prepare_for_publishing_intro.command [--root /path/to/project] [--keep-work]

Defaults:
• If --root is not provided, we anchor to the folder this script lives in,
  search UNDER that folder for *.xcodeproj, and treat the PARENT of the first
  match as the project root.
• We copy the project to a temp work dir in /tmp, extract from the copy, and
  delete the copy (unless you pass --keep-work).
• Outputs go to:  ~/MakeItSo_Publish_Preview
EOF
      exit 0;;
    *) warn "Ignoring unknown arg: $1";;
  esac
  shift || true
done

# ---------- Paths & discovery ----------
SCRIPT_DIR="$(cd -P -- "$(dirname -- "$0")" && pwd)"
DEFAULT_ROOT="$SCRIPT_DIR"

title "MakeItSo Publisher ($VER)"

# If user gave --root, use it (normalize). Else, derive from SCRIPT_DIR by finding *.xcodeproj underneath.
pick_root(){
  local root
  if [ -n "$OVERRIDE_ROOT" ]; then
    root="$OVERRIDE_ROOT"
    case "$root" in
      "~"|"~/"*) root="${root/#\~/$HOME}";;
      /*) : ;;
      *) root="$PWD/$root";;
    esac
    [ -d "$root" ] || { err "Directory not found: $root"; exit 1; }
    echo "$(cd -P -- "$root" && pwd)"
    return
  fi

  # Search under the script's folder for the project (*.xcodeproj)
  local hit
  hit="$(find "$DEFAULT_ROOT" -type d -name "*.xcodeproj" -print -prune 2>/dev/null | head -n1 || true)"
  if [ -n "$hit" ]; then
    # Use parent of .xcodeproj as project root
    echo "$(cd -P -- "$(dirname -- "$hit")" && pwd)"
    return
  fi

  # Fallback: ask the user (prefill = SCRIPT_DIR)
  info "Could not auto-detect *.xcodeproj under: $DEFAULT_ROOT"
  read -r -p "Project root (Enter to accept: ${DEFAULT_ROOT}): " TYPED
  [ -n "${TYPED// }" ] && DEFAULT_ROOT="$TYPED"
  case "$DEFAULT_ROOT" in
    "~"|"~/"*) DEFAULT_ROOT="${DEFAULT_ROOT/#\~/$HOME}";;
    /*) : ;;
    *) DEFAULT_ROOT="$PWD/$DEFAULT_ROOT";;
  esac
  [ -d "$DEFAULT_ROOT" ] || { err "Directory not found: $DEFAULT_ROOT"; exit 1; }
  echo "$(cd -P -- "$DEFAULT_ROOT" && pwd)"
}

PROJECT_ROOT="$(pick_root)"
ok "Project root: $PROJECT_ROOT"

# ---------- Make a safe temp copy (never touch the real project) ----------
TS="$(date +%Y%m%d_%H%M%S)"
WORK="/tmp/makeitso_publish_${TS}_$$"
mkdir -p "$WORK/project"

info "Copying project to temp work dir: $WORK"
# rsync the project into work area (exclude junk)
rsync -a \
  --exclude ".git" \
  --exclude "DerivedData" \
  --exclude "build" \
  --exclude ".DS_Store" \
  --exclude "*.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings" \
  --exclude "xcuserdata" \
  --exclude "dist" \
  --exclude "_publish_preview" \
  "$PROJECT_ROOT"/ "$WORK/project"/

# Everything from now on reads from the COPY in $WORK/project
ROOT="$WORK/project"

OUT="${HOME}/MakeItSo_Publish_Preview"
ASSETS="$OUT/ASSETS"
mkdir -p "$OUT" "$ASSETS"

# ---------- Collect Swift files under ROOT ----------
SWIFTS="$(find "$ROOT" -type f -name "*.swift" -print 2>/dev/null || true)"
if [ -z "$SWIFTS" ]; then
  err "No .swift files found under: $ROOT"
  info "Nothing to do."
  $KEEP_WORK || rm -rf "$WORK" 2>/dev/null || true
  exit 1
fi

# ---------- Helpers ----------
write_file(){ # $1 path, then stdin content
  local p="$1"; mkdir -p "$(dirname "$p")"
  cat > "$p"
}

extract_manual(){
  local hit=""
  local f
  for f in $SWIFTS; do
    if grep -q 'private[[:space:]]\+let[[:space:]]\+fullManualText[[:space:]]*=[[:space:]]*"""' "$f" 2>/dev/null; then
      hit="$f"; break
    fi
  done
  [ -z "$hit" ] && return 1

  # BSD-awk: capture lines between the triple quotes after the declaration and the closing triple quotes.
  awk '
    BEGIN { inb=0; }
    /private[[:space:]]+let[[:space:]]+fullManualText[[:space:]]*=[[:space:]]*"""/ {
      inb=1; next
    }
    {
      if (inb==1) {
        if ($0 ~ /"""[[:space:]]*$/) {
          sub(/"""[[:space:]]*$/,"")
          print $0
          inb=0
        } else {
          print $0
        }
      }
    }
  ' "$hit"
  return 0
}

extract_quickstart(){
  local hit=""
  local f
  for f in $SWIFTS; do
    if grep -q '\.id("quickStart")' "$f" 2>/dev/null && grep -q '\.id("manual")' "$f" 2>/dev/null; then
      hit="$f"; break
    fi
  done
  [ -z "$hit" ] && return 1

  # Slice between anchors, then transform section("Title", """Body""") into markdown
  awk '
    BEGIN { inb=0 }
    /\.id\("quickStart"\)/ { inb=1; next }
    /\.id\("manual"\)/ { inb=0 }
    { if (inb==1) print $0 }
  ' "$hit" \
  | awk '
      BEGIN { insec=0; inq=0; title=""; body="" }
      {
        if (insec==0) {
          if ($0 ~ /section\([[:space:]]*"/) {
            insec=1
            match($0,/section\([[:space:]]*"([^"]*)"/,m)
            title=m[1]
            if ($0 ~ /"""/) { inq=1; next }
          }
        } else {
          if (inq==0 && $0 ~ /"""/) { inq=1; next }
          if (inq==1) {
            if ($0 ~ /"""/) {
              inq=0; insec=0
              print "### " title
              print ""
              print body
              print ""
              title=""; body=""
            } else {
              if (body=="") { body=$0 } else { body=body "\n" $0 }
            }
          }
        }
      }
    '
  return 0
}

# ---------- Run extractions ----------
QS_OK=0
MAN_OK=0

QS_MD="$OUT/QUICK_START_extracted.md"
MAN_MD="$OUT/MANUAL_extracted.md"
REPORT="$OUT/extraction_report.txt"

rm -f "$QS_MD" "$MAN_MD" "$REPORT" 2>/dev/null || true

if extract_quickstart > "$QS_MD"; then
  if [ -s "$QS_MD" ]; then ok "Quick Start extracted → $(basename "$QS_MD")"; QS_OK=1; else rm -f "$QS_MD"; fi
else
  :
fi
if [ $QS_OK -eq 0 ]; then
  warn "Quick Start extraction failed."
  printf "Quick Start extraction failed.\nSearched between .id(\"quickStart\") and .id(\"manual\"), formatting section(\"title\", \"\"\"body\"\"\").\n" >> "$REPORT"
fi

if extract_manual > "$MAN_MD"; then
  if [ -s "$MAN_MD" ]; then ok "Manual extracted → $(basename "$MAN_MD")"; MAN_OK=1; else rm -f "$MAN_MD"; fi
else
  :
fi
if [ $MAN_OK -eq 0 ]; then
  warn "Manual extraction failed."
  printf "Manual extraction failed.\nLooked for:  private let fullManualText = \"\"\"\n" >> "$REPORT"
fi

if [ $QS_OK -eq 0 ] && [ $MAN_OK -eq 0 ]; then
  err "Nothing extracted."
  info "Outputs (if any) are in: $OUT"
  $KEEP_WORK || rm -rf "$WORK" 2>/dev/null || true
  exit 1
fi

# ---------- Draft README & forum posts ----------
README="$OUT/README_draft.md"
DW_POST="$OUT/Doomworld_post_draft.md"
REDDIT_POST="$OUT/Reddit_post_draft.md"

APP_NAME="Make It So"
GITHUB_URL="https://github.com/yourname/makeitso" # TODO replace
EMAIL_LINK="mailto:makeitsoapp@proton.me?subject=Make%20It%20So"

QS_SECTION="(Quick Start not found — fill this section)"
MAN_SECTION="(Manual not found — fill this section)"
[ $QS_OK -eq 1 ] && QS_SECTION="$(cat "$QS_MD")"
[ $MAN_OK -eq 1 ] && MAN_SECTION="$(cat "$MAN_MD")"

write_file "$README" <<EOF
# $APP_NAME for macOS

A friendly, batteries-included **GZDoom launcher** for macOS that focuses on clarity, backups, script generation, and ease of use.

**Highlights**
- Per-profile IWAD + mod loadout (ordered)
- One‑click **Engage** (run now) and **Build** (generate \`.sh\` + \`.app\`)
- **Privacy Mode** for screenshot‑safe displays (paths shown as \`~\`)
- Backup system for configs and saves, with retention and pruning
- **Pin profiles to the Dock menu** for super‑fast launching
- Import/Export profiles as JSON

> 🧪 This README was drafted by a helper script. Tweak anything you like.

## 🚀 Quick Start

$QS_SECTION

## 📘 Full Manual (from the app)

$MAN_SECTION

## 📸 Screenshots

Replace these placeholders with real images:

- \`ASSETS/app-main.png\` — Main UI
- \`ASSETS/dock-menu.png\` — Dock menu pins in action

## 🔧 Build & Run

- Open the Xcode project and run.
- Or download the release \`.app\` when available.

## 📝 License

Pick one (e.g., MIT). Place the license text in \`LICENSE\`.

## 💬 Support

- Email: <$EMAIL_LINK>
- Issues: open a ticket on GitHub.

EOF

write_file "$DW_POST" <<'EOF'
# [RELEASE] Make It So – macOS GZDoom Launcher

**Make It So** is a clean, Mac-native launcher for GZDoom focused on clarity, backups, and easy script/app generation.

## Why use it?
- Profile-based mod loadouts (ordered)
- One-click Engage (run) or Build (generate .sh + .app)
- Privacy mode for screenshot-safe paths
- Backups for configs/saves with retention
- Pin profiles to the Dock menu

## Quick Start (from the app)

(Paste the Quick Start excerpt you want here.)

## Screenshots
(Insert 2–3 images)

## Download / Source
- GitHub: (link)
- Feedback welcome!
EOF

write_file "$REDDIT_POST" <<'EOF'
**[Release] Make It So – macOS GZDoom Launcher**

A friendly GZDoom launcher for macOS with:
- Profile-based mod loadouts
- One-click run or build (.sh + .app)
- Privacy mode (paths shown as ~)
- Backups of configs/saves w/ retention
- Dock menu pins

Quick Start & Full Manual are in the repo README.

**Screenshots:** (attach)
**GitHub:** (link)
EOF

title "Preview ready"
echo "Drafts created in:"
echo "  $OUT"
if [ -s "$REPORT" ]; then
  echo
  warn "Some items need attention. See:"
  echo "  $REPORT"
fi

# Clean up temp copy unless requested
if $KEEP_WORK; then
  info "Keeping temp work dir: $WORK"
else
  rm -rf "$WORK" 2>/dev/null || true
fi