#!/bin/bash
###############################################################################
# makeitso_finalize_publish_v3_4.command
#
# Smart, one-and-done publisher for Make It So (macOS GZDoom Launcher)
#
# v3.4 Upgrades
#  - Prefer DMG; upload BOTH DMG + ZIP when available.
#  - If only ZIP present but an .app is available, also package a DMG.
#  - Release notes automatically include direct links to each asset.
#  - README (root + Source) gets a Download table that prefers DMG.
#  - Preview folder normalization & link fixes remain.
###############################################################################
set -euo pipefail

say(){ printf "%s\n" "$*"; }
hr(){ printf "%s\n" "-------------------------------------------------------------------------------"; }

# Defaults tuned for your layout
REPO_DIR="${HOME}/Documents/Make It So Project/Make It So Project"
APP_PATH=""
TAG_NAME=""
TITLE=""
NOTES="App build upload."
ATTACH_PREVIEW=1
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO_DIR="${2:-}"; shift 2;;
    --tag) TAG_NAME="${2:-}"; shift 2;;
    --title) TITLE="${2:-}"; shift 2;;
    --notes) NOTES="${2:-}"; shift 2;;
    --app-path) APP_PATH="${2:-}"; shift 2;;
    --no-preview) ATTACH_PREVIEW=0; shift;;
    --dry-run) DRY_RUN=1; shift;;
    *) echo "Unknown option: $1"; exit 1;;
  esac
done

