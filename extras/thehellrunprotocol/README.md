
## Quick Navigation
- [The Hell Run Protocol](#the-hell-run-protocol)
- [How To Activate](#how-to-activate)
- [Brutal Pack Load Order (Top → Bottom)](#brutal-pack-load-order-top--bottom)
- [Editorial Note](#editorial-note)

---

## The Hell Run Protocol

**What it is:**  
A continuous endurance run that removes the habit of save scumming. You fight forward without reloading saves. Resurrection and crowd control mechanics keep the pressure high but fair.

**Why it works:**  
- Death is part of the loop. Resurrection spawns create fresh encounters that feel earned.  
- Difficulty scales with your settings. Higher tiers increase spawn intensity and variety.  
- Progress feels real because you are not rewinding.

**Requirements**
- Load a map or campaign first if you are using one.  
- Use either setup:  
  - Brutal Pack + Behold-BP + add-ons (see Load Order)  
  - Behold! V3 on any base or mod configuration
- Launch with `+sv_cheats 1` so Nightmare and higher fully enable Behold! or Behold! - BP systems.

**Recommended start**
- Difficulty: Nightmare or higher if you want maximum escalation.  
- Brutal Pack users: enable your preferred gameplay options, and add Behold! - BP.  
- Base or other mods: add Behold! V3 to inject resurrection and crowd control.

**Run rules**
1. Do not reload a save to undo mistakes, unless dying in lava, etc.
2. If you die, use your resurrection and keep fighting.  

**FPS Gain Tip**  
If your FPS tanks during big fights, experiment with `vid_scalefactor`.  
Default is `1`. Try `0.3` or `0.5`.  
You can set it on launch: `+set vid_scalefactor 0.5`.

---

### How To Activate

 **(If using custom maps) Load them first.**  
   *Before anything else, load your chosen map or campaign above all mod and add-on files.*

---

#### Suggested Maps
*(In no particular order — they’re all fantastic!)*  

| Map / Megawad |
|:---------------|
| [DOOM 404 – complevel 2 megawad](https://www.doomworld.com/idgames/levels/doom2/megawads/doom404) |
| [DOOM 2: Remake for GZDoom (30 + 1 maps, OTEX)](https://www.doomworld.com/forum/topic/155604-doom-2-remake-for-gzdoom-with-otex-301-maps/) |
| [1000 Line Community Project](https://www.doomworld.com/idgames/levels/doom2/megawads/1klinecp) |
| [1000 Lines 2 – Community Project](https://www.doomworld.com/idgames/levels/doom2/megawads/1klinecp2) |
| [1000 Lines 3 – Community Project](https://www.doomworld.com/idgames/levels/doom2/megawads/1k3v1a) |
| [Real World](https://www.doomworld.com/idgames/levels/doom2/p-r/rw) |
| [Real World 2](https://www.doomworld.com/idgames/levels/doom2/p-r/rw2) |
| [Scythe](https://www.doomworld.com/idgames/levels/doom2/megawads/scythe) |
| [Scythe 2](https://www.doomworld.com/idgames/levels/doom2/Ports/megawads/scythe2) |
| [Scythe X](https://www.doomworld.com/idgames/levels/doom2/Ports/s-u/scythex) |
| [Zone 300](https://www.doomworld.com/idgames/levels/doom2/megawads/zone300) |
| [Zone 400](https://www.doomworld.com/idgames/levels/doom2/megawads/zone400) |
| [(cl-2) Bearricade](https://www.doomworld.com/idgames/levels/doom2/Ports/megawads/bearricade) |
| [Demonfear](https://doomwiki.org/wiki/Demonfear) |
| ["TNT:XIAO" - A 32 map megawad for TNT: Evilution](https://www.doomworld.com/idgames/levels/doom2/Ports/megawads/tnt-xiao) *requires* [TNT: Evilution](https://doomwiki.org/wiki/TNT:_Evilution) |
| [Khorus' Speedy Shit](https://www.doomworld.com/idgames/levels/doom2/megawads/kssht) |
| [Confinement Community Project](https://www.doomworld.com/idgames/levels/doom2/Ports/megawads/conf) |
| [Compendium](https://forum.zdoom.org/viewtopic.php?t=61211) |

---

 *Have a great map or mapset suggestion that should be added?*  
Send it to: **[makeitsoapp@proton.me](mailto:makeitsoapp@proton.me)**

---

1a) **[Load Brutal Pack and all provided add-ons](https://github.com/BobQuickSaveSmith/Make-It-So-GZDoom-Launcher/raw/main/extras/thehellrunprotocol/brutalpack_and_extras_quick_install.zip)** in their proper order. ➤ [Jump to Load Order](#load-order-top--bottom)

This zip file contains a complete, pre-configured setup for running **Brutal Pack** with my recommended add-ons for *GZDoom*.  

It includes all core files in one download for convenience.

Details are provided below for load order, sources, and to give various creators credit.

Extract this ZIP directly into your GZDoom mods folder or into a custom directory used by your launcher.


**OR**

1b) Install **[Behold! – Version 3 Resurrection Add-On for GZDoom](https://www.moddb.com/games/doom/downloads/behold-version-3-resurrection-add-on-for-gzdoom)** in any base or mod configuration.

---

2) **Run GZDoom with:**

   *+sv_cheats 1*
   
   This enables the **Nightmare and higher difficulties** to fully activate the **Behold!** or **Behold! – BP** spawning and resurrection systems.  
   
   *You’re not cheating — you’re resurrecting or unleashing Crowd Control Unlimited, and paying the demonic toll.*
   
---

3) Play your favorite map or campaign in **Nightmare** or **Extreme Nightmare.**

---

4) **Do not save or load**; when you die, **resurrect** instead.  
   Use **Crowd Control Unlimited** (for Behold! -BP) or **Crowd Control** (Behold! V3) freely, but beware: every use invites **hellish consequences** and escalating enemy spawns.

*The Hell Run Protocol can be extremely fun and intense: no interruptions, no backtracking, only the endless rhythm of resurrection and fighting.*

**Note:** Keep **Autoautosave** enabled to preserve progress when exiting or in case of a crash.  
If you fall to your death, such as into lava, resurrecting will only place you back in the same spot repeatedly.  
It will not interfere with the challenge. I recommend setting it to keep a maximum of 20 autosaves.

---

## Brutal Pack Load Order (Top → Bottom)

> Be sure to **load the files in the following order** (top → bottom) when launching GZDoom.  
> Using this order ensures all mods load correctly and maintain compatibility.

### 0) **Custom Map / Map Campaign First**
> Unless base (Doom1/2/Freedom.wad only), always load custom map or campaign first!  

---

### 1) **BRUTALPACK 10.4.pk3**  
> Core gameplay overhaul (base mod). Adds advanced AI, gore, and shoulder weapons.  
[ModDB](https://www.moddb.com/addons/brutal-pack1)

---

### 2) **Brutal Pack Neural Pack.pk3**  
> High-res AI-upscaled textures and sprites for Brutal Pack visuals.  
[YouTube Preview](https://www.youtube.com/watch?v=XEJTqbG27U4) · [Mega.nz Download](https://mega.nz/folder/04ZSyaRZ#bhhD8MpbOliZxHf9W-aHFg)

---

### 3) **BP-Glory-Kill-3.pk3**  
> Adds cinematic glory-kill executions (v3).  
[Discord Channel](https://discord.gg/GczEEGda) → `#brutal-pack-adons` (Pinned Messages)  

---

### 4) **BrutalDoom_PB-Blade_custom.pk3**  
> Custom melee system and blade weapon variant for PB/BP compatibility.  
[Discord](https://discord.gg/GczEEGda) → `#suggestions-weapons-and-abilities`  
  
---

### 5) **autoautosave-v1.6.3.pk3**  
> Automatically creates rolling autosaves during gameplay.  
[Forum](https://forum.zdoom.org/viewtopic.php?f=43&t=59889) · [GitHub](https://github.com/mmaulwurff/autoautosave)

---

### 6) **Behold_BP_Main.pk3**  
> Resurrection and crowd-control addon for Brutal Pack.  
[ModDB](https://www.moddb.com/games/doom/downloads/behold-bp)

---

### 7) **CorruptionCards-v6.3b.pk3**  
> Random gameplay modifiers that add roguelite twists to each map.  
[Forum](https://forum.zdoom.org/viewtopic.php?t=67939) · [ModDB](https://www.moddb.com/mods/corruption-cards/downloads/corruptioncards-v63b)

---

### 8) **crosshairhp.pk3**  
> Displays enemy health directly under the crosshair.  
[Forum](https://forum.zdoom.org/viewtopic.php?t=60356) · [GitHub Releases](https://github.com/Tekkish/CrosshairHP/releases/tag/v1.28)

---

### 9) **flashlight_plus_plus_v9_1.pk3**  
> Enhanced flashlight with adjustable beam and flicker.  
[ModDB](https://www.moddb.com/games/doom/addons/flashlight-plus-plus) · [Forum](https://forum.zdoom.org/viewtopic.php?f=43&t=75585&p=1221621)

---

### 10) **gearbox-0.7.3.pk3**  
> Custom weapon and upgrade selector; integrates with most weapon mods.  
[GitHub](https://github.com/mmaulwurff/gearbox) · [Forum](https://forum.zdoom.org/viewtopic.php?t=71086)

---

### 11) **LiveReverb.pk3**  
> Dynamic environmental reverb based on sector type and geometry.  
[Doomworld](https://www.doomworld.com/forum/topic/120740-livereverb-dynamic-reverb-for-all-doom-maps/) · [Forum](https://forum.zdoom.org/viewtopic.php?t=71849)

---

### 12) **minimap_m.pk3**  
> Adds an overlay minimap with custom colors and transparency options.  
[Discord](https://discord.gg/GczEEGda) → `#suggestions-monsters_and_items`  

---

### 13) **HXRTCHUD_BP_V10.4a_v2.pk3**  
> Alternate HUD layout tuned for Brutal Pack 10.4.  
[Discord](https://discord.gg/GczEEGda) → `#brutal-pack-adons` (Pinned Messages)  

---

## [Editorial Note]

Removed Gun Bonsai (GunBonsai-0.10.6.pk3) for the following reasons:  
a) It caused occasional instability and lock-ups.  
b) While an excellent mod, its frequent interruptions disrupted The Hell Run Protocol flow.  
c) It made the overall experience too easy on any difficulty, especially when combined with Crowd Control.  


_Last updated 2025-10-19_
