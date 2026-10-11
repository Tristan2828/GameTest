# Medieval Survival: art brief

**The game:** a dark fantasy pixel-art survivor in the style of Vampire Survivors, seen from top down. You only move; your weapons fire by themselves at hordes of undead. It's co-op for 1–4 players, and a run goes through 3 stages (The Crypt, The Bone Marsh, The Burning Cathedral), each about 4 minutes of waves and then a boss. The screen is often packed with hundreds of enemies, bullets and pickups, so **every sprite must read instantly at tiny size**.

Today every sprite is hand-written as text rows in `src/art/pixel_art.gd` (one character per pixel, from a shared 40-color palette). That file is the best reference for the current look: open it to see each sprite's shapes and colors.

**Tracking:** `assets.yaml` (repo root) lists every ID below with its size, frames, source, status and license; this brief says what each one should be. Keep the two in step.

## Technical requirements (all files)
- **Format:** PNG, RGBA, transparent background, **1 pixel = 1 game pixel**. Don't upscale: the game scales up itself (640x360 base resolution, nearest-neighbor, integer scaling).
- **Where to put them:** `assets/art/<sprite_id>.png`, named with the sprite IDs below (e.g. `assets/art/ghoul.png`, `assets/art/ghoul_walk_1.png`).
- **Keep each sprite's current size** (the sizes in the tables). Hitboxes, layout and UI slots are tuned to them. If something truly needs to be bigger, list it separately and say why.
- **Animation frames are separate files with the same size as the base sprite** (the game checks this): `<sprite>_walk_1`, `<sprite>_walk_2`, `<sprite>_attack`, `<sprite>_1`.
- **Hard pixels only:** no anti-aliasing, no semi-transparent pixels except where noted.
- You can deliver a few files at a time: any ID without a file keeps its current text sprite.

## Style rules
- **Dark outline:** creatures, heroes, pickups and icons have a 1 px near-black outline (`#17121C`). It's what keeps them readable on the dark floor.
- **Palette:** stay close to the current 40-color palette (top of `pixel_art.gd`): muted, slightly desaturated dark-fantasy colors with a few bright accents (gold, soul blue, fel green, fire orange). Bright colors are reserved for things you need to notice: pickups, bullets, eyes, weapon effects.
- **Facing:** characters and enemies face the viewer (front or 3/4 view) and are drawn **left/right symmetric where possible**. The game mirrors them to face left or right.
- **Player color (important):** heroes use two special colors for their clothing/cloak, which the game recolors per player (each of the 4 players has their own color). Draw those areas in **pure magenta `#FF00FF` (main) and dark magenta `#800080` (shade)**. Every other color stays as drawn.
- **Enemies must not look like heroes,** and enemy bullets must not look like player shots.
- **Floor props are background:** the game draws them dimmed and half see-through, without an outline, so they never compete with monsters.