command -v git >/dev/null 2>&1 || { echo "git not found."; exit 1; }
command -v gh >/dev/null 2>&1 || { echo "gh CLI not found. Install: https://cli.github.com/"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 not found."; exit 1; }

cd "$REPO_DIR" || { echo "Repo not found: $REPO_DIR"; exit 1; }

# Canonical owner/repo (handles hyphenation, case, spaces, etc)
if gh repo view >/dev/null 2>&1; then
  FULL_REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
else
  ORIGIN_URL="$(git config --get remote.origin.url || true)"
  FULL_REPO="${ORIGIN_URL##*github.com[:/]}"; FULL_REPO="${FULL_REPO%.git}"
fi

say "Repo: $REPO_DIR"
say "Owner/Repo: $FULL_REPO"
hr

# -------------------- 1) Normalize preview dir + README link fix -------------
TARGET_DIR="_publish_preview"
CANDS=("MakeItSo_Publish_Preview" "publish_preview" "public_review" "_publish_preview")
FOUND=()
for d in "${CANDS[@]}"; do [[ -e "$d" ]] && FOUND+=("$d"); done
say "Preview dirs found: ${FOUND[*]:-(none)}"
mkdir -p "$TARGET_DIR"
for d in "${FOUND[@]}"; do
  [[ "$d" == "$TARGET_DIR" ]] && continue
  say "Merging '$d' -> '$TARGET_DIR' ..."
  [[ $DRY_RUN -eq 1 ]] || rsync -a "$d"/ "$TARGET_DIR"/ || true
done

fix_links_py='
import os, re, sys
p=sys.argv[1]
if not os.path.exists(p): sys.exit()
s=open(p,"r",encoding="utf-8").read()
for a,b in [
    ("MakeItSo_Publish_Preview/", "_publish_preview/"),
    ("MakeItSo_Publish_Preview", "_publish_preview"),
    ("publish_preview/", "_publish_preview/"),
    ("public_review/", "_publish_preview/"),
]:
    s=s.replace(a,b)
open(p,"w",encoding="utf-8").write(s)
print(f"README links normalized -> _publish_preview/ : {p}")
'

ROOT_README="README.md"
SRC_README="Source/README.md"

if [[ ! -f "$ROOT_README" ]]; then
  if [[ -f "$SRC_README" ]]; then
    say "Promoting Source/README.md -> README.md (root)"
    [[ $DRY_RUN -eq 1 ]] || cp "$SRC_README" "$ROOT_README"
  else
    say "Creating minimal README.md at repo root"
    cat > "$ROOT_README" <<'NEWREAD'
# Make It So — macOS GZDoom Launcher

Welcome! This repo contains the Make It So launcher and its documentation.
NEWREAD
  fi
fi

python3 -c "$fix_links_py" "$ROOT_README" || true
[[ -f "$SRC_README" ]] && python3 -c "$fix_links_py" "$SRC_README" || true

# Ensure compatibility symlink
if [[ -d "$TARGET_DIR" ]]; then
  if [[ -e "MakeItSo_Publish_Preview" && ! -L "MakeItSo_Publish_Preview" ]]; then
    say "Replacing 'MakeItSo_Publish_Preview' with symlink -> '$TARGET_DIR'"
    [[ $DRY_RUN -eq 1 ]] || { rm -rf "MakeItSo_Publish_Preview"; ln -s "$TARGET_DIR" "MakeItSo_Publish_Preview"; }
  elif [[ ! -e "MakeItSo_Publish_Preview" ]]; then
    say "Creating compatibility symlink 'MakeItSo_Publish_Preview' -> '$TARGET_DIR'"
    [[ $DRY_RUN -eq 1 ]] || ln -s "$TARGET_DIR" "MakeItSo_Publish_Preview"
  fi
fi
hr

# -------------------- 2) Locate or package the app build ---------------------
DIST_DIR="$REPO_DIR/Source/dist"
LATEST_DMG=""
LATEST_ZIP=""
pick_newest(){ ls -1t "$1" 2>/dev/null | head -n1 || true; }

if [[ -d "$DIST_DIR" ]]; then
  LATEST_DMG="$(pick_newest "$DIST_DIR"/*.dmg)"
  LATEST_ZIP="$(pick_newest "$DIST_DIR"/*.zip)"
fi

# If only ZIP exists but .app exists, create a DMG too
if [[ -z "$LATEST_DMG" && -n "$LATEST_ZIP" ]]; then
  # try to find the app
  if [[ -z "$APP_PATH" ]]; then
    CAND_APP="$REPO_DIR/Release/Make It So.app"
    [[ -d "$CAND_APP" ]] && APP_PATH="$CAND_APP"
  fi
  if [[ -z "$APP_PATH" ]]; then
    say "Searching DerivedData for a Release .app ..."
    while IFS= read -r dd; do
      test -d "$dd/Build/Products/Release/Make It So.app" && APP_PATH="$dd/Build/Products/Release/Make It So.app" && break
    done < <(find "$HOME/Library/Developer/Xcode/DerivedData" -maxdepth 1 -type d -name "*Make*It*So*" 2>/dev/null || true)
  fi
  if [[ -n "$APP_PATH" && -d "$APP_PATH" ]]; then
    TS="$(date +%Y-%m-%d_%H%M%S)"
    LATEST_DMG="$DIST_DIR/MakeItSo_macOS_${TS}.dmg"
    say "Packaging DMG (ZIP exists but no DMG) -> $LATEST_DMG"
    TMPDIR="$(mktemp -d)"; APPDIR="$TMPDIR/MakeItSoApp"; mkdir -p "$APPDIR"; cp -R "$APP_PATH" "$APPDIR/"
    hdiutil create -volname "MakeItSo" -srcfolder "$APPDIR" -ov -format UDZO "$LATEST_DMG"
    rm -rf "$TMPDIR"
  fi
fi

# If neither present, package both from .app
if [[ -z "$LATEST_DMG" && -z "$LATEST_ZIP" ]]; then
  if [[ -z "$APP_PATH" ]]; then
    CAND_APP="$REPO_DIR/Release/Make It So.app"
    [[ -d "$CAND_APP" ]] && APP_PATH="$CAND_APP"
  fi
  if [[ -z "$APP_PATH" ]]; then
    say "Searching DerivedData for a Release .app ..."
    while IFS= read -r dd; do
      test -d "$dd/Build/Products/Release/Make It So.app" && APP_PATH="$dd/Build/Products/Release/Make It So.app" && break
    done < <(find "$HOME/Library/Developer/Xcode/DerivedData" -maxdepth 1 -type d -name "*Make*It*So*" 2>/dev/null || true)
  fi
  if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
    echo "ERROR: No packaged build and no .app found."; exit 1
  fi
  mkdir -p "$DIST_DIR"
  TS="$(date +%Y-%m-%d_%H%M%S)"
  LATEST_DMG="$DIST_DIR/MakeItSo_macOS_${TS}.dmg"
  LATEST_ZIP="$DIST_DIR/MakeItSo_macOS_${TS}.zip"
  say "Packaging DMG -> $LATEST_DMG"
  TMPDIR="$(mktemp -d)"; APPDIR="$TMPDIR/MakeItSoApp"; mkdir -p "$APPDIR"; cp -R "$APP_PATH" "$APPDIR/"
  hdiutil create -volname "MakeItSo" -srcfolder "$APPDIR" -ov -format UDZO "$LATEST_DMG"
  rm -rf "$TMPDIR"
  say "Packaging ZIP -> $LATEST_ZIP"
  ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$LATEST_ZIP"
fi

say "Selected assets:"
[[ -n "$LATEST_DMG" ]] && say "  DMG: $LATEST_DMG"
[[ -n "$LATEST_ZIP" ]] && say "  ZIP: $LATEST_ZIP"
hr

# -------------------- 3) Create/Update Release and upload assets -------------
[[ -z "$TAG_NAME" ]] && TAG_NAME="v1.0-app-$(date +%Y%m%d_%H%M%S)"
[[ -z "$TITLE" ]] && TITLE="$TAG_NAME"

ASSET_ARGS=()
[[ -n "$LATEST_DMG" ]] && ASSET_ARGS+=("$LATEST_DMG")
[[ -n "$LATEST_ZIP" ]] && ASSET_ARGS+=("$LATEST_ZIP")

# Optionally add preview zip
PREVIEW_ZIP=""
if [[ $ATTACH_PREVIEW -eq 1 && -d "$TARGET_DIR" ]]; then
  STAMP="$(date +%Y-%m-%d_%H%M%S)"
  PREVIEW_ZIP="MakeItSo_Publish_Preview_${STAMP}.zip"
  say "Zipping preview bundle -> $PREVIEW_ZIP"
  [[ $DRY_RUN -eq 1 ]] || ditto -c -k --sequesterRsrc --keepParent "$TARGET_DIR" "$PREVIEW_ZIP"
  ASSET_ARGS+=("$PREVIEW_ZIP")
fi

if gh release view "$TAG_NAME" >/dev/null 2>&1; then
  say "Release $TAG_NAME exists — uploading assets (clobber) ..."
  [[ $DRY_RUN -eq 1 ]] || gh release upload "$TAG_NAME" "${ASSET_ARGS[@]}" --clobber
else
  say "Creating release $TAG_NAME and uploading assets ..."
  if [[ $DRY_RUN -eq 1 ]]; then
    say "(dry-run) would create release $TAG_NAME"
  else
    gh release create "$TAG_NAME" "${ASSET_ARGS[@]}" -t "$TITLE" -n "$NOTES"
  fi
fi

# Prefer DMG for README link; fall back to ZIP
PREFERRED_ASSET_BASENAME="$(basename "${LATEST_DMG:-${LATEST_ZIP}}")"
DIRECT_URL="https://github.com/${FULL_REPO}/releases/download/${TAG_NAME}/${PREFERRED_ASSET_BASENAME}"
RELEASES_URL="https://github.com/${FULL_REPO}/releases"

# Build extra release notes list with bullet links to each asset
ASSET_LIST_MD=""
for a in "${ASSET_ARGS[@]}"; do
  base="$(basename "$a")"
  ASSET_LIST_MD="${ASSET_LIST_MD}- [${base}](https://github.com/${FULL_REPO}/releases/download/${TAG_NAME}/${base})\n"
done
NOTES_BLOCK=$'# Downloads\n\n'"${ASSET_LIST_MD}"$'\n'

# Update release notes (merge or set)
if [[ $DRY_RUN -eq 1 ]]; then
  say "(dry-run) would edit release notes with download list"
else
  # Read existing body, append/replace Downloads section
  EXISTING="$(gh release view "$TAG_NAME" --json body -q .body || true)"
  python3 - "$TAG_NAME" "$NOTES_BLOCK" <<'PY'
import os, re, sys, json, subprocess, textwrap
tag=sys.argv[1]
block=sys.argv[2]
def edit(body):
    if not body: body=""
    if re.search(r'^#\s*Downloads', body, flags=re.M):
        body=re.sub(r'^#\s*Downloads[\s\S]*?(?=^\S|\Z)', block, body, flags=re.M)
    else:
        if body and not body.endswith("\n"): body+="\n"
        body += block
    return body
new=edit(os.environ.get("EXISTING",""))
open(".__tmp_notes.md","w",encoding="utf-8").write(new)
# Use gh to apply
subprocess.run(["gh","release","edit",tag,"-F",".__tmp_notes.md"], check=True)
os.remove(".__tmp_notes.md")
PY
fi

update_dl_py='
import os, re, sys
p=sys.argv[1]
direct=os.environ.get("DIRECT_URL","").strip()
releases=os.environ.get("RELEASES_URL","").strip()
section=f"""## 📥 Download

| Build | Link |
|------|------|
| Latest App Build (DMG) | [Download]({direct}) |
| More Formats / Docs | [Releases Page]({releases}) |

"""
if not os.path.exists(p):
  sys.exit()
s=open(p,"r",encoding="utf-8").read()
if "## 📥 Download" in s:
  s=re.sub(r"## 📥 Download[\\s\\S]*?(?=\\n## |\\Z)", section, s, count=1, flags=re.M)
else:
  lines=s.splitlines()
  ins=3 if len(lines)>3 else len(lines)
  lines.insert(ins, section.strip()+"")
  s="\\n".join(lines)+"\\n"
open(p,"w",encoding="utf-8").write(s)
print(f"README Download section set: {p}")
'

export EXISTING="${EXISTING:-}"
export DIRECT_URL="$DIRECT_URL"
export RELEASES_URL="$RELEASES_URL"
python3 -c "$update_dl_py" "$ROOT_README" || true
[[ -f "$SRC_README" ]] && python3 -c "$update_dl_py" "$SRC_README" || true

# -------------------- 4) Commit & push any changes ---------------------------
git add -A || true
if git diff --cached --quiet; then
  say "No source changes to commit."
else
  git commit -m "Finalize v3.4: prefer DMG, upload DMG+ZIP, add asset links to release notes, update README"
  if git remote get-url origin >/dev/null 2>&1; then
    git push
  fi
fi

hr
say "Done."
say "Release: https://github.com/${FULL_REPO}/releases/tag/${TAG_NAME}"
say "Direct app download (prefer DMG): ${DIRECT_URL}"
[[ -n "${PREVIEW_ZIP}" ]] && say "Preview bundle attached: ${PREVIEW_ZIP}"
