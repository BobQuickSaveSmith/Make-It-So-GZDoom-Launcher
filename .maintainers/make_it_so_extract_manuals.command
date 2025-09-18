#!/bin/bash
# macOS /bin/bash 3.2 compatible
set -euo pipefail

SCRIPT_VER="2025-09-13.qs1"

bold(){ printf "\n\033[1m%s\033[0m\n" "$*"; }
ok(){ printf "✅ %s\n" "$*"; }
info(){ printf "• %s\n" "$*"; }
warn(){ printf "\033[33m⚠ %s\033[0m\n" "$*"; }
err(){ printf "\033[31m✖ %s\033[0m\n" "$*"; }

# --- Locate project root & ContentView.swift ---
guess_root(){
  # If you're already in the project, prefer here
  if [ -d "./Make It So Project" ]; then
    printf "%s" "$PWD"
    return
  fi
  # Walk up a bit looking for the nested "Make It So Project" dir
  local d="$PWD"
  for _ in 1 2 3 4 5; do
    if [ -d "$d/Make It So Project" ]; then
      printf "%s" "$d"
      return
    fi
    d="$(dirname "$d")"
  done
  printf "%s" "$PWD"
}

ROOT_DEFAULT="$(guess_root)"
bold "MakeItSo Manual/Quick Start Extractor ($SCRIPT_VER)"
info "Detected default root: $ROOT_DEFAULT"
read -r -p "Project root (Enter to accept): " ROOT
ROOT="${ROOT:-$ROOT_DEFAULT}"

APP_DIR="$ROOT/Make It So Project"
SWIFT_FILE="$APP_DIR/ContentView.swift"
OUT_DIR="$APP_DIR/_publish_preview"
REPORT="$OUT_DIR/extraction_report.txt"
QS_OUT="$OUT_DIR/EXTRACTED_QuickStart.md"
MAN_OUT="$OUT_DIR/EXTRACTED_Manual.md"

[ -f "$SWIFT_FILE" ] || { err "Could not find: $SWIFT_FILE"; exit 1; }
mkdir -p "$OUT_DIR"

# --- Extract Manual: private let fullManualText = """ ... """ ---
extract_manual(){
  # We grab text between: private let fullManualText = """   and the next standalone """
  awk '
    BEGIN{capture=0}
    /^ *private[[:space:]]+let[[:space:]]+fullManualText[[:space:]]*=[[:space:]]*"""/{
      capture=1; next
    }
    capture==1 && /^"""\s*$/ { capture=0; next }
    capture==1 { print }
  ' "$SWIFT_FILE"
}

# --- Extract Quick Start sections: section("Title", """ body """) ---
extract_quickstart(){
  # We parse every line that starts a section("...",""" and read the body until the matching """.
  # Output as:
  # ## <Title>
  # <Body>
  awk '
    function unescape_title(t) {
      # Title is already plain text from Swift string literal; leave as-is
      return t
    }
    BEGIN{in_body=0}
    !in_body && /^[[:space:]]*section\("[^"]+"\s*,\s*"""/ {
      # Extract title inside first quotes
      title=$0
      sub(/^[[:space:]]*section\("/,"",title)
      sub(/".*/,"",title)
      printf("## %s\n\n", unescape_title(title))
      in_body=1
      next
    }
    in_body && /^ *"""\s*$/ { in_body=0; print ""; next }
    in_body { print }
  ' "$SWIFT_FILE"
}

# --- Run extractions ---
MANUAL_CONTENT="$(extract_manual || true)"
QS_CONTENT="$(extract_quickstart || true)"

# --- Write outputs + report ---
{
  echo "# Extraction Report — $(date)"
  echo
  if [ -n "$MANUAL_CONTENT" ]; then
    echo "Manual: OK (fullManualText)"
  else
    echo "Manual: MISSING — Could not find fullManualText block. Verify the identifier or quotes."
  fi
  if [ -n "$QS_CONTENT" ]; then
    echo "Quick Start: OK (section(\"…\", \"\"\"…\"\"\"))"
  else
    echo "Quick Start: MISSING — Could not find any section(\"title\", \"\"\"body\"\"\") patterns."
  fi
  echo
  echo "Notes:"
  echo "• This script looks specifically for 'private let fullManualText = \"\"\"' and 'section(\"…\", \"\"\"…\"\"\")' patterns."
  echo "• If you renamed identifiers or changed the shapes, update this extractor accordingly."
} > "$REPORT"

if [ -n "$MANUAL_CONTENT" ]; then
  printf "%s\n" "$MANUAL_CONTENT" > "$MAN_OUT"
  ok "Manual → $MAN_OUT"
else
  warn "Manual content not found; wrote details to $REPORT"
fi

if [ -n "$QS_CONTENT" ]; then
  # Add a heading for clarity
  {
    echo "# Quick Start Guide"
    echo
    printf "%s\n" "$QS_CONTENT"
  } > "$QS_OUT"
  ok "Quick Start → $QS_OUT"
else
  warn "Quick Start content not found; wrote details to $REPORT"
fi

echo
ok "Done."
info "Preview folder: $OUT_DIR"
info "Report: $REPORT"