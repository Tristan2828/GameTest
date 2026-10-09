# Playtest Review (v0.14.0)

Milestones 3–5 and the polish pass were built while you were away, so **none of it has been played by a human yet.**
Automated tests prove it *works* (223 unit tests, plus online host+client runs).
Only you can judge whether it is *fun, fair, and readable*. This document is your checklist.

You don't need to do it all at once. Each section stands alone. Tick boxes as you go, jot notes,
then paste your notes back to Claude (see **Reporting back** at the end).

---

## 1. How to run things quickly

Normal play: run `builds\windows\GameTest.exe` (or the zip you send friends).

To jump straight to something, open PowerShell and run:

```powershell
$g = "C:\Repos\GameTest\builds\windows\GameTest.exe"
& $g -- --solo --start-at=230                      # Crypt boss (Bone Warden) in 10 s
& $g -- --solo --start-stage=2 --start-at=230      # Marsh boss (Mire Hag)
& $g -- --solo --start-stage=3 --start-at=230      # Cathedral boss (Ashen Bishop)
& $g -- --solo --start-stage=2                     # A full stage 2 from the start
& $g -- --solo --stage-seconds=30 --weak-bosses    # Speed-run all 3 stages + shops (tests the flow, not balance)
& $g -- --solo --give-weapons                      # Start with all 3 auto weapons at level 2
& $g -- --solo --character=1                       # Skip choosing: 0 Wanderer, 1 Gravekeeper, 2 Witch, 3 Necromancer
& $g -- --solo --run-config=single_stage=true,stage=3,bonus_levels=5   # Custom game without the lobby pages
```

Flags combine. `--start-at` and `--start-stage` skip upgrades, so jumped-to fights are **harder** than in a real run.
For balance judgments, prefer real runs.

---

## 2. Suggested sessions

| Session | Time | What |
|---|---|---|
| **A. Bosses** | ~15 min | Fight each boss with the `--start-at=230` shortcuts. Focus: can you read and dodge the patterns? |
| **B. Full solo run** | ~20 min | One real run start to finish with your favourite character. Focus: pacing, difficulty curve, shop, weapons. |
| **C. Characters** | ~15 min | 5 minutes of stage 1 with each of the 3 characters. Focus: do they feel different and fair? |
| **D. Full co-op run** | ~20 min | Real run with a friend over the internet. Focus: everything networked, plus fun together. |

Session D is the most valuable if you only have time for one.

---

## 3. Checklists

Each item has a **question** and, where relevant, **where to tune it** (so Claude can act fast on your answer).

### 3.0a Changes from the first co-op playtest (v0.14.0, check these first)
- [ ] Level-up pacing: about half as many level-ups (a 2-player team: ~14 in stage 1 instead of ~30). Does the flow feel better? Is the difficulty still right with fewer upgrades?
  - *Tune: `BASE_XP` / `XP_PER_LEVEL` in `src/progression/team_progress.gd`.*
- [ ] After you pick, your card stays lit (gold border, others dimmed) with "You chose X. Waiting for ...". Clear?
- [ ] Level pips on each card (filled = levels you have, blinking gold = this pick, hollow = left to max). Readable?
- [ ] "3, 2, 1" countdown (with beeps) after everyone picks and after the shop. Long enough? Too long?
  - *Tune: `RESUME_COUNTDOWN_SECONDS` in `src/arena/arena.gd`.*
- [ ] Weapon icons with level pips under the hearts (HUD), on the run-end cards, and floating over altars. Can you tell the three apart?
- [ ] Arrows at the screen edge point to off-screen teammates, in their color (faded for ghosts). Helpful? Distracting?
- [ ] Lobby: portraits show **your** color (a friend in Red sees red heroes), and small color squares show who picked which hero.
- [ ] Victory / Run over: "Return to character select" button (host). Works with gamepad?
- [ ] New boss arrival sound (impact + bell + horn). Audible and dramatic enough?
- [ ] Title menu: Compendium pages (Heroes, Weapons, Upgrades, Relics, Pickups, Enemies, Bosses). Useful? Anything missing or wrong?
- [ ] Lobby: Difficulty page (sliders + Easy / Normal / Hard). Do the settings feel like they do what they say? Is Hard hard?
- [ ] Lobby: Custom Game page. Try a single stage on the Bone Marsh or Cathedral, no boss, a short wave, starting level-ups, all weapons. Does the run end in Victory as expected?
- [ ] Friends see the host's settings (summary line in the lobby; pages are read-only for them).
- [ ] Title menu: this Playtest Checklist. Ticks are remembered after restarting the game? "Copy what's left" works?

