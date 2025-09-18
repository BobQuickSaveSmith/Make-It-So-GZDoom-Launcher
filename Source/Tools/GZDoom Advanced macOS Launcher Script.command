#!/bin/bash

# ==============================================================
# GZDoom Advanced macOS Launcher Script
# ==============================================================

# PURPOSE:
# Launch GZDoom with an ordered list of .pk3/.wad files, then back up
# your saves and config. Supports pruning (by age OR by count) and
# optional ZIP compression. All settings are below and can also be
# overridden with runtime flags.

# FEATURES:
# - Run multiple .pk3/.wad mods in a specific order
# - Load mods, maps, etc from a single folder (MOD_BASE) OR full paths (layering)
# - Per-mod save folder via -savedir
# - Custom IWAD file
# - Extra GZDoom CLI arguments (EXTRA_ARGS array)
# - Backups are named with the MOD and include only this MOD's savedir
# - Optional ZIP compression of each backup
# - Pruning of old backups by AGE or by COUNT (or disabled)

# HOW TO USE:
# 1) Edit the "USER SETTINGS" section.
# 2) Save as: GZDoom_Launcher_Advanced.command
# 3) Make executable: chmod +x GZDoom_Launcher_Advanced.command
# 4) Double-click to run (or execute from Terminal).

# RUNTIME FLAGS (optional):
# --mod="folder"             Override MOD name/folder (affects MOD_BASE and SAVE_DIR)
# --iwad="file.wad"          Use a different IWAD filename
# --backup=age|count|off     Choose pruning mode
# --days=N                   Set PRUNE_DAYS (for backup=age)
# --keep=N                   Set MAX_BACKUPS (for backup=count)
# --backup-dir="/path"       Override backup destination
# --zip=on|off               Enable/disable ZIP compression
# --zipkeep=on|off           Keep/delete raw folder after ZIP
# --help / --prune-help      Print detailed help and exit

# PRUNING MODES EXPLAINED:
# - backup=age:
#     Keeps all timestamped backups newer than PRUNE_DAYS days,
#     deletes anything older. Best if you play frequently and want
#     “last N days” retained regardless of how many sessions you ran.
# - backup=count:
#     Keeps only the newest MAX_BACKUPS backups (folders or .zip),
#     deletes older ones. Best if you play irregularly and want your
#     “last N sessions” retained regardless of calendar days.
# - backup=off:
#     No deletion is performed. Backups accumulate until you clean up.

# ==============================================================

set -u  # treat unset variables as errors

# =======================
# USER SETTINGS
# =======================

# Mod, Maps, Campaign, etc folder name (used for MOD_BASE and SAVE_DIR)
MOD="final carnage"

# IWAD filename (must exist in your GZDoom support folder)
IWAD_FILENAME="DOOM2.WAD"

# Base folder for relative mod entries
MOD_BASE="$HOME/Library/Application Support/gzdoom/$MOD"

# Ordered list of mods to load.
# - Relative entries are resolved under MOD_BASE.
# - Full-path entries (starting with "/" or "~") are used as-is.
MOD_FILES=(
  "FinalCarnage.pk3"
  "BRUTAL PACK V10 10.3.pk3"
  "BrutalPack Neural Pack.pk3"
  "BP-Glory-Kill-3.pk3"
  "BrutalDoom_PB-Blade custom.pk3"
  "autoautosave-v1.6.3.pk3"
  "CorruptionCards-v6.3b.pk3"
  "gearbox-0.7.3.pk3"
  "GZ-WalkItOut.pk3"
  "flashlight_plus_plus_v9_1.pk3"
  "BrutalDoom_PB-Blade custom.pk3"
  "GunBonsai-0.10.6.pk3"
  "minimap_m.pk3"
  "HXRTCHUD_BPV103b_v3.pk3"
  # Example full-path mod (uncomment and edit):
  # "$HOME/gzdoom_mods/visuals/hd_textures.pk3"
)

# Optional extra GZDoom CLI arguments (leave empty if not needed)
EXTRA_ARGS=(
  # "+set vid_fps 1"
  # "-width 1920" "-height 1080"
)

