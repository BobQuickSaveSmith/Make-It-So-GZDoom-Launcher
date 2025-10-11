BEHOLD! — BP EDITION 
================================

Behold! - BP Edition is a chaos-driven resurrection & crowd-control add‑on for GZDoom.
Built for continuous combat: less save‑scum interruptions, more fighting! 

Get Brutal Pack: ModDB – https://www.moddb.com/addons/brutal-pack1 
Brutal Pack Discord: https://discord.gg/GczEEGda

Important Load Order
──────────────────────
Behold! - BP is an add-on and must be loaded **after** the Brutal Pack mod in GZDoom.

Load Example:
1. BRUTALPACK 10.x.pk3
2. Behold_BP_Main.pk3

Why:
This ensures Behold! correctly overrides and integrates with Brutal Pack’s shoulder weapons,
surge logic, and resurrection effects. If loaded before Brutal Pack, several systems will not initialize properly.

This README has 4 sections:
1) PLAYER GUIDE — how it plays, keybinds, what you get on resurrection
2) MONSTER LIST — the exact spawn pool used in BP Edition
3) MODDER GUIDE — where things live in DECORATE (quick map)
4) ADVANCED CUSTOMIZATION — change default message style, Earthquake (camera+SFX) preset, and spawn mode
5) BRUTAL PACK — summonable monster reference 
6) Credits 

────────────────────────────────────
1) PLAYER GUIDE — SURVIVE. FIGHT. UNLEASH HELL.
────────────────────────────────────

Why use Behold! - BP?
- Instant resurrection with a vengeance wave around you
- Crowd Control (shoulder‑based) that cycles fast for swarms
- Surge modes that let you spawn rings of foes on demand
- Sensible auto‑loadouts so you’re never stuck

What happens on **Resurrection** (BP Edition)?
- Your core **shoulder cooldowns are refueled** (BP behavior)
- You receive **Blue Armor**
- You receive a **SoulSphere** (100 health; can overfill up to 200)
- A **vengeance surge** of enemies spawns around you

Keybinds (Options → Behold! - BP):
- **Resurrect**
- **Spawn Behold Surge** (instant spawn ring; uses the active Mode)
- **Cycle Mode** (The Quadrant → More Trouble → Random Mayhem → Hell’s Fury → Total Apocalypse → back to Quadrant)
- **Crowd Control** (shoulder cycle)
- **Crowd Control Unlimited** (builds “heat” and then unleashes a bigger surge)
- **Toggle Message Style** (HUD/Bold vs Console log)
- **SOS / Emergency**
  - **Friendly Marine** — Bring your BFF to help fight
  - **Marine Squad** — Call for backup, full squad arrives
  - **Wipe ’Em All Out** — The nuclear option (clears all hostiles)

Default Modes (summary):
- **Random Mayhem (Default)** — 5+ spawns, varied arcs + rear telefrag fallback
- **The Quadrant** — 4 tight arrivals near you (+ telefrag fallback)
- **More Trouble** — Balanced cross + diagonals
- **Hell’s Fury** — Two rings, heavier rear entries
- **Total Apocalypse** — Densest two‑ring pattern with fallbacks

All modes include “guarantee” logic so something always arrives.

────────────────────────────────────
2) MONSTER LIST — ACTUAL SPAWN POOL
────────────────────────────────────

Singles (weights set in DP_RandomFoe_RS):
- HellKnight
- Revenant
- BaronOfHell
- ChaingunGuy
- Cacodemon
- Arachnotron
- Fatso  (Mancubus)
- PainElemental
- Archvile
- voiddarkimp
- quadrumpus
- flemoid1
- flemoid2

Boss spice (rare):
- SpiderMastermind
- Cyberdemon

Group Packs (one roll spawns a small squad):
- DP_Pack_Chaingunners3 — 3 × ChaingunGuy
- DP_Pack_Cacodemons3   — 3 × Cacodemon
- DP_Pack_LostSouls4    — 4 × LostSoul
- DP_Pack_Flemoids3     — 2 × flemoid1 + 1 × flemoid2
- DP_Pack_HellKnights2  — 2 × HellKnight
- DP_Pack_Revenants3    — 3 × Revenant
- DP_Pack_Arachno2      — 2 × Arachnotron
- DP_Pack_VoidDarkImps2 — 2 × voiddarkimp
- DP_Pack_PainPlus2Losts— 1 × PainElemental + 2 × LostSoul

