# ✨ Make It So – User Manual

Welcome to **Make It So**, a GZDoom launcher for macOS that focuses on clarity, backups, script generation, and ease of use.

## 🧭 Features
- Per-profile mod loadout and IWAD paths  
- GZDoom `.app` or raw binary support  
- Read-only Privacy mode with toggleable CLI editing  
- Save folder name customization (under `~/Documents/GZDoom/`)  
- Backup system for `gzdoom.ini`, `makeitso.ini`, `autoexec.cfg`, and save games  
- Shell script (`.sh`) + macOS `.app` launcher generation  
- Built-in `Engage` and `Build` support  
- Editable CLI preview for advanced users  
- One-file architecture for easier open-source sharing  
- **Pin profiles to launch from the Dock**  
- **Import/Export profiles via shareable JSON**

## 👤 Profiles
Each profile remembers:
- GZDoom binary path (`.app` or raw)  
- IWAD file (`.wad`)  
- Mod list and order  
- Save game folder name (under `~/Documents/GZDoom/`)  
- Extra command-line args  
- Backup settings  
- Zip preferences and retention count  
- Privacy toggles  
- CLI preview (editable or regenerated)

Use the +, duplicate, delete, and up/down arrow buttons to manage and reorder profiles. Right‑click for quick actions (Engage, Build, Rename, Duplicate, Delete, Pin to Dock Menu).

## 🛡️ Privacy Mode
When Privacy Mode is enabled:
- All home-path fields display `~` instead of your full user folder  
- The CLI preview becomes read-only unless explicitly overridden  
- Paths are still saved with full accuracy behind the scenes  
- Great for screenshots, sharing, or public displays

## 🏗 Build Artifacts
Clicking **Build** generates two files in a folder you choose:
- `ProfileName.sh` — a portable, shareable bash script  
- `ProfileName.app` — a macOS app that runs the script without Terminal  

These artifacts are self-contained and use all profile settings.

## ⚡ Engage vs Build
- **Engage** runs the selected profile immediately within the app  
- **Build** produces files for later use outside the app (ideal for Dock icons)

## 🧳 Backups
Profiles include full control over what to back up:
- `makeitso.ini` — the launcher config file  
- `gzdoom.ini` — GZDoom preferences  
- `autoexec.cfg` — launch-time console config  
- Save games — for selected mod/base folder  
- Compression toggle (ZIP or plain)  
- “Backup After Run” toggle  
- Retention count (1–30) with pruning

Backups are stored under a destination of your choosing. Defaults to iCloud Drive if not changed.

## 📌 Pin to Dock Menu
- Add any profile to the app’s Dock menu  
- Right-click the Dock icon to launch pinned profiles  
- You can pin/unpin via right-click or the sidebar button  

## 📤 Import / Export Profiles
- Export selected or all profiles as JSON  
- Import profiles from another Mac or user  
- The app adjusts file paths and prevents conflicts  
- Exported paths use `~` for privacy  

## 📝 Editing Config Files
Use the built‑in Edit buttons to open or create these plain‑text files:
- **makeitso.ini** — Make It So launcher settings  
- **gzdoom.ini** — GZDoom preferences  
- **autoexec.cfg** — launch-time console commands  
- **Save games** — opens the save game locations folder in Finder  

**Supported editors:** TextEdit, BBEdit, CotEditor, Visual Studio Code, Sublime Text, Nova.  
You can also choose **Another App…** from the menu.  

> These files are **plain text**. In your editor, enable **Plain Text** mode (no rich text).

## 💡 Tips
- Use `Privacy Mode` before screen sharing or posting screenshots  
- Right-click profiles for quick Engage, Build, Rename, etc.  
- Click lock icon to toggle profile editability  
- CLI is read-only in Privacy unless explicitly enabled  
- All scripts generated are bash-compatible and portable  
- Use the `Manual…` and `Quick Start Guide` under Help for reference

## 📬 Support
[Email Support](mailto:makeitsoapp@proton.me?subject=Make%20It%20So)  
GitHub: Please fork and contribute if useful
