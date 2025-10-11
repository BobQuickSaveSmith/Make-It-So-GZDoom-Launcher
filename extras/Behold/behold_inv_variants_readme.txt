# Behold! Invulnerability Variants (behold_inv_##.pk3) — Read Me

## What are these?
These are optional **invulnerability variants** of *Behold!* that add a short grace period after you press your Behold trigger (any mode).  
- `behold.pk3` (the base mod) **does not** include invulnerability.  
- If you want a grace window, load **one** of the `behold_inv_##.pk3` files **instead of** `behold.pk3` (don’t load both).

Each variant is identical to Behold! except for the grace time:
- `behold_inv_03.pk3` – about 3 seconds
- `behold_inv_05.pk3` – about 5 seconds
- `behold_inv_07.pk3` – about 7 seconds
- `behold_inv_10.pk3` – about 10 seconds

> The grace protects you with classic (non‑reflective) Invulnerability so you can re‑enter the fight without getting instantly deleted. Monsters still spawn as usual for the selected mode.

---

## How to use
Pick **one** file and run it like any other mod:

### Drag & drop (quickest)
- **Windows/macOS**: Drag a `behold_inv_##.pk3` onto your GZDoom executable/app (or onto a shortcut).

### Command line
```
gzdoom -file path/to/behold_inv_05.pk3 -iwad path/to/DOOM2.WAD
```
(Use the variant you prefer; don’t also load `behold.pk3`.)

### Using Make It So (the launcher)
1. Add `behold_inv_##.pk3` to your mod list (do **not** add `behold.pk3` at the same time).
2. Launch as usual. Make It So will handle the rest.

### Using ZDL
1. Add `behold_inv_##.pk3` to the External Files list (omit `behold.pk3`).
2. Set your IWAD and click **Launch**.

---

## What changes in gameplay?
- When you press your Behold trigger (any mode), you get **N seconds** of invulnerability (depending on the chosen variant).
- You still receive the **Super Shotgun** and **Plasma Rifle**, plus their associated **Shells (8)** and **Cells (40)**, exactly like the base Behold flow.
- Monster spawns behave the same: each mode tries to spawn *up to* its target count around you, with fallback attempts and a last‑resort telefrag spawn to help guarantee at least one enemy in tight spaces. Spawns can still fail in cramped maps and may occasionally end up in walls.

**Important:** Load only **one** invulnerability variant at a time. These replace the same internals and should not be combined with each other or with `behold.pk3`.

---

## Advanced: Edit the grace time yourself
If none of the provided durations feels right, you can adjust it in minutes using a plain text editor.

### 1) Unpack the variant
Pick any `behold_inv_##.pk3` as your starting point.

- **Windows (7‑Zip):**
  - Right‑click the PK3 → 7‑Zip → **Open archive**, then **Extract** to a working folder.
- **Windows (PowerShell):**
  ```powershell
  Expand-Archive -Force .\behold_inv_05.pk3 .\behold_inv_work\
  ```
- **macOS (Terminal):**
  ```bash
  mkdir behold_inv_work
  cd behold_inv_work
  unzip ../behold_inv_05.pk3
  ```
- **Linux:**
  ```bash
  mkdir behold_inv_work
  cd behold_inv_work
  unzip ../behold_inv_05.pk3
  ```

### 2) Edit the duration (DECORATE)
Open the `DECORATE` file in any plain‑text editor (Notepad, BBEdit, VS Code, etc.). Find:

```
actor DP_GraceGiver : PowerupGiver
{
  ...
  Powerup.Type Invulnerable
  Powerup.Duration 175   // example: ~5 seconds
  ...
}
```

Change `Powerup.Duration` to your preferred number of **tics** (35 tics = 1 second).

#### Tic ↔ Second chart
| Seconds | Tics | Seconds | Tics |
|---:|---:|---:|---:|
| 1 | 35 | 11 | 385 |
| 2 | 70 | 12 | 420 |
| 3 | 105 | 13 | 455 |
| 4 | 140 | 14 | 490 |
| 5 | 175 | 15 | 525 |
| 6 | 210 | 16 | 560 |
| 7 | 245 | 17 | 595 |
| 8 | 280 | 18 | 630 |
| 9 | 315 | 19 | 665 |
| 10 | 350 | 20 | 700 |

> Tip: multiply seconds by 35 to get tics. Example: 7 seconds × 35 = **245**.

### 3) Repack to PK3
Repack **the contents** of the working folder (not the folder itself) as a ZIP, then rename `.zip` to `.pk3`.

- **Windows (7‑Zip GUI):**
  1. Open your working folder, press **Ctrl+A** to select all files (e.g., DECORATE, KEYCONF, MENUDEF, etc.).
  2. Right‑click → 7‑Zip → **Add to archive…** → **Archive format: zip**, **Compression level: Ultra** → OK.
  3. Rename the resulting `.zip` to something like `behold_inv_custom.pk3`.

- **Windows (7‑Zip CLI):**
  ```powershell
  cd .\behold_inv_work\
  & 'C:\Program Files\7-Zip\7z.exe' a -tzip -mx=9 ..\behold_inv_custom.pk3 *
  ```

- **macOS / Linux (zip):**
  ```bash
  cd behold_inv_work
  # Optional: remove Finder cruft on macOS
  find . -name ".DS_Store" -delete
  zip -9 -r ../behold_inv_custom.pk3 .
  ```

### 4) Test
Launch GZDoom with your new PK3, e.g.:
```
gzdoom -file path/to/behold_inv_custom.pk3 -iwad path/to/DOOM2.WAD
```
Or add it via **Make It So** / **ZDL** (remember: use the custom PK3 **instead of** `behold.pk3`).

---

## Notes & tips
- Invulnerability here is standard, non‑reflective; projectiles do not bounce back.
- If you run other gameplay mods that change weapon class names, Behold’s “give SSG + Plasma + ammo” may not match. That’s fine—your other mod’s weapons will still work; Behold doesn’t require those grants to succeed.
- Spawn behavior is unchanged from base Behold; the only difference in these variants is the grace window length.

## Credits
- **Behold!** by BobQuickSaveSmith
- Thanks to everyone playtesting and giving feedback.
