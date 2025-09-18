# Tools Folder — What’s Inside & How to Use It

This guide explains the helper scripts you’ll find in the **Tools/** folder. Each script is double‑clickable on macOS. If a script doesn’t open when you double‑click it, give it permission first:

```bash
chmod +x "<script name>.command"
```

Then just double‑click it in Finder (or run it from Terminal).

> Tip: Most tools show friendly prompts. If a path is needed, you can usually **drag a file or app into the Terminal** window and press **Return**.

---

## 1) Change Any App Icon.command

**Purpose**  
Update the icon of **any** macOS `.app` you choose. It converts a PNG into a full `.icns` set and embeds it in the app’s Resources, updates `Info.plist`, and (when possible) re‑signs the app locally to refresh Finder/Dock.

**Typical flow**  
1. You’ll be prompted to pick an **icon PNG** (1024×1024 recommended).  
2. You’ll be prompted to pick the **target .app**.  
3. The script converts the PNG → `.icns`, sets `CFBundleIconFile`, and ad‑hoc signs.  
4. It reveals the updated app in Finder.

**Good to know**  
- If the icon doesn’t update immediately, move/rename the app once or **Relaunch Finder** (⌥ right‑click Finder in Dock → *Relaunch*).

---

## 2) Change Make It So App Icon.command

**Purpose**  
Same idea as above, but **pre‑wired for your Make It So build output**. It tries to auto‑find:  
- `art/icon.png` (or `icon.png`) next to your project, and  
- the **newest** packaged app under `dist/**/app/*.app`.

**Typical flow**  
1. Run the script; it will auto‑detect the most recent app and icon.  
2. If it can’t find them, it will **ask you** to pick the PNG and the `.app`.  
3. It embeds the icon and refreshes the app signature locally.

---

## 3) GZDoom Advanced macOS Launcher Script.command

**Purpose**  
A convenience launcher for **GZDoom** on macOS. It is designed to help you start GZDoom with your preferred WAD/PK3 files and settings without typing long command lines.

**Typical flow** *(exact prompts may vary)*  
1. Choose your **GZDoom.app** or executable (first run).  
2. Pick an **IWAD / PWAD / PK3** or a folder with game data.  
3. Optional: set extra parameters (mods, fullscreen, etc.).  
4. The script launches GZDoom with the selected content.

**Good to know**  
- Keep your WADs in a consistent folder so they’re easy to pick.  
- If GZDoom isn’t installed, get the latest build from the official project and place it in `/Applications` or another known location.

---

## 4) Make .app Compiler.command

**Purpose**  
Create a **clickable macOS .app** wrapper for a script or simple command entry point. Useful when you want a true app bundle that users can run from Finder like any other application.

**Typical flow** *(may vary depending on your setup)*  
1. You’ll provide a script or command you’d like wrapped.  
2. The tool generates a minimal `.app` bundle around it.  
3. You can then customize the app’s icon using the icon tools above.

**Note**  
If your team already distributes a full Swift/Xcode app, you may not need this. It’s mainly for turning a script into a user‑friendly app.

---

## 5) Organize Project Structure.command

**Purpose**  
Gently **standardize your project layout** so the packager can find what it needs and your repository stays tidy. It can also create a **safety backup ZIP** before it changes anything.

**What it checks/creates**  
- Ensures key folders exist: `art/`, `dist/`, `docs/`, `Tools/`, `.github/`  
- Optionally moves loose assets into sensible places (never touches your Xcode files without asking)  
- Can write a basic `.gitignore` and boilerplate files if missing  
- Offers to create a dated backup ZIP **outside** your project first

**Running it safely**  
- Double‑click to run. If prompted for backup, it will suggest an iCloud Drive location (or you can enter a path).  
- Choose **safe mode** to keep all source locations intact.  
- There’s usually an **advanced** option that can update references after moving files—only use this if you know your project and you agree with every change it proposes.

---

## 6) Post To GitHub Release (Auto).command

**Purpose**  
Create a GitHub Release and upload the **newest** ZIP/DMG from `dist/`, without having to browse manually.

**How it works**  
- Auto-detects the latest build artifact in `dist/` (looks in both direct files and timestamped subfolders).  
- If it can’t find one, it asks you to drag a ZIP/DMG.  
- Prompts for repo (`owner/repo`), tag (e.g., `v1.0.0`), and a title.

**GitHub token**  
- Will use `GITHUB_TOKEN` or `GH_TOKEN` if set.  
- Otherwise, it looks in the macOS Keychain (`makeitso_gh_token`).  
- If none is found, it prompts you, and can **save to Keychain** for next time.

**Run**  
1) Make it executable (once):  
```bash
chmod +x "Post To GitHub Release (Auto).command"
```  
2) Double-click it in Finder (or run via Terminal).

---

## Running any tool

- **Double‑click** the `.command` file in Finder.  
- If nothing happens, grant permission once:  
  ```bash
  chmod +x "<tool name>.command"
  ```
- You can also run it from Terminal:  
  ```bash
  ./<tool name>.command
  ```

**Support**: makeitsoapp@proton.me



