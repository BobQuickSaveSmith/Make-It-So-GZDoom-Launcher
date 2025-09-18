#!/bin/bash
# Organize Project Structure v3.2h — Friendly.command
# - CLI-only backup flow with plain-English prompts
# - Single timestamped ZIP (no nested folder)
# - iCloud Drive default backup path
# - Optional flags and inline help
# - macOS /bin/bash 3.2 compatible

set -euo pipefail

say()  { printf "\n\033[1m%s\033[0m\n" "$*"; }
note() { printf "• %s\n" "$*"; }
ok()   { printf "\033[32m✔ %s\033[0m\n" "$*"; }
warn() { printf "\033[33m⚠ %s\033[0m\n" "$*"; }
err()  { printf "\033[31m✖ %s\033[0m\n" "$*"; }
ask()  { read -r -p "$1 " _a; [[ "${_a:-}" =~ ^[Yy]$ || "${_a:-}" =~ ^[Yy][Ee][Ss]$ ]]; }

expand_tilde() {
  case "$1" in "~/"*) printf "%s" "${HOME}/${1#~/}" ;; "~") printf "%s" "${HOME}" ;; *) printf "%s" "$1" ;; esac
}
trim_all() { printf "%s" "$1" | tr -d '\r' | awk '{ gsub(/^[ \t]+|[ \t]+$/, "", $0); print }'; }
normalize_path() { local p="$1"; p="${p%\"}"; p="${p#\"}"; p="$(trim_all "$p")"; case "$p" in */) p="${p%/}";; esac; p="$(expand_tilde "$p")"; printf "%s" "$p"; }
dir_exists() { [ -d "$1" ] && return 0; /bin/ls -d "$1" >/dev/null 2>&1 && return 0; /usr/bin/stat -f %N "$1" >/dev/null 2>&1 && return 0; return 1; }
outside_root(){ local path="$1"; local dir="$(cd "$(dirname "$path")" 2>/dev/null && pwd)"; local base="$(basename "$path")"; local abs="$dir/$base"; local root_abs="$(cd "$ROOT" && pwd)"; case "$abs" in "$root_abs"|"$root_abs"/*) return 1;; *) return 0;; esac; }

usage() {
  cat <<'HELP'

Make It So — Organize Project Structure (v3.2h, Friendly)
--------------------------------------------------------
This helper organizes your project folders, optionally makes a
safety backup ZIP first, and tidies helper scripts into Tools/.

Most questions accept the suggested default. Press Return to accept.

Flags (all optional):
  --backup-path <dir>   Use this folder for the backup ZIP (non‑interactive)
  --ensure-folders      Always create art/, Tools/, docs/, .github/ISSUE_TEMPLATE, dist/
  --fix-helpers         Move helper scripts (*.command, *.sh) into Tools/ (keeps main packager at root)
  --prepare-source      Copy detected source folder → source/ (non‑destructive; you can update Xcode later)
  --no-questions        Accept sensible defaults without prompts (safe)
  --help                Show this help

What gets excluded from the backup ZIP:
  dist/, .git/, DerivedData, *.xcarchive, Xcode user-data folders

HELP
}

# ---------------- Parse args -----------------
BACKUP_PATH=""
FORCE_ENSURE=false
FORCE_FIX=false
FORCE_PREP=false
NO_QUESTIONS=false

while [ $# -gt 0 ]; do
  case "$1" in
    --backup-path) shift; BACKUP_PATH="${1:-}" ;;
    --ensure-folders) FORCE_ENSURE=true ;;
    --fix-helpers) FORCE_FIX=true ;;
    --prepare-source) FORCE_PREP=true ;;
    --no-questions) NO_QUESTIONS=true ;;
    --help|-h|/?|help) usage; exit 0 ;;
    *) warn "Unknown argument: $1" ;;
  esac
  shift
done

confirm_or_auto() {
  # $1 = question text with [Y/n] style hint
  if $NO_QUESTIONS; then
    # Choose the safer default for each question:
    # backup: yes; ensure-folders: yes; move helpers: yes; copy source: no (non-destructive is fine but user may prefer manual)
    case "$1" in
      *"backup ZIP"*) return 0 ;;        # yes
      *"standard folders"*) return 0 ;;  # yes
      *"Move helper scripts"*) return 0 ;; # yes
      *"Copy '"*"' → 'source/'"*) return 1 ;; # no
      *) return 0 ;;
    esac
  else
    ask "$1"
    return $?
  fi
}

# ---------------- Locate root ----------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE="$(basename "$SCRIPT_DIR")"
if [ "$BASE" = "Tools" ] || [ "$BASE" = "tools" ]; then ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"; else ROOT="$SCRIPT_DIR"; fi
cd "$ROOT"

say "Organizing project at: $ROOT"

# ---------------- Discover project -----------
XCPROJ=""; for p in *.xcodeproj; do [ -d "$p" ] && XCPROJ="$p" && break; done
SRC_DIR_FOUND=""; for d in "Make It So" "MakeItSo" "App" "Sources" "source" "src"; do [ -d "$d" ] && SRC_DIR_FOUND="$d" && break; done
HAS_TOOLS="no"; { [ -d Tools ] || [ -d tools ]; } && HAS_TOOLS="yes"
HAS_ART="no"; [ -d art ] && HAS_ART="yes"
HAS_DIST="no"; [ -d dist ] && HAS_DIST="yes"
HAS_DOCS="no"; [ -d docs ] && HAS_DOCS="yes"
HAS_GH="no"; [ -d .github ] && HAS_GH="yes"

note "Detected:"
note "- Xcode project: ${XCPROJ:-none}"
note "- Source folder: ${SRC_DIR_FOUND:-none}"
note "- Tools folder : $HAS_TOOLS"
note "- art/         : $HAS_ART"
note "- dist/        : $HAS_DIST"
note "- docs/        : $HAS_DOCS"
note "- .github/     : $HAS_GH"

# ---------------- Backup (single ZIP) --------
ICLOUD_DEFAULT="$HOME/Library/Mobile Documents/com~apple~CloudDocs/MakeItSo-Backups"
if confirm_or_auto "Do you want to create a safety backup ZIP of your current project before organizing? (Recommended) [Y/n]:"; then
  say "Where should the backup ZIP be saved?"
  note "Default: iCloud Drive → MakeItSo-Backups"
  if [ -z "$BACKUP_PATH" ]; then
    printf "Press Return to use the default, or type another folder path (e.g., ~/Desktop/Backups):\n  %s\n> " "$ICLOUD_DEFAULT"
    IFS= read -r CHOICE || true
    if [ -z "$CHOICE" ]; then
      BASE="$ICLOUD_DEFAULT"
    else
      BASE="$(normalize_path "$CHOICE")"
    fi
  else
    BASE="$(normalize_path "$BACKUP_PATH")"
    note "(Using --backup-path) $BASE"
  fi

  if ! outside_root "$BASE"; then
    warn "That folder is inside the project. Backups must be outside to avoid being included."
    printf "Enter a different folder path or press Return to use the default:\n  %s\n> " "$ICLOUD_DEFAULT"
    IFS= read -r BASE2 || true
    if [ -z "$BASE2" ]; then BASE="$ICLOUD_DEFAULT"; else BASE="$(normalize_path "$BASE2")"; fi
  fi

  if ! dir_exists "$BASE"; then
    warn "That folder does not exist yet."
    if confirm_or_auto "Create it now? [Y/n]:"; then
      mkdir -p "$BASE"; ok "Created: $BASE"
    else
      warn "Skipping backups and continuing without a ZIP."
      DO_BACKUP="no"
    fi
  fi

  DO_BACKUP="${DO_BACKUP:-yes}"
  if [ "$DO_BACKUP" = "yes" ]; then
    TS="$(date +%Y%m%d_%H%M%S)"
    ZIP_PATH="$BASE/MakeItSo_build_files_backup_${TS}.zip"
    say "Creating backup ZIP (this may take a moment)…"
    /usr/bin/zip -r -q "$ZIP_PATH" . \
      -x "dist/*" ".git/*" "*DerivedData/*" "*.xcarchive" \
         "*.xcodeproj/project.xcworkspace/xcuserdata/*" "*.xcuserdatad/*" "*.xcuserdata/*"
    ok "Backup created → $ZIP_PATH"
  fi
else
  warn "Skipping backups by request."
fi

# ---------------- Ensure folders -------------
mk(){ mkdir -p "$1" && ok "Created: $1"; }
if $FORCE_ENSURE || confirm_or_auto "Create standard folders (art, Tools, docs, .github/ISSUE_TEMPLATE, dist)? [Y/n]:"; then
  [ -d art ] || mk "art"
  [ -d docs ] || mk "docs"
  [ -d Tools ] || mk "Tools"
  [ -d .github/ISSUE_TEMPLATE ] || mk ".github/ISSUE_TEMPLATE"
  [ -d dist ] || mk "dist"
else
  note "Skipping folder creation."
fi

# ---------------- Move helpers ---------------
mv_safe(){
  f="$1"; [ -f "$f" ] || return 0
  case "$f" in "Make It So.command"|"Make It So_V2.command") return 0 ;; esac
  [ "$(basename "$f")" = "$(basename "$0")" ] && return 0
  mkdir -p Tools && mv -f "$f" Tools/ && ok "Moved helper → Tools/$(basename "$f")"
}
if $FORCE_FIX || confirm_or_auto "Move helper scripts (.command/.sh) into Tools/ (keeps the main packager at the project root)? [Y/n]:"; then
  for f in *.command; do [ "$f" = "*.command" ] && break; mv_safe "$f"; done
  for f in *.sh; do [ "$f" = "*.sh" ] && break; mv_safe "$f"; done
  [ -f "Post To GitHub Release.command" ] && mv_safe "Post To GitHub Release.command"
  [ -f "Notarize and Staple.command" ] && mv_safe "Notarize and Staple.command"
else
  note "Helpers left where they are."
fi

# ---------------- Prepare source copy --------
if [ -n "$SRC_DIR_FOUND" ] && [ "$SRC_DIR_FOUND" != "source" ]; then
  MSG="Copy '$SRC_DIR_FOUND/' → 'source/' now? (non-destructive copy so you can update Xcode later) [y/N]:"
  if $FORCE_PREP || confirm_or_auto "$MSG"; then
    mkdir -p source
    rsync -a "$SRC_DIR_FOUND/./" "source/"
    ok "Copied to 'source/'."
  else
    note "Skipping source copy."
  fi
else
  ok "Source already conventional ('source/') or not detected."
fi

# ---------------- Summary --------------------
say "Done."
echo "Summary:"
echo "  • Project root: $ROOT"
[ -n "${ZIP_PATH:-}" ] && echo "  • Backup ZIP:   $ZIP_PATH"
echo "  • Xcode project: ${XCPROJ:-none}"
echo "  • Source folder: ${SRC_DIR_FOUND:-none}"
echo ""
echo "Next:"
echo "  • If you created 'source/': open Xcode and switch the target to that folder if needed."
echo "  • Re-run your packager when finished:  ./Make\\ It\\ So.command"
echo ""
echo "Help any time:"
echo "  ./\"$(basename "$0")\" --help"
