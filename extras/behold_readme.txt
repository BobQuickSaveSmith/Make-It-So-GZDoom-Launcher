Behold! — Resurrection Add-On for GZDoom
=============================================

###  Intro

Behold! is a resurrection add-on for GZDoom. Whether you’re using a custom weapon pack or playing *vanilla Doom 1/2*, it drops in without drama. Load it at any time, bind a key, and face Hell’s reply.

### The Core Idea
Behold! is a resurrection add-on that gives you control over what happens *after* death. Inspired by the flow of roguelites and the frustration of quicksaves, it lets you pick your punishment and jump right back in.

When you die, trigger Behold! to return to the action—with consequences. You’re not restarting the level, and you’re not reloading a save. Instead, you come back fighting.

There’s no mercy from hell. You choose how badly it punishes you.

---

### When you trigger Behold! after dying:
- You’re instantly resurrected.
- You’re given a Super Shotgun and Plasma Rifle, along with shells and cells.
- No powerups. No mercy. Just you and the weapons to fight back.

---

### Modes: Choose Your Punishment

Each mode represents a different *flavor* of retaliation from hell:

• The Quadrant – Up to 4 enemies spawn around you in a tight cross-pattern. Short and sweet… unless it fails. Most prone to tight-space issues.

• More Trouble – Up to 6 enemies. A balanced ring that tends to spawn consistently and with good variation.

• Random Mayhem – 3 to 5 enemies in unpredictable patterns. For players who like surprise and variety. Recommended for most users.

• Hell’s Fury – Up to 10 enemies in two overlapping rings. A brutal test of close-quarters control. Most effective in larger rooms.

• Total Apocalypse – Up to 12 enemies in an elegant but deadly double ring. The most reliable mode for forcing spawns even in tight maps.

- All modes attempt fallback logic to spawn *something*, even in tight spaces.
- Spawns may appear behind you or across the room—don’t assume they’ll be polite.
- Monsters may occasionally spawn inside walls. That’s the price of defying death.

Pro tip: Keep hitting the trigger. Monsters will keep coming. The only limit is you… or your hardware.

---

### How To Use It (Players)
- Load this mod alongside any WAD, PK3, or mod combo.
- Go to Options → Behold! Options
- There, you’ll:
  - Choose your mode
  - Bind one or more keys to trigger a mode
- Triggering a mode will:
  - Instantly resurrect you
  - Spawn monsters
  - Re-arm you
- That’s it. No checkpoint. No reroll. Just continue the fight—worse off than before.

---

### Notes on Behavior
- Triggers can be used *anytime*, not just after death.
- Enemies spawn around your position in world space, using fixed ring patterns.
- Fallbacks are built in: if no monster can spawn, it’ll retry or teleport one on top of you.
- You can trigger multiple modes. You asked for it.

---

Behold! was made for fast action, chaos, and thematically appropriate suffering.
You’re not cheating death. You’re making it mad.

---

Modding / Technical Notes
=========================

### For Modders
- Everything is DECORATE-based. No ZScript required or used.
- Uses `RandomSpawner` for enemy pool (`DP_RandomFoe`)
- Weapons given are: `SuperShotgun` and `PlasmaRifle`
- Ammo is clamped and restored via `A_TakeInventory` + `A_GiveInventory`
- `DP_GiveAndClamp` handles gear grant logic
- `DP_MasterTrigger` spawns monsters using `A_SpawnItemEx` rings
- `DP_ModeReporter` provides non-ZScript mode printout via `A_Log`
- Spawn radii use tuned values like 288, 320, 384, 448 for spacing
- Pattern angles vary to prevent overlaps and alignments
- Uses `A_Jump` for randomness in modes like “Random Mayhem”
- Some inner vs outer ring logic built-in for fallback safety

### Customizing It
- To change monster pool: edit the `DP_RandomFoe` actor
- To change gear: edit `DP_GiveAndClamp`
- To change spawn patterns: edit the states in `DP_MasterTrigger`

> Monsters from hell don’t use a GPS. If they show up in a wall or behind you—it’s not a bug. It’s flavor.

Want to go deeper? Fork it. Expand it. Replace the monsters with your own. There’s no state tracking and no penalty for chaos.
