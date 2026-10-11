# Playtest Review (v0.25.0)

Most of the game was built between playtests: you've played M1 and M2, a solo run, co-op runs of v0.13 and v0.14 and a 4-player run of v0.23.0, but each new version adds things nobody has played yet.
Automated tests prove it *works* (unit tests, plus online host+client runs).
Only you can judge whether it is *fun, fair, and readable*. This document is your checklist.

You don't need to do it all at once. Each section stands alone. Tick boxes as you go, jot notes,
then paste your notes back to Claude (see **Reporting back** at the end).

---

## 1. How to run things quickly

Normal play: run `builds\windows\MedievalSurvival.exe` (or the zip you send friends).

To jump straight to something, open PowerShell and run:

```powershell
$g = "C:\Repos\GameTest\builds\windows\MedievalSurvival.exe"
& $g -- --solo --start-at=230                      # Crypt boss (Bone Warden) in 10 s
& $g -- --solo --start-stage=2 --start-at=230      # Marsh boss (Mire Hag)
& $g -- --solo --start-stage=3 --start-at=230      # Cathedral boss (Ashen Bishop)
& $g -- --solo --start-stage=2                     # A full stage 2 from the start
& $g -- --solo --stage-seconds=30 --weak-bosses    # Speed-run all 3 stages + shops (flow and quests, not balance)
& $g -- --solo --give-weapons                      # Start with 5 random auto weapons at level 3
& $g -- --solo --character=1                       # Skip choosing (ignores unlocks): 0 Kael, 1 Mortimer, 2 Morwen, 3 Vesper
& $g -- --solo --run-config=single_stage=true,stage=3,bonus_levels=5   # Custom game without the lobby pages
& $g -- --solo --run-config=soundtrack=1           # Metal soundtrack (2 = metal boss fights only, 3 = shuffle)
& $g -- --solo --start-at=65                       # Map events: the first Grave Robber pops up at 1:10
```

Flags combine. `--start-at` and `--start-stage` skip level-ups, so jumped-to fights are **harder** than in a real run.
For balance judgments, prefer real runs.

---

## 2. Suggested sessions

| Session | Time | What |
|---|---|---|
| **A. Bosses** | ~15 min | Fight each boss with the `--start-at=230` shortcuts. Focus: can you read and dodge the patterns? |
| **B. Full solo run** | ~20 min | One real run start to finish. Focus: pacing, difficulty curve, shop, weapons. |
| **C. Characters** | ~15 min | 5 minutes of stage 1 with each of the 4 heroes. Focus: do they feel different and fair? |
| **D. Full co-op run** | ~20 min | Real run with friends over the internet. Focus: everything networked, plus fun together. |

Session D is the most valuable if you only have time for one.

---

## 3. Checklists

Each item has a **question** and, where relevant, **where to tune it** (so Claude can act fast on your answer).

### 3.0p v0.25.1 (behind-the-scenes cleanup, then 3.0o and 3.0n)
- [ ] Everything should play exactly like v0.25.0 (a lot of code moved). Do these still work and show for everyone: chests, rituals, champions and the Grave Robber, quests, power-ups, Grave Blast / Hex Snare / Bone Effigy, Corpse Blast?
- [ ] The end-of-run screen: do all four pages (Overview, Weapons, Stages, Highlights) look right, with the boss trophies, MVP crown and confetti?
- [ ] Arcane Focus and Holy Water cards now say they also make Hex Snare and Bone Effigy last longer. Clear?

### 3.0o Your eighth list (v0.25.0, check these first)
- [ ] Heroes unlock now: a fresh PC has only Kael. Win a full run as Kael to unlock Mortimer, then Morwen, then Vesper. Locked heroes are dark in the picker and say what unlocks them. Does it feel rewarding, or too slow?
  - *Tune: `HeroUnlocks.run_counts` in `src/progression/hero_unlocks.gd` (what counts as a win).*
- [ ] After a win, does the run summary show "NEW HERO: ..." on your card, and is the hero open in the lobby next time?
- [ ] Update button: does it work for everyone now (the repo rename broke it)? If it can't check, it says so and offers Check again.
- [ ] Hellfire Trail: muted enough? Still easy to see where it burns?
  - *Tune: the flame colors in `WeaponSystem._draw` (`src/combat/weapon_system.gd`).*
- [ ] An opened chest disappears right away now, for the host too.
- [ ] New hero sprites (drawn as image files now). Do they read well in a crowd and fit the game?

