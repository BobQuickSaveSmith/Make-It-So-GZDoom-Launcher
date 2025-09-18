# 🌟 Quick Start Guide

## 🚀 What does **Engage** do?
Launch GZDoom using the current profile’s settings:
- IWAD
- Mod list (suggested order):
  - Map (custom map or campaign)
  - Mod (core gameplay changes)
  - Add-ons (visuals, UI, QoL, etc.)
- Extra arguments
- Save game folder
- GZDoom binary path

## 🛠 What does **Build** do?
Creates two files for this profile **in a folder you choose**:
- A shell script: “ProfileName.sh”
  - Launches GZDoom with the exact settings for this profile
- A mini macOS app: “ProfileName.app”
  - Double‑click to run the script without Terminal

**Tips:**
- You can move the .app anywhere (Dock, Desktop, etc.)
- Keep the .sh where you built it, so the .app can find it
- Re‑run Build to overwrite these files in the same folder

## 🛡️ What does **Privacy** do?
- Hides your home path as “~” in fields and the CLI preview
- Saves your real paths under the hood (full absolute paths)
- Makes the CLI read‑only while Privacy is ON — unless you enable
  “Allow editing while Privacy is ON”

## 🔒 What does **Lock** do?
- Prevents changes to Paths, Mods, Extra Args, and Backup options
- You can still **Engage**, **Build**, and **Back Up Now**, and you can click **Show Backups**
- Click the lock again to unlock and allow editing

## 📌 What does **Pin to Dock Menu** do?
- Adds the profile to the app’s Dock menu (right-click the icon)
- Lets you quickly Engage from outside the app
- Toggle it on/off per profile or with the sidebar button

## 📤 How do I **Import / Export Profiles**?
- Use **Export** to save selected or all profiles as JSON
- Use **Import** to load profiles from another system or user
- Paths are localized and adjusted automatically when importing

## 📝 Editing Config Files
Use the built‑in Edit buttons next to the config files to open them in your preferred editor:
- **makeitso.ini** — launcher settings
- **gzdoom.ini** — GZDoom preferences
- **autoexec.cfg** — launch-time console commands
- **Save games** — opens the save game locations folder in Finder

Supported editors (detected automatically): **TextEdit**, **BBEdit**, **CotEditor**, **Visual Studio Code**, **Sublime Text**, **Nova**. You can also choose **Another App…**

> These files are **plain text**. In your editor, use **Plain Text** mode (no rich text).
