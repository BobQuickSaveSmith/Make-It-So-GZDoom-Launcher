# READ ME FIRST — Make It So

This single guide explains **everything** you need to run the packaging script and find your results.
It’s written for non‑experts in clear, step‑by‑step language.

---

## What this is

`Make_It_So.command` is a **one‑file, double‑clickable** script that:
- Finds the Xcode project in the same folder
- Builds the app in **Release**
- Copies clean source files into a package
- **Imports your app icon** from a PNG (if present) and embeds it
- Optionally creates a DMG and release notes
- Writes a final report and opens the results

> **Important:** Your Xcode project **must** live in the same folder as the script.

```
📁 Your Project Folder/
├─ Make It So.xcodeproj         ← must be here
├─ Make_It_So.command             ← run this
├─ art/                         ← put icon.png here (optional, 1024×1024 PNG)
└─ (your Swift files, assets, etc.)
```

---

## Requirements (once per Mac)

- macOS with **Xcode** installed
- **Command Line Tools** (run once): `xcode-select --install`
- The script needs permission to run (see below).

---

## Give the script permission (once)

If double‑clicking does nothing, you likely need to mark it as runnable.

1. Open **Terminal**.
2. Type:
   ```bash
   chmod +x Make_It_So.command
   ```
3. Press **Return**.
4. Now double‑clicking should work. (You can also run it with `./Make_It_So.command`.)

---

## How to run (every time)

1. Put **`Make_It_So.command`** next to **`Make It So.xcodeproj`** in the same folder.
2. Double‑click **`Make_It_So.command`** (or run `./Make_It_So.command` in Terminal).
3. Follow the on‑screen prompts. Press **Return** to accept defaults.
4. When it finishes, it prints a summary of **exact paths** to everything it made and can open them for you.

---

## What the script builds

Everything is placed under a timestamped folder inside **`dist/`** so you can keep multiple builds.

Example:
```
dist/MakeItSo_Package_2025-09-12_15-45-23/
├─ source/        # a clean copy of your project files for sharing
├─ build/         # temporary build artifacts
├─ app/           # your compiled .app bundle
│  └─ Make It So.app
├─ MakeItSo_Package_2025-09-12_15-45-23.zip
├─ MakeItSo_Package_2025-09-12_15-45-23.dmg       (optional, if you said yes)
├─ MakeItSo_Package_2025-09-12_15-45-23_RELEASE_NOTES.md
└─ MakeItSo_Package_2025-09-12_15-45-23_AUDIT_REPORT.md
```

### Where to find the **app**
- Inside `dist/.../app/` you’ll see your **`.app`** bundle.
- The script offers to **open it** so you can test right away.

---

## How the icon is imported

If you provide a 1024×1024 PNG at **`art/icon.png`** (preferred) or `./icon.png`, the script:

1. Uses macOS tools **`sips`** and **`iconutil`** to convert the PNG into a full **`.icns`** file.
2. Copies that `.icns` to your app at: `YourApp.app/Contents/Resources/AppIcon.icns`.
3. Updates `Info.plist` with `CFBundleIconFile = AppIcon`.
4. Performs a **local ad‑hoc code sign** to nudge Finder/Dock to refresh the icon.
5. Shows your app in Finder. (If the icon still looks old, move the app once or relaunch Finder.)

> If you don’t provide a PNG, macOS uses a generic app icon. You can run the icon helper later, too.

---

## Optional: DMG and release notes

- The script can create a **DMG** (a disk image) to make sharing simple.
- It also writes **Release Notes** (with checksums) and an **Audit Report** summarizing the build.

---

## The Tools folder

You’ll find a **Tools/** folder alongside the script.  
It contains **optional helper scripts**. This folder is updated over time, so **open it to see what’s available**.

---

## Troubleshooting

- **“App is from an unidentified developer”**: Right‑click the app → **Open** → Open.
- **Script won’t run when double‑clicked**: run `chmod +x Make_It_So.command`, then try again.
- **Icon didn’t change right away**: move the app once or relaunch Finder (⌥ Right‑click Finder in Dock → **Relaunch**).
- **Missing tools**: install Xcode + Command Line Tools (`xcode-select --install`).

---

## Contact

Questions or ideas? **makeitsoapp@proton.me**