### 3.0n Your seventh list, after the 4-player run (v0.24.0)
- [ ] Boss fights: when the boss arrives the old horde crumbles away and the boss brings its own (12 enemies, +6 per extra player). After that the horde trickles in at 25% (was 40%) and stops growing, with at most 65 / 90 / 115 / 140 regular enemies alive (1-4 players). Can you get to the boss now? Still enough horde?
  - *Tune: `BOSS_FIGHT_SPAWN_RATE`, `BOSS_FIGHT_MAX_ALIVE`, `BOSS_FIGHT_MAX_ALIVE_PER_PLAYER`, `BOSS_ESCORT`, `BOSS_ESCORT_PER_EXTRA_PLAYER` in `src/arena/arena.gd`.*
- [ ] Ritual circle: fills 50% faster for each extra player inside (two players 10 s, four 6 s), with "x1.5" / "x2" over the circle. Right speed?
  - *Tune: `RITUAL_EXTRA_PLAYER_SPEED` in `src/arena/map_events.gd`.*
- [ ] Spirit Daggers fly as little knives now. Readable?
- [ ] During the "3, 2, 1" after a level-up or the shop, your hero gets a ring and a bouncing "YOU" arrow (below you when you're at the top of the screen). Easy to find yourself? Gone as soon as play resumes?
- [ ] New level-up card icons (bigger, in a frame: gold = weapon, blue = passive, green = evolution). Better? Any that don't read as what they are?
  - *Edit: the `*_lg` sprites at the end of `SPRITES` in `src/art/pixel_art.gd`.*
- [ ] Cards grow to fit their text (all three the same height). Any text still spilling past a border?
- [ ] After picking, click (or A / left trigger) another card to change your mind while others are still choosing. Works for you and your friends?
- [ ] Gamepad: the left trigger picks the focused card, like A (left stick to choose, left trigger to pick, one hand).
- [ ] Run summary: four cards side by side with nothing cut off (the Embers line wraps). Does it look better? The new parts: the difficulty and every setting under the headline, each stage's time under its boss trophy, a big score per player, Weapons / Passives / Relics rows, and a new **Stages** page (time, boss fight, kills, damage taken, downs, level, events and the most enemies at once, per stage). Anything else you'd like on it?
- [ ] Party page: each card shows the hero's weapon (icon + name) and their perk's name, but not the perk's description. Right amount of info?
- [ ] No controls line at the bottom of the screen during play (the host still sees the invite line online). Miss it?
- [ ] Title menu: **Join Game** opens a small window to paste the invite (Paste button, or it's filled in for you if the clipboard has one). Clearer?
- [ ] The game is called **Medieval Survival** now (title screen, window, the exe's details, and from v0.25.0 the exe and zip). Everyone on v0.24.0 or older downloads v0.25.0 once by hand; does updating work from there on?
- [ ] Difficulty page: the preset you're on is lit, a **Custom** chip lights when the sliders match no preset, a line lists what differs from Normal, and those sliders turn gold with Normal's value beside them. Reopening the page no longer jumps to Easy. Clear?
- [ ] Code review fixes: while you're downed, coins and power-ups wait for someone standing (XP gems still come to you); Bone Cleaver throws at the nearest enemy; a friend who joins mid-run keeps their Ember boosts; an altar with nothing left to give says so (10 coins). Anything odd?

### 3.0k Auto-fire redesign, step 1 (v0.22.0)
- [ ] You only move now: every main weapon fires by itself. Does it feel good, or do you miss aiming? Is the game more about dodging, like you wanted?
- [ ] Targeting: Kael's bolts hit the closest enemy, Morwen's lightning and Vesper's spears pick a random enemy near you, Mortimer's scythes fly the way you last moved **and** behind you. Does each rule feel fair and readable?
  - *Tune: `src/player/auto_aim.gd` (rules and reach); the back throw is `SCYTHE_BACK_THROW` in `src/combat/main_weapons.gd`.*
- [ ] Mortimer's scythe also throws behind him (Claude's call: with only the front throw, running away from a crowd meant facing away from it, and his boss fights took 4+ minutes). Keep it, or front only?
- [ ] HP bar instead of hearts (top-left, and a small bar under every hero). Kael 100, Morwen 70, Vesper 90, Mortimer 150. Readable? Right amounts?
- [ ] Touching enemies drains a little every half second (Shambler 5, Ghoul 8, bosses 15), with no safe time: getting surrounded is deadly. Bullets hit harder (15, bosses 20, champions 18) and then you're safe from bullets for 0.5 s. Later stages hit 30% / 60% harder. Fair? Too harsh / too soft?
  - *Tune: `contact_damage` / `bullet_damage` in `src/enemies/types/*.tres`, `DAMAGE_BY_DEPTH` in `src/arena/arena.gd`, `max_hp` / `hit_invulnerability` in `src/player/characters/*.tres`, `CONTACT_INTERVAL` in `src/player/player_health.gd`.*
- [ ] Healing: Heart pickup 30% of max HP, every level-up 5%, a finished ritual 25%, full HP each stage, Ghoul Blood (upgrade, +0.4 HP/s) and Bloodstone (relic, +1 HP/s). Too much healing, too little?
  - *Tune: `HEART_HEAL_SHARE` in `src/progression/power_ups.gd`, `LEVEL_UP_HEAL_SHARE` in `src/arena/arena.gd`, `RITUAL_HEAL_SHARE` in `src/arena/arena_rewards.gd`.*
- [ ] No more ability button. Grave Blast, Hex Snare and Bone Effigy are auto weapons anyone can find on altars and in chests; they go off by themselves (Grave Blast when enemies get close, the other two at the biggest crowd near you). Do they feel useful? Dash is gone.
  - *Tune: `src/combat/weapons/grave_blast.tres`, `hex_snare.tres`, `bone_effigy.tres`; crowd rules and `BLAST_WAKE_FACTOR` / `BLAST_HEAL_SHARE` in `src/combat/auto_weapons.gd`.*
- [ ] Hero perks instead of abilities: Kael moves 10% faster, Mortimer regenerates 0.5 HP/s, Morwen +10% crit chance, Vesper's kills burst for 8 damage. Do heroes still feel different enough?
- [ ] The mouse cursor hides while you play and comes back for level-up cards, the shop and the pause menu. Any moment it's missing when you need it?
- [ ] What used to boost abilities now boosts auto weapons: Cracked Hourglass (recharge faster), Arcane Focus and Holy Water (more damage; they also make Hex Snare and Bone Effigy last longer), and the Ember Shrine's Focus. Noticeable?

### 3.0m Build rework: weapons and passives on level-up cards (v0.23.0)
- [ ] Level-up cards now offer new weapons, weapon levels (your hero's main weapon too) and passives. Is picking a build fun? Do you know what each card does from its text and numbers?
  - *Tune: card weights `NEW_WEIGHT` / `LEVEL_WEIGHT` / `MAIN_LEVEL_WEIGHT` in `src/progression/cards.gd`.*
- [ ] 6 weapon slots (your main weapon is one) and 6 passive slots. Did you fill them? Too few, too many?
  - *Tune: `WEAPON_SLOTS` in `src/combat/auto_weapons.gd`, `PASSIVE_SLOTS` in `src/progression/upgrades.gd`.*
- [ ] Main weapon levels (2-6): the old hero upgrades come one per level (e.g. Kael: Extra Bolt, Piercing, Ricochet...). Does your hero's weapon feel like it grows?
  - *Tune: `main_levels` in `src/player/characters/*.tres`.*
- [ ] Evolutions: max a weapon, carry its passive, then open a champion's chest or beat a boss (Game Guide > Evolutions). Did you get one? Worth chasing? Clear what you need?
  - *Tune: `src/combat/weapons/death_spiral.tres` etc., `src/player/evolutions/*.tres`.*
- [ ] New weapons: Storm Lantern, Bone Cleaver, Grave Spikes, Spirit Daggers (they fly ahead of you and behind). Any useless or too strong?
- [ ] HUD: under the HP bar, your weapons (main first, pips = level, green bar = evolved) and your passives below. Readable?
- [ ] Card rerolls: you start with 1, the shop sells more (15 coins). Did you use them? Worth the price?
  - *Tune: `START_REROLLS` in `src/progression/cards.gd`, `CARD_REROLL_PRICE` in `src/progression/shop_session.gd`.*
- [ ] Altars now give the weapon shown (or a level of it), else a level of a weapon you carry. Still worth walking to?

### 3.0l Balance pass: upgrades, pickups, events (v0.22.1, Claude, measured with the autopilot only)
- [ ] Sharpened Edge is now a share of your hero's own damage for **all** your weapons (+20% per level since v0.23.0; Cursed Skull +30%) instead of a flat +4, which was worth +40% to Kael but +13% to Mortimer. Does every hero still feel their damage grow? Is it still the pick you always want?
  - *Tune: `amount` in `src/progression/upgrades/sharpened_bolts.tres`, `src/progression/relics/cursed_skull.tres` (stat 36 = share of starting damage).*
- [ ] Auto weapons hit much harder (Holy Aura, Orbiting Skulls, Hellfire, Seeking Bolts, Grave Blast and Bone Effigy got 30-80% more damage, the first three also more size) and grow x1.5 / x2.25 stronger in stages 2 and 3 (v0.23.0; with 5 weapon levels). Before, all of them together did under 5% of the damage. Now worth finding? Is any one of them still useless, or too strong?
  - *Tune: `src/combat/weapons/*.tres`, `AUTO_DAMAGE_BY_DEPTH` in `src/arena/arena.gd`.*
- [ ] Morwen's lightning goes for the boss half the time when one is in reach, and a jump with nobody new to reach strikes the last enemy again at 60% damage (her boss fights took 1.5-3.5 minutes, mostly zapping the adds). Boss fights fair for her now? Does the lightning still feel random enough?
  - *Tune: `BOSS_FOCUS_SHARE` in `src/player/auto_aim.gd`, `GROUNDED_SHARE` in `src/combat/main_weapons.gd`.*
- [ ] Corpse Blast 12 -> 10 per pick (it did up to a third of all damage). Still feels good?
- [ ] Fewer coins from enemies (75% in stage 1, 25% in stages 2-3; events and bosses unchanged) and relics cost ~30% more: the autopilot ended runs with 500-1000 coins and every relic. Now you should afford 2-3 relics per shop and have to choose. Too stingy?
  - *Tune: `COIN_DROP_BY_DEPTH` in `src/arena/arena.gd`, `price` in `src/progression/relics/*.tres`.*
- [ ] Power-ups are rarer (1% of kills, at most one per 18 s: about 6-9 per stage instead of 10-20; Holy Bomb 15% of drops, Heart 40%). Still exciting when one drops? Do you miss the Hearts?
  - *Tune: `DROP_CHANCE`, `DROP_COOLDOWN`, `WEIGHTS` in `src/progression/power_ups.gd`.*
- [ ] Rituals give 1.5 levels of XP (was 0.6: less than standing still and fighting for 15 s). Worth the stand now?
- [ ] Co-op: more altars (2 players: 2 per wave, 4 players: 3, each near a different player), so everyone finds weapons.
- [ ] Quests got harder where they had become trivial: Slayer 1000 kills, Gold Digger 80 coins, Arsenal 12000 auto weapon damage; Untouchable is 45 s now (60 s with touch damage that never pauses was nearly impossible). Any still too easy or too hard?

### 3.0j Embers and the Ember Shrine (v0.21.0)
- [ ] Finish a run: the run summary says "+N Embers". Title menu > **Ember Shrine**: buy a boost, see the rank pips fill. Clear? Works with mouse and gamepad?
- [ ] Earning pace: about 40 for a victory and about 15 for dying in stage 2; everything costs about 1950 (around 100 runs). Feels rewarding enough, or too slow?
  - *Tune: `PER_BOSS`, `PER_VICTORY`, `KILLS_PER_EMBER`, `PRICES` and the per-rank amounts in `src/progression/embers.gd`.*
- [ ] Boosts feel small but noticeable (a maxed hero is only a few percent stronger)? Any boost useless or missing?
- [ ] **My boosts: Off** and **Refund all** work? Host: Custom Game > **Ember boosts Off** turns everyone's off (the lobby summary says "no Ember boosts")?
- [ ] Co-op: a friend's boosts work for them (e.g. Swiftness makes only them faster, with no rubber-banding)?

### 3.1 Moment-to-moment feel
- [ ] Does movement still feel instant and smooth (it did in M1/M2)?
- [ ] Your main weapon (fires by itself): does it feel good? Too weak or strong early on?
- [ ] Screen shake (hurt, Grave Blast, boss death). Too much, too little, or annoying? *(Can be turned off in Settings)*
- [ ] Hit sparks, death puffs, red flash when hurt. Helpful or noisy?

### 3.2 Bullet patterns and dodging (the core pillar)
- [ ] Are enemy bullets easy to **see** against each floor (Crypt purple, Marsh green, Cathedral red)?
- [ ] Is the tiny hitbox clear? Do hits ever feel unfair ("that didn't touch me")?
- [ ] Cultists (stage 1, from 2:00): slow 3-bullet fans. Annoying or interesting?
- [ ] Plague Spitters (stage 2): slow 8-bullet rings. Readable?
- [ ] Fallen Paladins (stage 3): aimed lines of 5 bullets. Readable?
- [ ] Online (session D): does dodging feel fair as the *client*? (Enemy bullets are shifted forward by your ping.)
- [ ] Frost Hourglass freezes enemy bullets in the air (they still hurt). Readable, or confusing?
  - *Tune: patterns in `src/combat/shot_patterns.gd`; who fires them in `src/enemies/types/*.tres`.*

### 3.3 Bosses
For each boss: Can you learn the pattern? Does phase 2 (below half HP) feel like an escalation? How long did it take?

| Boss | Attacks | Fight length felt | Notes |
|---|---|---|---|
| Bone Warden (Crypt) | rings, spiral, aimed fans; phase 2: faster, double spiral | | |
| Mire Hag (Marsh) | sweeping walls with a gap, random sprays, rings; phase 2: faster walls, double spiral | | |
| Ashen Bishop (Cathedral) | rotating cross, 3-wave burst, aimed fans; phase 2: faster cross, rings, double spiral | | |

- [ ] Boss HP: 6000 base, ×4.5 in stage 2, ×12 in stage 3 (since v0.18.0), +75% per extra player. Too spongy? Too quick?
- [ ] Do the bosses *look* distinct enough (horns / witch hat / mitre)?
  - *Tune: boss HP in `src/enemies/types/*.tres`; attack scripts in `src/stages/*.tres` (`boss_phase_one/two`).*

### 3.4 Difficulty and pacing (full runs)
- [ ] Stage length: 4:00 of horde, then the boss. Too long / short?
- [ ] Difficulty curve inside a stage: too flat, or a sudden wall?
- [ ] Stage 2 and 3 difficulty jump (enemy HP x4 / x9, spawns x1.4 / x1.8, enemies hit x1.3 / x1.6). Fair with your build?
- [ ] Pack surges (a clump from one direction every 35–50 s). Exciting or cheap?
- [ ] Did you ever feel bored? Overwhelmed? When?
- [ ] Total run length (~17–20 min including shops). Right?
- [ ] Lobby: Difficulty page (sliders + Easy / Normal / Hard). Do the settings feel like they do what they say? Is Hard hard?
- [ ] Lobby: Custom Game page. Try a single stage on the Bone Marsh or Cathedral, no boss, a short wave, starting level-ups, Full arsenal. Does the run end in Victory as expected?
  - *Tune: `WAVE_DURATION`, `SPAWN_RATE_BY_DEPTH`, `ENEMY_HP_BY_DEPTH`, `BOSS_HP_BY_DEPTH`, `DAMAGE_BY_DEPTH`, `RAMP_HEAD_START_BY_DEPTH` in `src/arena/arena.gd`;
    spawn rate in `src/arena/spawn_director.gd`; enemy mixes in `src/stages/*.tres`; late levels: `LATE_LEVEL`, `LATE_XP_SQUARED` in `src/progression/team_progress.gd`.*

### 3.5 Heroes (lobby)
- [ ] Lobby: easy to pick and ready up (mouse **and** gamepad)?
- [ ] Lobby: the main page shows the whole party (one card per player, hero walking on the spot, ready state). Your card (or **Choose Hero**) opens the hero picker; picking goes straight back. Works with mouse and gamepad?

| Character | Feels distinct? | Too strong / weak? | Perk noticeable? |
|---|---|---|---|
| Kael the Wanderer (Bolt Gun, 100 HP, moves 10% faster) | | | |
| Mortimer the Gravekeeper (Reaper's Scythe, 150 HP, regenerates) | | | |
| Morwen the Hexblade Witch (fast, 70 HP, Chain Lightning, +10% crit) | | | |
| Vesper the Necromancer (90 HP, Bone Spears, kills burst) | | | |

- [ ] Heroes have names: Kael (Wanderer), Mortimer (Gravekeeper), Morwen (Hexblade Witch), Vesper (Necromancer). Do they fit? Want different ones?
- [ ] In Choose Hero, press **Watch** under a hero: a looping demo shows their main weapon, then a dodge. Does it explain the hero well? Anything missing or confusing?
- [ ] The demo's **Pick** button picks that hero; Back / Esc / B closes it. Works with a gamepad?
- [ ] Gravekeeper's scythe range (short). Fun or frustrating?
- [ ] Necromancer: **Bone Spears** rise in a row toward a random nearby enemy after a short warning. Satisfying, or does the delay feel laggy?
- [ ] Wanderer: still the Bolt Gun. Does the Wanderer feel boring next to the others?
- [ ] Witch with 70 HP. Too fragile?
- [ ] Online: your scythe / lightning / spears show up instantly for you, and your friends see them too.
  - *Tune: `src/player/characters/*.tres` (max_hp, fire_interval, bullet_damage, weapon_reach / weapon_radius / weapon_duration, `hero_name`), `src/combat/main_weapons.gd`; the demo in `src/lobby/hero_demo.gd`.*

### 3.6 Level-ups and passives
- [ ] How often do level-ups pause the game? Too often in co-op?
- [ ] Level-up cards show level pips and your real stat before -> after (e.g. "Damage 13 -> 16"). Useful, and are the numbers right after a few picks and relics?
- [ ] Are the 12 passives and the main weapon levels meaningfully different? Any always/never picked?
- [ ] With 12 passives and 11 weapons on the cards, do you find a build you like, or does it feel too random?
- [ ] Keen Edge: gold sparks on critical hits, visible but not too noisy?
- [ ] Corpse Blast: green bursts where your kills die. Too strong with a crowd, or too weak? Still smooth with lots of kills in co-op?
- [ ] Ricochet and Hunting Bolts (Kael's Bolt Gun levels): bolts bounce / curve toward enemies. Fun, and does it look right on a client?
- [ ] 30-second countdown after the first pick: right length?
- [ ] "3, 2, 1" countdown (with beeps) after everyone picks and after the shop (co-op only since v0.18.0). Long enough? Too long?
  - *Tune: XP curve `BASE_XP` / `XP_PER_LEVEL` / `TEAM_COST_PER_EXTRA_PLAYER` in `src/progression/team_progress.gd`; passives in `src/progression/upgrades/*.tres`; crit / boss / wounded math in `src/combat/hit_bonus.gd`; `KILL_BURST_RADIUS` in `src/arena/arena_abilities.gd`, `RESUME_COUNTDOWN_SECONDS` in `src/arena/arena.gd`; `RICOCHET_RANGE` / `HOMING_RANGE` in `src/combat/projectile_manager.gd`.*

### 3.7 Coins, shop and relics
- [ ] Coin income: could you afford 2–3 relics per shop? (Boss bounty 25 / 40 / 55 coins + drops and events.)
- [ ] Relic prices (45–100), relic reroll (10, then +10 each) and card rerolls (15). Right?
- [ ] Any relic clearly best / useless? (Cursed Skull, Iron Boots, Cracked Hourglass, Grave Lantern, Bone Charm,
      Hunter's Eye, Vampire Fang, Holy Water, Mourner's Bell, Bloodstone)
- [ ] Trade-offs are in the shop now (Cursed Skull, Iron Boots): tempting, or never worth it?
- [ ] Shop flow: clear what to do? 45 s countdown after first Ready OK?
  - *Tune: `src/progression/relics/*.tres`, `BOSS_BOUNTY` in `src/arena/arena.gd`, coin drop chances in enemy `.tres`.*

### 3.8 Auto weapons and altars
- [ ] Did you notice the altars (glowing pedestals at ~1:20 and ~2:40)? Worth walking to?
- [ ] Orbiting Skulls / Seeking Bolts / Holy Aura / Hellfire Trail / Grave Blast / Hex Snare / Bone Effigy / Storm Lantern / Bone Cleaver / Grave Spikes / Spirit Daggers: any too strong or useless? Is max level 5 right?
- [ ] Do weapons make the screen too busy to read enemy bullets?
  - *Tune: `src/combat/weapons/*.tres`, `ALTAR_TIMES` in `src/combat/weapon_system.gd`.*

### 3.9 Map events, quests and pickups
- [ ] Champion lair: a dark crowned statue on a red ring somewhere on the map. It wakes when you get close. Fun to hunt down? Too tough or too easy?
- [ ] Champion's chest: the first player to touch it gets an auto weapon (or a level). Worth the detour?
- [ ] Ritual circle: standing in it calls waves; when the gold ring is full everyone inside heals and XP gems drop. Is 15 s the right length? Too dangerous or too safe?
- [ ] Grave Robber: runs away dropping coins; catch it within 20 s. Catchable with every hero? Fun to chase?
- [ ] Toasts under the timer ("The Ghoul Champion awakens!") readable, not spammy?
- [ ] Quests: in the shop, pick 1 of 3 for the next stage. Clear what to do (HUD line under your weapons)? Rewards worth it? Any quest that's too hard or too easy?
- [ ] Pickups: Heart, Soul Magnet, Holy Bomb, Frost Hourglass. Rare enough to be exciting, common enough to matter?
  - *Tune: event numbers at the top of `src/arena/map_events.gd` (wake radius, ritual length, thief time, pop-up times) and `src/arena/arena_rewards.gd` (champion / thief coins, ritual XP share, wave size); champions in `src/enemies/types/*_champion.tres`; quests in `src/progression/quests.gd` (targets, rewards); pickups in `src/progression/power_ups.gd` (drop chance, cooldown, bomb damage, freeze time).*

### 3.10 Co-op (session D)
- [ ] Co-op revives: at 0 HP you're downed in a circle; a teammate standing in it brings you back in 4 s with half your HP. Is 4 s right? Is the circle easy to find and stand in?
  - *Tune: `RADIUS`, `SECONDS`, `HP_SHARE`, `DRAIN_PER_SECOND` in `src/player/revive.gd`.*
- [ ] Being downed: do revives happen often enough, or do you still end up waiting for the next stage?
- [ ] While you're down, your screen follows a teammate after a moment (Space / A switches who). Better than watching your body? Did the arrow back to your own body help?
- [ ] Teammates' arrows pulse with a green "+" when they're down, and "Red is down!" / "Reviving Red... 40%" shows near the bottom. Noticeable in a fight?
- [ ] Mourner's Bell relic (co-op only): revive twice as fast. Worth buying?
- [ ] Arrows at the screen edge point to downed teammates (pulsing, with a "+") and map events; healthy teammates are on the minimap (since v0.18.0). Helpful? Distracting?
- [ ] Title menu: type **Your name**. It shows on your lobby card, over your hero for friends, on their edge arrows, in "Waiting for..." lines and on the run summary. Friends see it too?
- [ ] Friends see the host's settings (summary line in the lobby; pages are read-only for them).
- [ ] Shared XP + individual picks: does it feel good together?
- [ ] Coins first-come-first-served: fair, or does one player hog them?
- [ ] Any desync weirdness (rubber-banding, enemies jumping, bullets that hit you but didn't look like it)?
- [ ] Performance: the slowdown for 10-20 s after a boss appears (2 players) should be gone. Still any stutter? Who had it, host or friend?
- [ ] Ping shown on the client HUD: what was it?

### 3.11 Menus and UI
- [ ] Settings (volume, fullscreen, screen shake). Do they work and stick after restarting?
- [ ] Menu style (dark panels, gold focus ring for gamepad, crisp pixel text, crypt backdrop on the title screen). Readable? Fits the game?
- [ ] HUD readable at your screen size? Anything you look for and can't find?
- [ ] Minimap: each thing has its own shape (you = big diamond, teammates = small diamonds, downed teammate = blinking "+", boss = skull, altar = sword, champion = crown, ritual = ring, thief = coin, chest = chest). Easy to tell apart at a glance?
- [ ] Minimap: helpful? Did you notice the red edge warning near walls?
- [ ] Run summary: Weapons page (button at the bottom): damage, share, DPS and kills per weapon. Numbers believable? Anything else you want there?
- [ ] Records (title menu): your best runs per hero on this PC, with a score. Shows after a real run? Does the score feel fair (kills, damage, bosses, victory, difficulty)?
- [ ] Title menu: Game Guide pages (Heroes, Weapons, Passives, Evolutions, Relics, Pickups, Events, Enemies, Bosses). Useful? Anything missing or wrong?
- [ ] Title menu: this Playtest Checklist. Ticks are remembered after restarting the game? "Copy what's left" works?
- [ ] "Send feedback" from the title menu and from the pause menu (Esc / Start). The message (with your name and the game info) arrives in Discord #feedback?
- [ ] "Include screenshot" during a game: the picture in Discord shows the game, not the menu?
- [ ] Typing in the boxes doesn't move your character or trigger other keys (R, F1, Esc)?
- [ ] Title screen: "(latest version)" next to the version, or "Version X is out!" + Update now when a newer release exists. Does updating work (download, restart into the new version)? Windows or antivirus warnings?

### 3.12 Looks and sound
- [ ] Pixel-art sprites for every character, enemy and boss. Do they read well at a glance in a crowd?
- [ ] Can you always tell the enemy types apart? The bosses?
- [ ] Your character in your player color: easy to find yourself? Is the white hitbox dot clear?
- [ ] Animations (walk cycles, enemy attack poses when they fire, death squash-and-fade, spinning coins). Readable and satisfying, or distracting?
- [ ] Gems: easy to spot now? Three tiers distinguishable?
- [ ] Floor decorations (tombstones, bones, skull piles, reeds, pews) are now about half a monster's size and faded into the floor. Still distracting, or now too hard to see?
- [ ] Pixel-art floors (Crypt slabs, Marsh mud and puddles, Cathedral marble and carpet) with props. Atmospheric? Too busy or too dark to read bullets?
- [ ] Any sprite you'd like redrawn (too small, wrong vibe, ugly)?
  - *Tune: sprites in `src/art/pixel_art.gd` or `assets/art/<sprite>.png`; props in `src/arena/floor_baker.gd` (`PROP_OPACITY`, `PROP_BRIGHTNESS`).*
- [ ] Music: menu/shop theme, one track per stage, boss theme. Does each fit its stage? Gets repetitive (loops are 10–27 s)? Too loud vs effects? *(Music volume in Settings)*
- [ ] Custom Game: Soundtrack (Classic / Metal / Metal boss fights / Shuffle). Do the metal tracks fit? Which stage track is best or worst?
- [ ] Sound effects: any sound too loud, grating, or missing? (Attacks, hits, enemy deaths, gems, coins, level-up, bomb, boss arrival, victory/defeat jingles.)
- [ ] Boss arrival sound (impact + bell + horn). Audible and dramatic enough?
  - *Tune: scores are text in `src/audio/tracks.gd` (the music files are rendered from them by `tools/render_music.gd`); sounds in `src/autoload/sfx.gd` (one line each).*

---

## 4. Decisions Claude made for you (revisit)

All of these are recorded in `DESIGN.md`. In one place:

- **Stage flow:** 4:00 horde then boss; when it arrives the horde is swept away and the boss brings an escort; then the horde comes back at 25% (capped); stage clear = boss dead.
- **Run:** 3 stages, each harder; Victory after stage 3.
- **Boss HP** scales with players (+75% each); regular enemies don't (more of them instead).
- **Revives:** 4 s in a 30 px circle, half HP back, slow drain, no bleed-out timer; otherwise you get up at the next stage.
- **Shop:** 4 personal relic offers, 10-coin reroll (+10 each), card rerolls for 15, 45 s after first Ready.
- **Auto-fire redesign:** the targeting details (reach, random picks), Mortimer's back throw, every HP and damage number, the healing amounts, the four perks, the three ability weapons' numbers and when they go off, the hidden cursor, the Watch demo's dodge part, Ghoul Blood and Bloodstone.
- **Builds:** the 12 passives and their numbers, the card weights, which passive each evolution needs, Spirit Daggers.
- **Map events and quests:** pop-up times, every reward number, champions as recolored crowned stage enemies, the nine quests.
- **Altars:** at 1:20 and 2:40 (more in co-op, near different players), first touch takes it; nothing left to give = 10 coins.
- **Mid-run joiners** play Kael.
- **Seventh list:** the boss fight numbers, no XP from the swept horde, +50% ritual speed per extra player, the "YOU" marker, the icon art, what the run summary shows, the Custom chip and gold values.
- **Eighth list:** a won full run unlocks the next hero (single-stage custom games don't; easier difficulties do); a downed player still gets the unlock when the team wins; how muted Hellfire is.

---

## 5. Known limitations (not bugs)
- Sound effects and music are synthesized from text (the music now plays from files rendered from those scores); new audio is planned (`docs/AUDIO_BRIEF.md`).
- Most sprites and all floors are drawn by Claude as text grids/code; the hero sprites are the first image files.
- Enemy bullets already on screen aren't sent to a friend who joins mid-fight (new ones are).
- Joining mid-run always gives Kael the Wanderer.
- The autopilot used in automated tests dodges badly, so its balance numbers only compare stages and heroes; real difficulty needs humans.

---

## 6. Reporting back

Paste something like this to Claude. Rough notes are fine:

```
Session: B (full solo run, Mortimer)   Result: died in stage 3 at ~2:00
Felt great: ...
Felt bad / unfair: ...
Too easy / too hard: ...
Bugs (what happened, roughly when): ...
Ideas: ...
```

Claude will turn it into tuning changes, fixes, and DESIGN.md updates.