### 3.0 Changes from your first playtest (v0.12.0)
- [ ] Gems: easy to spot now? Three tiers distinguishable?
- [ ] Minimap: helpful? Did you notice the red edge warning near walls?
- [ ] Text: shop, level-up cards, lobby, HUD all readable now?
- [ ] Shop: about one relic per shop now? Too stingy? (*Tune: coin_chance in enemy `.tres`, relic `price`, `BOSS_BOUNTY` in `src/arena/arena.gd`*)
- [ ] Abilities: Dash / Grave Blast / Hex Snare / Bone Effigy each feel good and different? Cooldowns right? Is the hex sigil and the effigy's lure ring readable? (*Tune: `ability_cooldown` etc. in `src/player/characters/*.tres`*)
- [ ] Version shown on the title screen.

### 3.1 Moment-to-moment feel
- [ ] Does movement still feel instant and smooth (it did in M1/M2)?
- [ ] Shooting: does the main gun feel good? Too weak or strong early on?
- [ ] Abilities (Space / LT): see 3.0.
- [ ] **New:** screen shake (hurt, Grave Blast, boss death). Too much, too little, or annoying? *(Can be turned off in Settings)*
- [ ] **New:** hit sparks, death puffs, red flash when hurt. Helpful or noisy?
- [ ] **New:** music. Menu/shop theme, one track per stage, boss theme. Does each fit its stage? Gets repetitive (loops are 14–27 s)? Too loud vs effects? *(Music volume in Settings)*
  - *Tune: scores are text in `src/audio/tracks.gd` (tempo, chords, melody, drums).*
- [ ] **New:** sound effects (synthesized, now with filtering/echo). Any sound too loud, grating, or missing?
  - Shots, hits, enemy deaths, gems, coins, level-up, bomb, boss roar, dash, victory/defeat jingles.
  - *Tune: `src/autoload/sfx.gd` (each sound is one line) and the `Sfx.play(...)` volumes.*

### 3.2 Bullet patterns and dodging (the core pillar)
- [ ] Are enemy bullets easy to **see** against each floor (Crypt purple, Marsh green, Cathedral red)?
- [ ] Is the tiny hitbox clear? Do hits ever feel unfair ("that didn't touch me")?
- [ ] Cultists (stage 1, from 2:00): slow 3-bullet fans. Annoying or interesting?
- [ ] Plague Spitters (stage 2): slow 8-bullet rings. Readable?
- [ ] Fallen Paladins (stage 3): aimed lines of 5 bullets. Readable?
- [ ] Online (session D): does dodging feel fair as the *client*? (Enemy bullets are shifted forward by your ping.)
  - *Tune: patterns in `src/combat/shot_patterns.gd`; who fires them in `src/enemies/types/*.tres`.*

### 3.3 Bosses
For each boss: Can you learn the pattern? Does phase 2 (below half HP) feel like an escalation? How long did it take?

| Boss | Attacks | Fight length felt | Notes |
|---|---|---|---|
| Bone Warden (Crypt) | rings, spiral, aimed fans; phase 2: faster, double spiral | | |
| Mire Hag (Marsh) | sweeping walls with a gap, random sprays, rings; phase 2: faster walls, double spiral | | |
| Ashen Bishop (Cathedral) | rotating cross, 3-wave burst, aimed fans; phase 2: faster cross, rings, double spiral | | |