## Heroes (4)
| ID | Hero | Size | Frames | Notes |
|---|---|---|---|---|
| `wanderer` | Kael the Wanderer (Bolt Gun) | 12x14 | `_walk_1`, `_walk_2` | Hooded traveler, glowing eyes in the hood shadow. |
| `gravekeeper` | Mortimer the Gravekeeper (Reaper's Scythe) | 14x16 | `_walk_1`, `_walk_2` | Wide-brimmed hat, gaunt face. Tanky. |
| `hexblade_witch` | Morwen the Hexblade Witch (Chain Lightning) | 12x16 | `_walk_1`, `_walk_2` | Witch hat, hex magic. |
| `necromancer` | Vesper the Necromancer (Bone Spears) | 12x16 | `_walk_1`, `_walk_2` | Robed, skull motifs. |

All four are also shown larger in the lobby's hero picker (the same sprite scaled up), so they should hold up at 4x.

## Enemies
| ID | Enemy | Size | Frames | Notes |
|---|---|---|---|---|
| `shambler` | Shambler (basic zombie) | 12x12 | `_walk_1`, `_walk_2` | The most common enemy. Slow. |
| `bat` | Bat | 14x8 | `bat_1` (wing flap) | Fast, erratic. |
| `ghoul` | Ghoul; also the Ghoul Champion at 1.7x | 20x20 | `_walk_1`, `_walk_2` | Big brute. |
| `cultist` | Cultist | 12x14 | `_walk_1`, `_walk_2`, `_attack` | Shoots. `_attack` = casting pose. |
| `mire_crawler` | Mire Crawler | 10x8 | `_walk_1`, `_walk_2` | Low swamp creature (Bone Marsh). |
| `plague_spitter` | Plague Spitter; also the Plague Champion at 2x | 12x12 | `_attack` | Spits poison bullets. |
| `flame_imp` | Flame Imp | 10x10 | `flame_imp_1` (flicker) | Burning Cathedral. |
| `fallen_paladin` | Fallen Paladin; also the Paladin Champion at 1.7x | 18x18 | `_walk_1`, `_walk_2`, `_attack` | Corrupted knight. |
| `grave_robber` | Grave Robber (map event: a thief who runs off with loot) | 9x11 | `_walk_1`, `_walk_2` | Should look sneaky, carrying a sack. |

## Bosses (drawn at 2x in game)
| ID | Boss | Size | Frames | Notes |
|---|---|---|---|---|
| `bone_warden` | The Bone Warden (The Crypt) | 24x24 | `_attack` | Armored skeleton lord. |
| `mire_hag` | The Mire Hag (The Bone Marsh) | 24x24 | `_attack` | Swamp witch. |
| `ashen_bishop` | The Ashen Bishop (The Burning Cathedral) | 24x24 | `_attack` | Burnt priest, fire and ash. |

## Pickups and world objects
| ID | What | Size | Frames | Notes |
|---|---|---|---|---|
| `gem` / `gem_mid` / `gem_big` | XP gems (small / medium / large) | 7x8 / 9x11 / 11x13 | — | Must pop on a dark floor. |
| `coin` / `coin_big` | Coins | 5x5 / 7x7 | `coin_1`, `coin_big_1` (spin) | Gold. |
| `ember` | Ember (meta currency, title-menu Ember Shrine) | 9x12 | — | Glowing ember / flame shard. |
| `pickup_heart` | Heart power-up (heals) | 9x8 | — | |
| `pickup_magnet` | Soul Magnet (pulls in all gems) | 9x9 | — | |
| `pickup_bomb` | Holy Bomb (clears the screen) | 9x9 | — | |
| `pickup_frost` | Frost Hourglass (freezes enemies) | 7x9 | — | |
| `chest` | Champion's chest | 11x9 | — | |
| `crown` | Crown over a champion's head | 7x5 | — | |
| `star` | Rating star (run summary) | 7x7 | — | |

## Weapon projectiles and effects
| ID | What | Size | Notes |
|---|---|---|---|
| `scythe` | Reaper's Scythe blade | 9x9 | Spins. |
| `bone_spear` | Bone Spear | 5x13 | Points up. |
| `flame` | Hellfire Trail flame | 5x6 | `flame_1` flicker frame. |
| `cleaver` | Bone Cleaver (thrown, spins) | 9x9 | |
| `dagger` | Spirit Dagger, pointing right | 11x5 | Ghostly blue knife. |
| `dagger_diag` | Spirit Dagger, pointing up-right | 9x9 | Same dagger at 45°. |
| `bone_effigy` | Bone Effigy (lures enemies) | 10x14 | A totem of bones. |

## Icons (9x9): HUD, lists, run summary
Each icon should be readable at 9x9. Many of them also have a **16x16 `_lg` version** (next section) used on level-up cards, in the shop and in the Game Guide.

**Main weapons:** `icon_main_gun` (Bolt Gun), `icon_reapers_scythe`, `icon_chain_lightning`, `icon_bone_spears`.
**Main weapon evolutions:** `icon_storm_bolter`, `icon_harvester`, `icon_tempest`, `icon_bone_cathedral`.
**Auto weapons:** `icon_orbiting_skulls`, `icon_seeking_bolts`, `icon_holy_aura`, `icon_hellfire_trail`, `icon_storm_lantern`, `icon_bone_cleaver`, `icon_grave_spikes`, `icon_spirit_daggers`, `up_hallowed_blast` (Grave Blast), `up_deep_hex` (Hex Snare), `up_ossuary` (Bone Effigy).
**Auto weapon evolutions:** `icon_death_spiral`, `icon_soul_barrage`, `icon_sanctuary`, `icon_inferno_path`.
**Passives:** `up_sharpened_bolts` (Sharpened Edge), `up_quick_hands`, `up_fleet_foot`, `up_heart_container`, `up_grave_magnet`, `up_steady_nerves`, `up_arcane_focus`, `up_keen_edge`, `up_corpse_blast`, `up_giant_slayer`, `up_executioner`, `up_ghoul_blood`, plus `up_blood_draught` and `coin_big` (Coin Pouch).
**Main weapon level-ups:**
- Bolt Gun: `up_extra_bolt`, `up_piercing_bolts`, `up_ricochet`, `up_hunting_bolts`
- Scythe: `up_twin_scythes`, `up_long_reach`, `up_heavy_blade`, `up_grim_harvest`
- Lightning: `up_forked_lightning`, `up_long_arc`, `up_conductor`, `up_split_bolt`
- Spears: `up_longer_row`, `up_wide_spikes`, `up_quick_rise`, `up_splinters`

**Shop relics:** `rel_cursed_skull`, `rel_iron_boots`, `rel_hourglass` (Cracked Hourglass), `rel_grave_lantern`, `rel_bone_charm`, `rel_hunters_eye`, `rel_vampire_fang`, `rel_bloodstone`, `rel_holy_water`, `rel_mourners_bell`.
**Other:** `icon_ritual` (ritual circle event), `icon_ability` (old ability damage in the run summary).

## Big icons (16x16, `_lg`)
These exist today: the 4 main weapons, the 4 main evolutions, all 11 auto weapons and the 4 auto evolutions (same IDs as above plus `_lg`; Grave Blast / Hex Snare / Bone Effigy are `up_hallowed_blast_lg`, `up_deep_hex_lg`, `up_ossuary_lg`), plus `up_sharpened_bolts_lg`, `up_quick_hands_lg`, `up_fleet_foot_lg`, `up_heart_container_lg`, `up_grave_magnet_lg`, `up_steady_nerves_lg`, `up_arcane_focus_lg`, `up_keen_edge_lg`, `up_corpse_blast_lg`, `up_giant_slayer_lg`, `up_executioner_lg`, `up_ghoul_blood_lg`, `up_blood_draught_lg`, `coin_big_lg`.

**Optional:** the 16 main weapon level-ups and the 10 relics have no `_lg` version yet, so their cards show the small icon scaled up. New `_lg` versions are welcome (just add the file; the game picks it up automatically).

## Minimap markers (tiny shapes, recolored by the game)
Draw these in **pure magenta `#FF00FF` only**; the game tints them and adds the dark outline itself.

| ID | Size | Marker |
|---|---|---|
| `mm_you` | 5x5 | You |
| `mm_teammate` | 3x3 | Teammate |
| `mm_downed` | 5x5 | Downed teammate |
| `mm_boss` | 7x6 | Boss |
| `mm_champion` | 5x3 | Champion lair |
| `mm_ritual` | 5x5 | Ritual circle |
| `mm_chest` | 5x4 | Chest |
| `mm_altar` | 5x5 | Altar |
| `mm_coin` | 5x5 | Grave Robber / loot |

## Floor props (background decoration; drawn dimmed, no outline)
| ID | Size | Stage |
|---|---|---|
| `skull`, `grave`, `grave_cross`, `bones`, `skull_pile`, `candle` | 6x6, 6x6, 5x6, 5x5, 7x4, 3x5 | The Crypt |
| `reeds`, `stump` | 5x5, 6x4 | The Bone Marsh |
| `pew`, `pillar_stump`, `candelabra`, `rubble` | 14x5, 7x6, 7x6, 5x3 | The Burning Cathedral |

## Not needed
- `ghost` and `icon_quest`: still in the file, but nothing shows them.
- Icons of retired upgrades: `up_afterimage`, `up_shadow_step`, `up_glass_cannon`, `up_long_shot`, `up_reckless_haste`, `up_swift_bolts`.

## Not sprites (out of scope unless asked)
These are drawn by code, not from sprites, so swapping them needs code changes:
- **Floors and walls:** painted from each stage's colors by `FloorBaker` (stone tiles, moss, marsh water, the Cathedral's carpet aisles, candle light).
- **Bullets, rings and auras:** colored discs and circles made in code.
- **Font:** `PixelFont`, every glyph is text rows.
- **UI panels and buttons:** `src/ui/theme/game_theme.tres`.
- **Particles, death animations, hit flashes:** code-drawn.

If you want to do any of these (a tileset for the floors or a new UI frame style are the most likely), make them as a separate proposal and say what sizes you used.
