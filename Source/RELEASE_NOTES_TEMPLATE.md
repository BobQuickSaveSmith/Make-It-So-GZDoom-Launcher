# 🚀 Release: v1.0.0

This is the first public release of **Make It So** — a macOS build & launcher toolkit optimized for GZDoom mods and other Swift/Xcode-based projects.

---

## ✨ Features

- ✅ One‑file build script (`Make It So.command`) that:
  - Detects your `.xcodeproj`
  - Builds in Release mode
  - Embeds icon.png → AppIcon.icns
  - Signs app ad-hoc to reduce Mac prompts
  - Creates `.zip` and optional `.dmg`
  - Writes `RELEASE_NOTES.md` and `AUDIT_REPORT.md`
  - Can notarize and staple (if Apple Developer ID is set up)
  - Can upload to GitHub Releases (via CLI)

- 📄 Single PDF/MD/TXT guide included
- 📁 Source folder included for easy forking
- 📦 Full demo app provided (no Xcode project needed)

---

## 📁 Contents

- `Make It So.command`
- `Make_It_So_README_V1.(pdf|md|txt)`
- `LICENSE.txt`
- `.gitignore`, `.gitattributes`, GitHub issue templates
- `demo-project/` folder with buildable SwiftUI test app

---

## 📝 How to use

```bash
chmod +x "Make It So.command"
./Make\ It\ So.command --fix-all --open
```

After a few seconds, everything will be built, zipped, and opened in Finder.

---

## 🧰 System Requirements

- macOS 11+ (Big Sur or newer)
- Xcode or Command Line Tools installed
- Optional: `gh` for GitHub uploads, `notarytool` for notarization

---

## 📨 Contact

Support: **makeitsoapp@proton.me**

Forks welcome. Bugs forgiven. Glory optional.