# Backup destination (iCloud by default)
BACKUP_BASE="$HOME/Library/Mobile Documents/com~apple~CloudDocs/gzdoom-backup"

# Pruning mode: "age", "count", or "off"
BACKUP_MODE="count"

# Age-based pruning: delete backups older than PRUNE_DAYS days
PRUNE_DAYS=30

# Count-based pruning: keep only the newest MAX_BACKUPS backups
MAX_BACKUPS=30

# ZIP each backup after creation? "on" or "off"
ZIP_BACKUPS="on"

# If zipping is on, delete the raw unzipped folder after successful ZIP?
ZIP_DELETE_RAW="on"

# =======================
# DERIVED PATHS
# =======================

SAVE_DIR="$HOME/Documents/GZDoom/$MOD"
IWAD_PATH="$HOME/Library/Application Support/gzdoom/$IWAD_FILENAME"

# Back up only this run's savedir (matches -savedir), not all mods
SRC_DOCS="$SAVE_DIR"
SRC_INI="$HOME/Library/Preferences/gzdoom.ini"

# =======================
# FLAG PARSING
# =======================

for arg in "$@"; do
  case "$arg" in
    --backup=*) BACKUP_MODE="${arg#*=}" ;;
    --days=*) PRUNE_DAYS="${arg#*=}" ;;
    --keep=*) MAX_BACKUPS="${arg#*=}" ;;
    --mod=*)
      MOD="${arg#*=}"
      MOD_BASE="$HOME/Library/Application Support/gzdoom/$MOD"
      SAVE_DIR="$HOME/Documents/GZDoom/$MOD"
      SRC_DOCS="$SAVE_DIR"
      ;;
    --iwad=*)
      IWAD_FILENAME="${arg#*=}"
      IWAD_PATH="$HOME/Library/Application Support/gzdoom/$IWAD_FILENAME"
      ;;
    --zip=*) ZIP_BACKUPS="${arg#*=}" ;;
    --zipkeep=*) ZIP_DELETE_RAW="${arg#*=}" ;;
    --backup-dir=*) BACKUP_BASE="${arg#*=}" ;;
    --help|--prune-help)
      echo ""
      echo "USAGE FLAGS"
      echo "  --mod=FOLDER            Override MOD folder (affects MOD_BASE and SAVE_DIR)"
      echo "  --iwad=FILENAME         Use a different IWAD (e.g., DOOM2.WAD)"
      echo "  --backup=age|count|off  Pruning mode selection"
      echo "  --days=N                PRUNE_DAYS for backup=age (delete older than N days)"
      echo "  --keep=N                MAX_BACKUPS for backup=count (keep newest N)"
      echo "  --backup-dir=PATH       Backup destination root"
      echo "  --zip=on|off            ZIP each backup folder"
      echo "  --zipkeep=on|off        If zipping, keep raw folder (on) or delete it (off)"
      echo ""
      echo "PRUNING EXPLANATION"
      echo "  age   : Retain backups newer than PRUNE_DAYS days; delete older ones."
      echo "  count : Retain only the newest MAX_BACKUPS; delete older ones."
      echo "  off   : No deletion; backups accumulate until you clean up manually."
      echo ""
      echo "MOD LAYERING"
      echo "  MOD_FILES entries starting with '/' or '~' are treated as full paths."
      echo "  Other entries are resolved under MOD_BASE."
      echo ""
      exit 0
      ;;
    *)
      echo "Ignoring unknown option: $arg"
      ;;
  esac
done

# Ensure backup root exists
mkdir -p "$BACKUP_BASE"

# =======================
# BUILD MOD FILE ARGUMENTS
# =======================