These are the exact actors referenced in DECORATE’s `DP_RandomFoe_RS` and “DP_Pack_*” helpers.

────────────────────────────────────
3) MODDER GUIDE — QUICK MAP OF IMPORTANT ACTORS
────────────────────────────────────

Core flow:
- **DP_ResurrectFire** — “do everything on resurrection” (gives SoulSphere, BlueArmor, grace, then triggers surge)
- **DP_ResurrectSurge** — fires **DP_MasterTrigger** 5 times (spaced) after resurrection
- **DP_MasterTrigger** — mode router that actually spawns enemies (labels: DoQuad/DoMore/DoRandom/DoFury/DoApoc)
- **DP_Mode_Quad / More / Random / Fury / Apoc** — inventory tokens for the current spawn mode
- **DP_ModeCycle** — cycles the above tokens
- **HR6_Fire** — logic for “Crowd Control Unlimited” (heat → arm → unleash)
- **DP_QBed_Master** — Earthquake bed dispatcher (camera shake + rumble presets)
  - spawns: **DP_RattleBed_Default, _Jolt, _Sway, _Cinematic, DP_RumblePulse** etc.

Console utilities (safe to summon):
- **DP_ConsoleTriggerMaster** — instantly runs one **DP_MasterTrigger**
- **DP_ConsoleSpawnRandom** — spawn a single DP_RandomFoe_RS now
- **DP_ConsolePrintMode** — logs the current spawn mode

Message style:
- **DP_MsgStyleToggle** + token **DP_ConsoleOnlyMsgs**

Earthquake presets (camera shake + SFX):
- **DP_RumblePulse** (a.k.a. Whiplash; shortest one‑shot)
- **DP_RattleBed_Default / _Jolt / _Sway / _Cinematic** (longer orchestrations)

────────────────────────────────────
4) ADVANCED CUSTOMIZATION (FOR POWER USERS)
────────────────────────────────────

🛠 Unpack / Edit / Repack
1) **Unpack** the `.pk3` with any ZIP tool or SLADE (a .pk3 is just a zip).
2) **Edit** `DECORATE` (and `MENUDEF` for menu text/ordering if desired).
3) **Repack**: zip the folder contents and rename back to `.pk3` (or use SLADE’s “Save As PK3”).

A) Change DEFAULT **Message Style** (HUD/Bold vs Console)
--------------------------------------------------------
Goal: ship a variant that boots in **Console** messages *or* **HUD/Bold** by default.

Find this actor in `DECORATE`:
```
actor DP_MsgStyleToggle : CustomInventory
{
  States
  {
  Use:
    TNT1 A 0 A_JumpIfInventory("DP_ConsoleOnlyMsgs", 1, "SwitchToBold")
    TNT1 A 0 A_GiveInventory("DP_ConsoleOnlyMsgs", 1)
    TNT1 A 0 A_PrintBold("\c[Gray]Behold: Message style = Console\c-")
    Stop
  SwitchToBold:
    TNT1 A 0 A_TakeInventory("DP_ConsoleOnlyMsgs", 999)
    TNT1 A 0 A_PrintBold("\c[Gray]Behold: Message style = Bold\c-")
    Stop
  }
}
```

To **default to Console** messages on game start, insert a one‑time grant of the token in a “startup” location you control, e.g. at the end of `DP_ResurrectFire`’s `Spawn:` or a small autogrant actor that runs at map load:
```
TNT1 A 0 A_GiveInventory("DP_ConsoleOnlyMsgs", 1)
```
To **default to HUD/Bold**, make sure no place gives that token by default. Players can still toggle in‑game.

B) Change DEFAULT **Earthquake** preset (camera+SFX)
----------------------------------------------------
Terminology note: we use *Earthquake* to avoid confusion with id’s Quake®.

