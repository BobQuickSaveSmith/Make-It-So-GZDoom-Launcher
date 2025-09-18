#!/bin/bash
#
# =====================================================================
# make_app_compiler — Convert a .command / .sh / .bsh script into a macOS .app
# =====================================================================
#
# PURPOSE:
#   Turn any shell script (e.g., doom_launcher.command, filename.sh, filename.bsh)
#   into a double-clickable macOS .app. Uses an AppleScript wrapper via osacompile.
#
# QUICK USAGE:
#   make_app_compiler -f /path/to/doom_launcher.command
#
# REQUIRED:
#   -f, --file FILE      Path to the .command/.sh/.bsh script to wrap
#
# OPTIONAL:
#   -n, --name NAME      App name (default: input filename without extension)
#   -m, --mode MODE      Run mode: "silent" (no Terminal) or "terminal" (default: silent)
#   -d, --dest DIR       Destination folder for the .app (default: script's folder)
#   -h, --help           Show usage with examples and exit
#
# EXAMPLES:
#   make_app_compiler -f ./doom_launcher.command
#   make_app_compiler -f ./filename.sh -m terminal
#   make_app_compiler -f ./filename.bsh -n "My Launcher" -d "/Applications"
#
# NOTES:
#   - The tool sets the source script executable (chmod +x).
#   - On first run, macOS Gatekeeper may block the app. Right‑click → Open (one time).
#   - Your original script is not modified.
#
# =====================================================================

set -euo pipefail

# ------------- helpers -------------
usage() {
  cat <<'USAGE'
make_app_compiler — Convert a .command / .sh / .bsh script into a macOS .app

REQUIRED:
  -f, --file FILE      Path to the script to wrap (e.g., ./doom_launcher.command)

OPTIONAL:
  -n, --name NAME      App name (default: source filename without extension)
  -m, --mode MODE      Run mode: "silent" (no Terminal) or "terminal" (default: silent)
  -d, --dest DIR       Output folder for the .app (default: same folder as the script)
  -h, --help           Show this help and exit

EXAMPLES:
  make_app_compiler -f ./doom_launcher.command
  make_app_compiler -f ./filename.sh -m terminal
  make_app_compiler -f ./filename.bsh -n "My Launcher" -d "/Applications"

USAGE
}

die() { echo "ERROR: $*" >&2; exit 1; }
trim() { awk '{$1=$1;print}' <<<"$*"; }

# ------------- parse flags -------------
SOURCE_SCRIPT=""
APP_NAME=""
RUN_MODE="silent"
DEST_DIR=""

while (($#)); do
  case "$1" in
    -f|--file)
      shift
      SOURCE_SCRIPT="${1:-}"; [ -n "${SOURCE_SCRIPT}" ] || die "Missing value for -f|--file"
      ;;
    -n|--name)
      shift
      APP_NAME="${1:-}"; [ -n "${APP_NAME}" ] || die "Missing value for -n|--name"
      ;;
    -m|--mode)
      shift
      RUN_MODE="$(echo "${1:-}" | tr '[:upper:]' '[:lower:]')"
      [ -n "${RUN_MODE}" ] || die "Missing value for -m|--mode"
      ;;
    -d|--dest)
      shift
      DEST_DIR="${1:-}"; [ -n "${DEST_DIR}" ] || die "Missing value for -d|--dest"
      ;;
    -h|--help)
      usage; exit 0 ;;
    --) shift; break ;;
    -*)
      echo "Unknown option: $1" >&2
      usage; exit 2 ;;
    *)
      echo "Unexpected positional argument: $1" >&2
      usage; exit 2 ;;
  esac
  shift
done

# Require -f/--file
if [ -z "${SOURCE_SCRIPT}" ]; then
  echo "No source script provided."
  echo ""
  usage
  exit 2
fi

# ------------- validate inputs -------------
[ -f "$SOURCE_SCRIPT" ] || die "Script not found: $SOURCE_SCRIPT"

SCRIPT_DIR="$(cd "$(dirname "$SOURCE_SCRIPT")" && pwd)"
SCRIPT_FILE="$(basename "$SOURCE_SCRIPT")"
SCRIPT_ABS="$SCRIPT_DIR/$SCRIPT_FILE"
BASENAME_NOEXT="${SCRIPT_FILE%.*}"

# Defaults for name and dest
APP_NAME="${APP_NAME:-$BASENAME_NOEXT}"
[ -n "${DEST_DIR}" ] || DEST_DIR="$SCRIPT_DIR"
DEST_DIR="$(cd "$DEST_DIR" && pwd)"

# Validate mode
case "$RUN_MODE" in
  silent|terminal) ;;
  *)
    die "Invalid --mode. Use 'silent' or 'terminal'."
    ;;
esac

APP_OUT="$DEST_DIR/$APP_NAME.app"

# ------------- ensure executable -------------
echo "Making script executable: $SCRIPT_ABS"
chmod +x "$SCRIPT_ABS"

# ------------- AppleScript wrappers -------------
read -r -d '' AS_SILENT <<'EOF' || true
on run
  set scriptPOSIX to "%SCRIPT_PATH%"
  do shell script quoted form of scriptPOSIX
end run
EOF

read -r -d '' AS_TERMINAL <<'EOF' || true
on run
  set scriptPOSIX to "%SCRIPT_PATH%"
  tell application "Terminal"
    activate
    do script quoted form of scriptPOSIX
  end tell
end run
EOF

AS_WRAPPER="$AS_SILENT"
[ "$RUN_MODE" = "terminal" ] && AS_WRAPPER="$AS_TERMINAL"
AS_WRAPPER="${AS_WRAPPER//%SCRIPT_PATH%/$SCRIPT_ABS}"

# ------------- compile app -------------
command -v osacompile >/dev/null 2>&1 || die "osacompile not found (required on macOS)."

TMPDIR="$(mktemp -d)"
AS_FILE="$TMPDIR/wrapper.applescript"
printf "%s\n" "$AS_WRAPPER" > "$AS_FILE"

rm -rf "$APP_OUT"
echo "Creating app: $APP_OUT"
osacompile -o "$APP_OUT" "$AS_FILE"

# ------------- cleanup + summary -------------
rm -rf "$TMPDIR"

echo ""
echo "App created successfully:"
echo "  $APP_OUT"
echo ""
echo "Details:"
echo "  Source script : $SCRIPT_ABS"
echo "  App name      : $APP_NAME"
echo "  Destination   : $DEST_DIR"
echo "  Run mode      : $RUN_MODE"
echo ""
echo "Note: If macOS blocks the app on first run, right-click it and choose 'Open'."
echo ""

exit 0