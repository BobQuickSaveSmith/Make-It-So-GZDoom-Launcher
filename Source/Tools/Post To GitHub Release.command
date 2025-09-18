#!/usr/bin/env bash
set -euo pipefail

echo "📤 Post To GitHub Release"
echo "This script uploads your built ZIP/DMG and notes to GitHub using the GitHub CLI."

read -rp "GitHub repo (e.g. username/MakeItSo): " REPO
read -rp "Tag name (e.g. v1.0.0): " TAG
read -rp "Release title: " TITLE

DIST_DIR=$(ls -d dist/MakeItSo_* | tail -1)
ZIP=$(find "$DIST_DIR" -name "*.zip" | head -1)
DMG=$(find "$DIST_DIR" -name "*.dmg" | head -1)
NOTES=$(find "$DIST_DIR" -name "*RELEASE_NOTES.md" | head -1)

if ! command -v gh &>/dev/null; then
  echo "❌ GitHub CLI (gh) is not installed. Install it first: https://cli.github.com"
  exit 1
fi

gh release create "$TAG"   --repo "$REPO"   --title "$TITLE"   --notes-file "$NOTES"   "$ZIP" "${DMG:-}"

echo "✅ GitHub Release created!"