Dispatcher:
```
actor DP_QBed_Master : Actor
{
  States
  {
  Spawn:
    ...
    // Route by Earthquake Mode token (held by the player)
    TNT1 A 0 A_JumpIfInventory("DP_QMode_Whip", 1, "WHIP", AAPTR_MASTER)
    TNT1 A 0 A_JumpIfInventory("DP_QMode_Cine", 1, "CINE", AAPTR_MASTER)
    TNT1 A 0 A_JumpIfInventory("DP_QMode_Sway", 1, "SWAY", AAPTR_MASTER)
    TNT1 A 0 A_JumpIfInventory("DP_QMode_Jolt", 1, "JOLT", AAPTR_MASTER)
    ...
    // No mode token → Default bed
    TNT1 A 0 A_SpawnItemEx("DP_RattleBed_Default", 0,0,0, 0,0,0, 0, SXF_SETMASTER|SXF_TRANSFERPOINTERS)
    Stop
  ...
```

If you want **Whiplash** (shortest) as default when no token is present, **replace** that “Default bed” line with:
```
TNT1 A 0 A_SpawnItemEx("DP_RumblePulse", 0,0,0, 0,0,0, 0, SXF_SETMASTER|SXF_TRANSFERPOINTERS)
```
Optionally, create mode‑setter helpers (DECORATE-safe):
```
actor DP_QMode_Clear  : CustomInventory { States { Use: TNT1 A 0 A_TakeInventory("DP_QMode_Jolt",999); TNT1 A 0 A_TakeInventory("DP_QMode_Sway",999); TNT1 A 0 A_TakeInventory("DP_QMode_Cine",999); TNT1 A 0 A_TakeInventory("DP_QMode_Whip",999); Stop } }
actor DP_QMode_SetWhip: CustomInventory { States { Use: TNT1 A 0 A_GiveInventory("DP_QMode_Clear",1); TNT1 A 0 A_GiveInventory("DP_QMode_Whip",1); Stop } }
```
Give `DP_QMode_SetWhip` once on startup if you prefer a forced “Whiplash” token instead of changing the dispatcher’s default line.

C) Change DEFAULT **Spawn Mode**
--------------------------------
Modes are inventory tokens. The spawn router lives in `DP_MasterTrigger`.

To **force a default** token at boot, grant one of these once (e.g., in a tiny autogrant actor that runs at map start):
```
TNT1 A 0 A_GiveInventory("DP_Mode_Quad",   1)  // 4 tight
TNT1 A 0 A_GiveInventory("DP_Mode_More",   1)  // wider cross
TNT1 A 0 A_GiveInventory("DP_Mode_Random", 1)  // DEFAULT — varied
TNT1 A 0 A_GiveInventory("DP_Mode_Fury",   1)  // heavy two rings
TNT1 A 0 A_GiveInventory("DP_Mode_Apoc",   1)  // densest
```
Players can still use **DP_ModeCycle** at runtime.

D) Packaging quick‑ref
----------------------
- A `.pk3` **is** a zip. Keep folder structure (DECORATE, MENUDEF, sounds/, sprites/…)
- Zip the *contents* of the root folder (not the folder itself), then rename to `.pk3`
- SLADE can open/save PK3 directly

────────────────────────────────────
5 BRUTAL PACK — SUMMONABLE MONSTER REFERENCE
────────────────────────────────────

# BrutalPack Summonable Entities — Categorized Reference List

This is a curated list of summonable entities confirmed to work in BrutalPack, grouped by category.  
Each entry includes the summon command and a brief description. Use this list for testing, spawning, and modding purposes.  
Controversial entities are marked accordingly.

---

## 😈 Demons (Pinky Family)
- `summon demon` — Standard Pinky Demon  
- `summon bulldemon` — Synonym for Pinky  
- `summon brutalstealthdemon` — Invisible unless attacking  
- `summon flemoidcyclopticcommonus` — Funny alien pinky variant  
- `summon spectre` — Semi-invisible Pinky  
- `summon spectro` — Fast, stealthy Pinky  
- `summon armlessdemon` — Injured, half-dead Pinky  
- `summon poorpinkylosthisarm` — Dying, immobile Pinky  
- `summon vanillaspectre` — Vanilla-style spectre  