FILE_ARGS=()
for f in "${MOD_FILES[@]}"; do
  [ -n "$f" ] || continue
  if [[ "$f" == /* || "$f" == ~* ]]; then
    FILE_ARGS+=("${f/#\~/$HOME}")
  else
    FILE_ARGS+=("$MOD_BASE/$f")
  fi
done

# =======================
# LAUNCH GZDOOM (robust command assembly)
# =======================

CMD=(/Applications/GZDoom.app/Contents/MacOS/gzdoom -savedir "$SAVE_DIR")

if [ "${#FILE_ARGS[@]}" -gt 0 ]; then
  CMD+=(-file "${FILE_ARGS[@]}")
fi

CMD+=(-iwad "$IWAD_PATH")

# Append EXTRA_ARGS only if any exist (compatible with set -u)
if [ "${#EXTRA_ARGS[@]:-0}" -gt 0 ]; then
  CMD+=("${EXTRA_ARGS[@]}")
fi

# Execute
"${CMD[@]}"

# =======================
# CREATE BACKUP (only this MOD's savedir)
# =======================

echo "Backing up GZDoom save and config data..."

STAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# Sanitize MOD for filesystem safety (spaces/special chars -> underscores)
SAFE_MOD="$(echo "$MOD" | sed 's/[^A-Za-z0-9._-]/_/g')"

# Name backup folder with MOD included
DEST="$BACKUP_BASE/${SAFE_MOD}_Backup_$STAMP"
mkdir -p "$DEST"

# Back up only this mod’s savedir into a mod-named subfolder
if [ -d "$SRC_DOCS" ]; then
  rsync -av "$SRC_DOCS/" "$DEST/Savedir_${SAFE_MOD}/"
fi

# Back up global config
if [ -f "$SRC_INI" ]; then
  rsync -av "$SRC_INI" "$DEST/"
fi

# =======================
# OPTIONAL ZIP COMPRESSION
# =======================

if [ "$ZIP_BACKUPS" = "on" ]; then
  echo "Zipping backup folder..."
  (
    cd "$BACKUP_BASE" && /usr/bin/zip -r -q "${SAFE_MOD}_Backup_${STAMP}.zip" "${SAFE_MOD}_Backup_${STAMP}"
  )
  ZIP_STATUS=$?
  if [ $ZIP_STATUS -eq 0 ]; then
    echo "Zip complete: $BACKUP_BASE/${SAFE_MOD}_Backup_${STAMP}.zip"
    if [ "$ZIP_DELETE_RAW" = "on" ]; then
      echo "Removing unzipped folder after successful zip..."
      rm -rf "$DEST"
    fi
  else
    echo "Zip failed. Leaving uncompressed folder: $DEST"
  fi
fi

# =======================
# BACKUP PRUNING
# =======================

case "$BACKUP_MODE" in
  age)
    if [ "$PRUNE_DAYS" -gt 0 ]; then
      echo "Pruning backups older than $PRUNE_DAYS days..."
      find "$BACKUP_BASE" -maxdepth 1 \
        \( -type d \( -name 'Backup_*' -o -name '*_Backup_*' \) -o \
           -type f \( -name 'Backup_*.zip' -o -name '*_Backup_*.zip' \) \) \
        -mtime +"$PRUNE_DAYS" -exec rm -rf {} +
    else
      echo "Age-based pruning disabled (PRUNE_DAYS=0)."
    fi
    ;;
  count)
    if [ "$MAX_BACKUPS" -gt 0 ]; then
      echo "Keeping only the newest $MAX_BACKUPS backups..."
      IFS=$'\n' read -r -d '' -a BACKUPS < <(ls -1dt "$BACKUP_BASE"/Backup_* "$BACKUP_BASE"/*_Backup_* 2>/dev/null && printf '\0')
      COUNT=0
      for item in "${BACKUPS[@]}"; do
        [ -e "$item" ] || continue
        COUNT=$((COUNT+1))
        if [ $COUNT -gt $MAX_BACKUPS ]; then
          echo "Deleting old backup: $item"
          rm -rf "$item"
        fi
      done
      unset IFS
    else
      echo "Count-based pruning disabled (MAX_BACKUPS=0)."
    fi
    ;;
  off|none|disable)
    echo "Pruning disabled (backup=off)."
    ;;
  *)
    echo "Unknown BACKUP_MODE: $BACKUP_MODE (use age|count|off)."
    ;;
esac

exit 0