- [ ] Boss HP: 6000 base, ×1.5 in stage 2, ×2 in stage 3, +75% per extra player. Too spongy? Too quick?
- [ ] Do the bosses *look* distinct enough (horns / witch hat / mitre)?
  - *Tune: boss HP in `src/enemies/types/*.tres`; attack scripts in `src/stages/*.tres` (`boss_phase_one/two`).*

### 3.4 Difficulty and pacing (full runs)
- [ ] Stage length: 4:00 of horde, then the boss. Too long / short?
- [ ] Difficulty curve inside a stage: too flat, or a sudden wall?
- [ ] Stage 2 and 3 difficulty jump (+35% spawn rate, +50% enemy HP per stage). Fair with your upgrades?
- [ ] Pack surges (a clump from one direction every 35–50 s). Exciting or cheap?
- [ ] Did you ever feel bored? Overwhelmed? When?
- [ ] Total run length (~17–20 min including shops). Right?
  - *Tune: `WAVE_DURATION`, `STAGE_SPAWN_RATE_GROWTH`, `STAGE_HP_GROWTH` in `src/arena/arena.gd`;
    spawn rate in `src/arena/spawn_director.gd`; enemy mixes in `src/stages/*.tres`.*

### 3.5 Characters (lobby)
- [ ] Lobby: easy to pick and ready up (mouse **and** gamepad)?

| Character | Feels distinct? | Too strong / weak? | Ability noticeable? |
|---|---|---|---|
| Wanderer (Dash) | | | |
| Gravekeeper (shotgun, 5 hearts, Grave Blast) | | | |
| Hexblade Witch (fast, 2 hearts, piercing hexes, Hex Snare) | | | |
| Necromancer (3 hearts, bone-shard fan, Bone Effigy decoy) | | | |

- [ ] Gravekeeper's shotgun range (short). Fun or frustrating?
- [ ] Witch with 2 hearts. Too fragile?
  - *Tune: `src/player/characters/*.tres`.*

### 3.6 Level-ups and upgrades
- [ ] How often do level-ups pause the game? Too often in co-op? (Rebalanced in v0.14.0, see 3.0a.)
- [ ] Level-up cards show level pips and your real stat before -> after (e.g. "Damage 13 -> 16"). Useful, and are the numbers right after a few picks and relics?
- [ ] Run over / Victory screen: headline (what killed you, which stage), run totals, a card per player with stats, build and co-op awards. Readable? Any stat you miss?
- [ ] Are the 9 upgrades meaningfully different? Any always/never picked?
- [ ] 30-second countdown after the first pick: right length?
  - *Tune: XP curve in `src/progression/team_progress.gd`; upgrades in `src/progression/upgrades/*.tres`.*

