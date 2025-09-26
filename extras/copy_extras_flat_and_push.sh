#!/bin/bash
# Copy all files from makeitso-extras (flat) into the 'extras/' folder of the real repo and push

SRC="/Users/paulgamlowski/Library/Application Support/gzdoom/makeitso-extras"
DEST="/Users/paulgamlowski/Documents/MakeItSoRealClone/extras"
REPO="/Users/paulgamlowski/Documents/MakeItSoRealClone"

mkdir -p "$DEST"

echo "Copying files from:"
echo "  $SRC"
echo "to:"
echo "  $DEST"
echo

count=0
while IFS= read -r -d '' file; do
  cp "$file" "$DEST/"
  ((count++))
done < <(find "$SRC" -type f -print0)

echo
echo "Copied $count file(s) into: $DEST"
echo

cd "$REPO" || exit 1

git add extras/*
if git diff --cached --quiet; then
  echo "No changes to commit."
else
  msg="Add/update extras (flattened) — $(date '+%Y-%m-%d %H:%M:%S')"
  git commit -m "$msg"
  echo "Pushing to remote…"
  git push
fi

echo "✅ Done."