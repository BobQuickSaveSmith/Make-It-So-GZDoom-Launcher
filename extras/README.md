# Extras — Optional Files and Add-Ons

This folder contains optional files, helpers, test variants, and examples that extend or complement the main **Make It So** launcher.

| File | Description |
|------|--------------|
| **behold_release_bundle_v2.zip** | Newest version of Behold! — includes grace invulnerability options and updated readmes |
| **behold_readme.txt** | Plain-text README for Behold! |
| **behold.png** | Preview image for Behold! |
| **crowdcontrol_bind_for_bp.txt** | Example keybind sequence for Crowd Control (Brutal Pack) |
| **mod_load_order.txt** | Example mod load order used in typical sessions |
| **behold_inv_variants_readme.txt** | Overview of the invulnerability variants — how they work, how to load them, and how they change Behold’s behavior |
| **behold_inv_troubleshooting.txt** | Console tips to test invulnerability effects (give DP_GraceGiver, etc.) |
| **BEHOLD_BP_README.txt** | Full player & technical guide for Behold! — BP Edition (load order, keybinds, modes, SOS, advanced edits). |
| **Behold_BP_Variants_Guide.txt** | Explains the 40 pre-built variants (filename parts, how to pick, examples). |
| **brutalpack_summonable_monsters.txt** | Summonable monster reference for Brutal Pack — testing / spawn lists by category. |
| **Behold_BP_V1.zip** | Complete Behold! — BP Edition pack (Main .pk3 + variant builds) for quick download. |

---

**Load Order Tip:**  
For Behold! BP Edition, load it *after* **Brutal Pack** so it can properly hook into its shoulder-weapon logic, resurrection system, and monster definitions.

```
1. BRUTALPACK 10.x.pk3
2. Behold_BP_Main.pk3 (or any variant)
```

**Default configuration in `Behold_BP_Main.pk3`:**
- **Earthquake preset:** Whiplash  
- **Spawn mode:** Random Mayhem  
- **Message style:** HUD / Bold  

(Other combinations are available among the 40 variants.)