## 💀 Revenants & Skulls
- `summon revenant` — Missile skeleton  
- `summon brutalstealthrevenant` — Invisible powerhouse  
- `summon lostsoul` — Flying flame skull  
- `summon chexsoul` — Tougher skull  
- `summon betaskull` — Fast stare-damage skull  

## 🧠 Floaters (Cacos, Pain Elementals)
- `summon cacodemon` — Red floaty ball  
- `summon stealthcacodemon` — Sneaky bitey floatball  
- `summon brutalstealthcacodemon` — Stealth juggernaut  
- `summon painelemental` — Spawns lost souls  

## 🦍 Hell Nobility (Knights & Barons)
- `summon hellknight` — Green brute  
- `summon hellknight2` — Synonym  
- `summon vanillahellknight` — Standard 40-damage variant  
- `summon brutalstealthhellknight` — Sneaky heavy hitter  
- `summon stealthhellknight` — Stealth projectile  
- `summon baronofhell` — Buff red brute  
- `summon brutalstealthbaron` — Red, invisible baron  
- `summon flembrane` — Stationary baron gunner  

## 🐽 Fat Demons
- `summon mancubus` — Close-range flamethrower  
- `summon vanillafatso` — Standard  
- `summon brutalstealthfatso` — Invisible, heavy  

## 🔥 Archviles
- `summon archvile` — Resurrector & fire summoner  
- `summon teharchvile` — Meme version  
- `summon brutalstealtharchvile` — High-risk invisible threat  

## 🕷 Tech Demons
- `summon arachnotron` — Plasma spiderbot  
- `summon stealtharachnotron` — Cloaked version  
- `summon brutalstealtharachnotron` — Twin spawn chance  

## 🧠 Bosses
- `summon spidermastermind` — Chaingun boss  
- `summon cyberdemon` — Classic rocket titan  
- `summon cyberdemonboss` — Enhanced cyberdemon  

## 🧪 Joke / Throwable
- `summon throwedimp` — Projectile imp (not fightable)  
- `summon throwedimp2` — Same  

## 👤 Humanoid Enemies
- `summon chaingunguy` — Heavy gunner  
- `summon zombieman` — Weak green soldier  
- `summon shotgunguy` — Shotgun grunt  
- `summon marinechainsaw` — Close-range slicer  

## 🚫 Controversial / Historical (Not recommended for spawn pools)
- `summon nazi` — Nazi soldier ⚠️  
- `summon nazisurrendered` — Begging Nazi ⚠️  
- `summon germandog` — Nazi dog ⚠️  
- `summon wolfensteinss` — Hitler’s dad ⚠️  
- `summon commanderkeen` — Hanged dog (shock) ⚠️  
- `summon panzertank` — Nazi tank ⚠️  
- `summon zombieseizedtank` — Seized Nazi tank ⚠️  

## 👽 Flemoid Aliens
- `summon flemoid3` — Acid alien  
- `summon armoredflemoidusbipedicus` — Bigger alien  
- `summon flemoid1` — Small variant alien  
- `summon flemoid2` — Mid-tier alien  

## 🌑 Special / Dark Entities
- `summon voiddarkimp` — Shadowy imp, dark-themed  
- `summon quadrumpus` — Acid-spitting 4-legged alien  

---

## 💡 Just for Fun Entities (not fightable or joke-only)
These were detected from the BrutalPack deep scan but may be aesthetic, broken, or unspawnable:
- `summon slugplasma`
- `summon skullonapole`
- `summon voodoodoll`
- `summon dyingmarine`
- `summon deadbaron`
- `summon hangingmarine`
- `summon errordeath`
- `summon glitchspawner`
- `summon pileofgibs`

---

## Notes
- ✅ All entities have been tested and confirmed summonable unless marked
- ❌ Some entries (like `throwedimp`) are not interactive enemies
- ⚠️ Controversial entries are included for reference only

────────────────────────────────────
6) Credits
────────────────────────────────────

BEHOLD! — BP by BobQuickSaveSmith
Testing and feedback from the GZDoom and modding communities
Inspired by roguelikes, quicksave burnout, and post-death revenge
Thanks for playing. You’re not cheating death — you’re picking a fight with it.