### 3.7 Coins, shop and relics
- [ ] Coin income: could you afford 1–2 relics per shop? (Boss bounty 20 / 30 / 40 coins + drops.)
- [ ] Relic prices (15–30) and reroll price (5). Right?
- [ ] Any relic clearly best / useless? (Cursed Skull, Iron Boots, Cracked Hourglass, Grave Lantern, Bone Charm,
      Hunter's Eye, Vampire Fang, Holy Water)
- [ ] Shop flow: clear what to do? 45 s countdown after first Ready OK?
  - *Tune: `src/progression/relics/*.tres`, `BOSS_BOUNTY` in `src/arena/arena.gd`, coin drop chances in enemy `.tres`.*

### 3.8 Auto weapons and altars
- [ ] Did you notice the altars (glowing pedestals at ~1:20 and ~2:40)? Worth walking to?
- [ ] Orbiting Skulls / Seeking Bolts / Holy Aura: any too strong or useless? Is max level 3 enough?
- [ ] Do weapons make the screen too busy to read enemy bullets?
  - *Tune: `src/combat/weapons/*.tres`, `ALTAR_TIMES` in `src/combat/weapon_system.gd`.*

### 3.9 Grave Blast (Gravekeeper)
- [ ] Clear radius big enough to save you? Damage noticeable? 14 s cooldown fair?
  - *Tune: `blast_*` and `ability_cooldown` in `src/player/characters/gravekeeper.tres`.*

### 3.10 Ghosts and co-op (session D)
- [ ] Being a ghost: fun enough to stay engaged until the next stage? Too long a wait?
- [ ] Shared XP + individual picks: does it feel good together?
- [ ] Coins first-come-first-served: fair, or does one player hog them?
- [ ] Any desync weirdness (rubber-banding, enemies jumping, bullets that hit you but didn't look like it)?
- [ ] Ping shown on the client HUD: what was it?

### 3.11 Menus and UI
- [ ] **New:** Esc / Start opens the pause menu (it used to instantly leave!). Solo actually pauses.
- [ ] **New:** Settings (volume, fullscreen, screen shake). Do they work and stick after restarting?
- [ ] **New:** End-of-run stats table. Interesting?
- [ ] **New:** menu style (dark panels, gold focus ring for gamepad, crisp pixel text, crypt backdrop on the title screen). Readable? Fits the game?
- [ ] **Changed:** the aim line on your character is gone (sprites face your aim instead). Do you miss knowing exactly where you aim?
- [ ] HUD readable at your screen size? Anything you look for and can't find?
- [ ] Is the controls hint at the bottom still useful, or clutter?

### 3.12 Looks
- [ ] **New:** pixel-art sprites for every character, enemy and boss. Do they read well at a glance in a crowd?
- [ ] Can you always tell the enemy types apart? The bosses?
- [ ] Your character in your player color: easy to find yourself? Is the white hitbox dot clear?
- [ ] **New:** animations (walk cycles, enemy attack poses when they fire, death squash-and-fade, spinning coins). Readable and satisfying, or distracting?
- [ ] **Fixed:** sprites facing left used to be drawn off-center. Do enemies now get hit exactly where they look?
- [ ] Any sprite you'd like redrawn (too small, wrong vibe, ugly)? *(Sprites are text grids in `src/art/pixel_art.gd`; easy to change.)*
- [ ] **New:** pixel-art floors (Crypt slabs, Marsh mud and puddles, Cathedral marble and carpet) with props. Atmospheric? Too busy or too dark to read bullets?

---

## 4. Decisions Claude made for you (revisit)

All of these are recorded in `DESIGN.md` with "Revisit in the next playtest". In one place:

- **Stage flow:** 4:00 horde then boss; horde at 40% during the boss; stage clear = boss dead.
- **Run:** 3 stages, each harder; Victory after stage 3; the host returns everyone to character select (button, or R / Select).
- **Boss HP** scales with players (+75% each); regular enemies don't (more of them instead).
- **Ghosts** collect gems/coins; respawn next stage.
- **Coins** go to whoever picks them up; the boss bounty is paid to everyone.
- **Shop:** 4 personal offers, 5-coin reroll, 45 s after first Ready.
- **Relics** are one-of-a-kind per player; some have drawbacks.
- **Altars:** two per stage, first touch takes it; maxed weapon = 15 coins.
- **Abilities:** one per character on a cooldown (Dash / Grave Blast / Hex Snare / Bone Effigy), replacing dash and bombs.
- **Characters / abilities**, as listed in 3.5.
- **Mid-run joiners** play the Wanderer.
- **Sound** is synthesized placeholder; no music yet.

---

## 5. Known limitations (not bugs)
- All audio is synthesized (chiptune style); no recorded sounds or composed soundtrack.
- Sprites and floors are drawn by Claude as text grids/code (little animation: bats, imps, walk bob); effects and UI are simple code drawing.
- Enemy bullets already on screen aren't sent to a friend who joins mid-fight (new ones are).
- Joining mid-run always gives the Wanderer.
- The autopilot used in automated tests can't dodge, so it can't tell us anything about balance.

---

## 6. Reporting back

Paste something like this to Claude. Rough notes are fine:

```
Session: B (full solo run, Gravekeeper)   Result: died in stage 3 at ~2:00
Felt great: ...
Felt bad / unfair: ...
Too easy / too hard: ...
Bugs (what happened, roughly when): ...
Ideas: ...
```

Claude will turn it into tuning changes, fixes, and DESIGN.md updates.
