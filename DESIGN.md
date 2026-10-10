# Game Design Document

> Working title: TBD
> Last updated: 2026-10-10 (v0.18.0)

A 2D top-down, twin-stick roguelite bullet-hell shooter for online co-op with friends. It blends Vampire Survivors-style hordes and build power fantasy with readable, dodgeable bullet patterns.

---

## 1. Vision

- **Pillars**
  1. **Power fantasy through builds.** Start weak, end the run with the screen full of your own attacks.
  2. **Real dodging.** Tiny hitbox, few hearts, readable enemy bullet patterns. Skill matters.
  3. **Better with friends.** Online co-op for 1–4 players, but solo is fully supported.
  4. **Easy to pick up.** Simple controls, short runs, friends can jump in quickly.
- **Audience:** Me and my friends. Long-term goal is a complete game.
- **Platform:** Windows PC.

## 2. Tech

| Item | Decision |
|---|---|
| Engine | Godot 4.x |
| Language | GDScript, **statically typed** throughout |
| Development | AI-assisted coding. Keep everything text-editable and verifiable via `godot --headless` |
| Networking | Godot built-in high-level multiplayer (ENet), host-authoritative |
| Connection | Direct IP. The **host** makes the game reachable: Host Game tries UPnP to open the router port automatically, otherwise the host forwards UDP 7777 once by hand. The host gets an invite (`public IP:port`) copied to the clipboard; **friends just paste it and click Join**, no extra apps. Doesn't work if the host is behind CGNAT; fallback is a host-side tunnel such as playit.gg (friend still just pastes an address) |
| Input | Mouse + keyboard and gamepad, both fully supported |

| Base resolution | **640x360**, integer-scaled (3x at 1080p, 4x at 1440p, 6x at 4K) |
| Tests | GUT addon, plus a headless host+client smoke test script |

### Networking approach
- One player hosts; the host owns the true game state. Solo uses the same code with an offline peer (acts as a host with nobody connected).
- **Drop-in joining** for now: the host goes straight into the arena, and friends appear when they connect.
- Clients send one input per tick (60/s) to the host. The host simulates and sends snapshots at **30/s**.
- **Own player: predict and correct.** The client simulates its own movement immediately with the same deterministic code as the host. When a host snapshot disagrees, it corrects, smoothing small errors and snapping big ones.
- Other players and enemies on clients: smoothed toward the latest snapshot positions.
- Enemies: host simulates; positions and HP sent in compact batches, interpolated on clients.
- Bullets: **never synced individually.** Send pattern events (`pattern id, origin, aim, seed`) and let every client simulate the bullets deterministically. Bullet position = `origin + velocity * age`.
  - Player shots spawn on receipt. That matches the remote shooter, who is also shown slightly delayed. Enemy/boss patterns (M3) will add a shared clock (`time`) so clients can fast-forward late-arriving patterns.
  - Only the host's bullets deal damage. Client bullets are visual.
- Heavy use of object pooling for enemies, bullets, and pickups.

## 3. Core gameplay

### Format
- Twin-stick roguelite with runs made of **arena stages in sequence**.
- Each stage: a few minutes of enemy waves, then a boss, then a shop / upgrade break.
- **Run length target:** 15–20 minutes.

### Threat model (hybrid)
- Hordes of enemies that swarm the player (contact damage).
  - **Spawning:** continuous ramp (Vampire Survivors style). A steady trickle off-screen around the players gets denser over time, with occasional **pack surges** (a tight cluster from one direction).
  - **First melee roster (M2):** Shambler (basic, medium speed, low HP), Bat (fast, very weak, erratic), Ghoul (slow, tanky, big).
- Some enemy types, and all bosses, fire readable bullet patterns.
- **Bullet density:** readable (Enter the Gungeon-like), not hardcore shmup. See *Ideas for Later*.

### Player
- **Health:** a few hearts (depends on the character), with a hitbox much smaller than the sprite. Enemy contact costs 1 heart, then ~1s of invulnerability (flashing).
- **Downed:** at 0 hearts the player is downed and lies in a revive circle until a teammate revives them (see Co-op rules).
- **Movement:** free 8-direction / analog movement.
- **Aiming:** manual 360° aim with the mouse or right stick.
- **Defense:**
  - **One character ability** on one button, on a cooldown (owner decision after the first playtest; replaces the separate dash and bomb). Dash and a bomb-like blast are abilities of specific characters.

### Weapons
- **Main weapon (v0.19.0):** each hero has their own, always aimed with the mouse / right stick and used by holding fire (owner decision: unique weapons instead of everyone shooting bolts; every hero keeps aiming so the twin-stick feel stays). See *Hero main weapons (v0.19.0)* in Milestones.
  - Wanderer: **Bolt Gun** (unchanged). Gravekeeper: **Reaper's Scythe**. Hexblade Witch: **Chain Lightning**. Necromancer: **Bone Spears**.
- **Auto weapons:** found on altars and in champions' chests, fire automatically: Orbiting Skulls, Seeking Bolts, Holy Aura, Hellfire Trail. (Reaper's Scythe, Chain Lightning and Bone Spears were auto weapons in v0.17–0.18; they're main weapons now and no longer drop.)

### Characters
- Multiple playable characters, each with a **unique kit** (main weapon, stats, unique ability, and their own weapon upgrades).
- Encourages team composition in co-op.

## 4. Progression

### In-run
- **XP level-ups:** enemies drop **XP gems**. Any player who walks near pulls them in (magnet radius), and they fill the shared team bar. On level-up, each player picks 1 of 3 upgrades. Each card shows its level as pips (owned / this pick / left to max) and the player's real stat before -> after taking it.
  - **Late levels (v0.18.0):** from level 15 on, a level also costs 1.5·(n−15)² more, so teams stop snowballing through stages 2–3 (an invincible solo autopilot used to reach level 44–53 by the end; now ~40).
  - **Pacing (v0.15.0):** level n costs 10 + 9·(n−1) XP, times +40% per extra player (spawns grow 60%, so bigger teams level slightly faster). History: v0.13 cost 5 + 5·(n−1) with no team factor (a 2-player team got ~30 level-ups in stage 1: too many pauses); v0.14.0 cost 16 + 14·(n−1) × the spawn factor, which left the team too weak to beat stage 1. Measured with the autopilot (solo, it can't dodge or collect everything): level 13 by the boss and the horde under control, vs level 7 and an overrun arena in v0.14. Sharpened Bolts went +3 → +4 damage and Quick Hands 12% → 15%.
  - M2 upgrades are **stat upgrades only** (damage, fire rate, move speed, max hearts, extra bolt, pierce, pickup radius, dash cooldown, heal). Auto weapons come later.
  - **v0.16.0: 25 upgrades** (owner asked for more, a mix of stats and new mechanics, a couple of trade-offs and one per hero). New:
    - *Stats:* Long Shot (bolt range +30%), Steady Nerves (+0.3 s safety after a hit), Swift Bolts (bolt speed +20%), Arcane Focus (ability power +20%).
    - *Mechanics:* Keen Edge (10% chance a main-gun bolt does double damage; gold sparks), Corpse Blast (enemies you kill burst for 12 damage in 32 px; bursts don't chain), Giant Slayer (+25% damage to bosses) and Executioner (+30% to enemies below half health), both from all your damage sources, Ricochet (after its last hit a bolt bounces to the closest enemy within 110 px), Hunting Bolts (bolts turn toward enemies within 130 px).
    - *Trade-offs:* Glass Cannon (+10 damage, −1 max heart; once; not offered at 1 max heart) and Reckless Haste (fire 25% faster, move 10% slower).
    - *Hero-only* (only offered to that hero; the Compendium says whose): Afterimage (Wanderer: untouchable 0.3 s longer after a Dash), Hallowed Blast (Gravekeeper: +40% blast damage, heals 1 more), Deep Hex (Witch: hex +1 s, hexed enemies +25% damage), Ossuary (Necromancer: Effigy +1.5 s, burst +50%).
    - An upgrade can carry extra effects (`Upgrade.extra_effects`, used by trade-offs and hero upgrades); cards show one before -> after line per effect.
    - Networking: damage bonuses and crits are rolled by the host (`HitBonus`, in `EnemyManager.damage`); crits reach clients as a snapshot flag. Corpse Blast bursts go to clients as one batched message per tick. Ricochet and homing run on every peer for their own (visual) bolts; the host decides the real hits, as before.
- **Weapon pickups:** new auto weapons found during stages (altars and champions' chests). v0.17.0: 7 weapons (see Playtest 4 changes).
- **Power-up pickups (v0.17.0):** Heart, Soul Magnet, Holy Bomb, Frost Hourglass (see Playtest 4 changes).
- **Passive items / relics:** stat boosts and synergies.
- **Shop between stages:** spend coins on items.

### Meta
- **None.** Each run stands alone, with no unlocks or permanent upgrades.
- **Records (v0.15.0):** each PC keeps its own best runs (top 10 per hero, `user://records.cfg`) with a score: 10 per kill + 1 per 10 damage + 3000 per boss + 5000 for a victory, times the difficulty (enemy/boss health and enemy count; bonus hearts, starting levels, extra XP and all weapons lower it). Shown on the title menu's Records page and as "Score" on the run summary. Bragging rights only, no unlocks.

## 5. Co-op rules

| Topic | Rule |
|---|---|
| Players | 1–4 |
| Friendly fire | Off |
| XP | **Shared** team XP bar; each player picks their **own** upgrade |
| Level-up flow | **Pauses for everyone.** Since XP is shared, all players level up at once and choose simultaneously. The pause waits until someone picks, then the rest have a **30s countdown**. It resumes once everyone has picked, and anyone who hasn't picked when time runs out gets a random upgrade. Several level-ups at once are chosen one after another. While waiting, your pick stays highlighted. Online, play resumes after a **3-second "3, 2, 1" countdown** (also after the shop); solo resumes right away (v0.18.0) |
| Loot (weapons, relics, coins) | **Shared world drops, first come first served** |
| Death | **Downed and revivable** (v0.15.0, owner request; replaced ghosts). At 0 hearts you lie in a circle (30 px) and can't move, shoot or use your ability. A teammate standing in the circle revives you in **4 s** (two helpers: 2 s; `revive_speed` and the Mourner's Bell relic make it faster); you get up with half your max hearts (rounded up) and 2 s of safety. Nobody in the circle: the progress drains slowly. Not revived: you get up at the next stage. Your screen follows a living teammate after 1.5 s (Fire / Ability cycles, ending on your own body). Teammates see a pulsing edge arrow with a "+" and the name, a blinking "+" on the minimap and a "Red is down!" line. (Since v0.18.0 only downed teammates get edge arrows; healthy ones are on the minimap.) Run ends if everyone is down at once |
| Difficulty scaling | **More enemies, same toughness:** spawn rate rises with player count (start: +60% per extra player). Enemy HP stays the same. Tune in playtests |
| Pause | Solo: the Esc menu pauses the game. Online: nobody can pause; the Esc menu only blocks your own controls. (v0.17.0's host pause that froze everyone was removed in v0.18.0: the owner saw the game desync and it wasn't worth it) |
| Names | Each player types a display name on the title menu (saved on their PC, max 12 characters, only characters the pixel font draws). Without one you're called by your slot color ("Red"). Shown on lobby cards, over teammates' heroes, on edge arrows, in toasts and "Waiting for..." lines, and on the run summary. Clients send it to the host on connecting; the host sends the list to everyone (`Net.names`) |
| Map events and quests | Events are shared (anyone can wake a champion, hold a ritual, catch a thief); a chest goes to whoever touches it first. Quests are personal (each player picks their own) |

## 6. Art & audio

- **Setting:** Dark fantasy (undead hordes, demons, dark magic).
- **Art style:** Pixel art. Sprites are text grids with a shared palette (`src/art/pixel_art.gd`).
- Bullets must stay readable against backgrounds (high-contrast, glowing projectiles).
- Audio: everything is synthesized in code from text (no audio files). Sound effects use a small synth with filters, layering and echo; music is five looping chiptune-style tracks written as text scores (menu, Crypt, Marsh, Cathedral, boss). Final audio direction TBD after playtesting.
- **Metal soundtrack (v0.15.0, owner request):** four more tracks with distorted power-chord riffs (palm-muted chugs and ringing chords), double kick, crashes and an overdriven lead: Crypt (E minor gallop), Marsh (slow Phrygian doom), Cathedral (neoclassical thrash), boss (tremolo riffs over a blast beat). The host picks in Custom Game: Classic / Metal / Metal boss fights / Shuffle (alternates per stage). The menu stays classic.

## 7. Milestones

### Milestone 1: Online movement & shooting ✅ (done 2026-10-09; internet playtest with a friend felt smooth)
- Godot project setup and project rules file (`CLAUDE.md`, Godot 4.x only, typed GDScript).
- Host / join by IP.
- 2+ players move, dash, and shoot (mouse and gamepad).
- Dummy enemies that take damage, synced across clients.
- **Goal:** prove the netcode early, before content is built on top of it.

### Milestone 2: Hordes, XP, level-ups ✅ (playtested 2026-10-09: fun, everything worked; fixed gamepad card picking in 0.3.1)
- Shambler / Bat / Ghoul hordes with ramping spawns and pack surges; hearts, i-frames, downed state.
- XP gems with magnet pull, shared team level, networked level-up pause with 9 stat upgrades.
- 5-minute timed stage, "Stage clear" / "Run over", host restart (R / Start).

### Milestone 3: First stage + first boss ✅ (stage 1 and its boss playtested solo 2026-10-09; stages 2–3 not yet)
Decisions made by Claude while the owner was away. **Revisit in the next playtest.**
- **Stage flow:** 4:00 of horde waves, then the boss arrives. The horde keeps trickling at 40% rate during the fight, with no pack surges. **Stage clear = boss defeated** (no longer a timer).
- **First boss, "The Bone Warden":** a slow, huge undead that drifts toward the players and cycles attacks:
  - ring bursts (bullets in every direction)
  - a spiral
  - aimed fans at each player
  - Below 50% HP: phase 2, faster with a double spiral.
  - Boss HP scales with player count (+75% per extra player). Regular enemies still don't scale (see Co-op rules).
- **First ranged enemy, Cultist** (from 2:00): keeps its distance and fires a slow 3-bullet aimed fan.
- **Enemy bullets:** 1 heart per hit; readable speeds (90–140 px/s); magenta glow with a white core. Dashing passes through them.
- ~~**Bomb:** 2 per stage.~~ Replaced in v0.12.0 by character abilities (the Gravekeeper's Grave Blast works like the old bomb, on a cooldown).
- **Fair dodging online:** enemy bullet patterns are fast-forwarded on clients by the network delay, so what you dodge on your screen matches what the host checks.
- **Arena look:** dark stone floor with seeded variation, plus decorative graves and bones (no collision yet).

### Milestone 4: Multi-stage run, ghosts, coins & shop, relics, auto weapons ✅ (shop seen in the solo playtest: too many coins, fixed in v0.12.0; the rest not yet playtested)
Decisions made by Claude while the owner was away. **Revisit in the next playtest.**
- **Run = 3 stages** in the same crypt arena (distinct stages/themes come in M5). Each stage is harder:
  - ~~Spawn rate +35% per stage. Enemy and boss HP +50% per stage.~~ Far too gentle (owner, v0.17: "stage 2 and 3 are super easy"). **v0.18.0:** enemy HP x1 / x4 / x9, boss HP x1 / x4.5 / x12, spawn rate x1 / x1.4 / x1.8, and stages 2 and 3 start their spawn ramp 45 s / 90 s in (see Playtest 5 changes).
  - Beating the stage 3 boss = **Victory**.
- **Between stages:** a **shop break**. The run keeps your team level, upgrades, relics, weapons and coins.
- ~~**Ghosts:** a downed player becomes a ghost until the next stage (floats around, collects gems and coins).~~ Replaced in v0.15.0 by revives (see Co-op rules). Everyone still respawns with full hearts and a ready ability at the start of the next stage.
- **Coins:** enemies sometimes drop coins (v0.12.0: 4% basic, 20% tougher enemies), plus a boss bounty for everyone (25, +15 per stage). First come, first served: coins go to whoever picks them up.
- **Shop:**
  - Each player sees their own 4 relic offers with prices and buys with their own coins.
  - Relics cost 40–80 (v0.12.0, after the playtest showed 350 coins in round 1). Target: about one relic per shop, two if you save.
  - Rerolls cost 10, then +10 each within the same shop.
  - The shop closes when everyone presses Ready, or 45s after the first Ready (same pattern as level-ups).
- **Relics:** passive items with stat effects and trade-offs (e.g. Cursed Skull: +damage, −1 max heart). Each relic can be bought once.
- **Auto weapons:**
  - Found as **weapon altars** that appear twice per stage (~1:20 and ~2:40). First player to touch one takes it. Taking a weapon you already own levels it up (max level 3).
  - Three weapons to start: **Orbiting Skulls** (circle you, hurt on touch), **Seeking Bolts** (auto-fire at the nearest enemy), and **Holy Aura** (pulses damage around you).

### Milestone 5: Characters, lobby, three themed stages ✅ (implemented; characters reworked around abilities in v0.12.0; not yet fully playtested)
The owner approved the plan; details below are Claude's defaults. **Revisit in the next playtest.**
- **Lobby:**
  - Solo/Host/Join leads to a lobby: pick a character, press Ready, and the host starts (solo starts right away).
  - After Victory or Run over, the host returns everyone to the lobby.
  - Friends joining mid-run still drop in, as the Wanderer.
  - **Party page + hero picker (v0.18.0, owner request):** the lobby's main page shows the whole party, one card per player (name, their hero walking on the spot, ability, hearts, ready state; 3 players = 3 cards). Your own card or **Choose Hero** opens a sub-screen with the four heroes; picking one goes back.
  - **Difficulty and Custom Game pages (v0.14.0, owner request; defaults by Claude, revisit):** the host sets them in the lobby; friends see them read-only, and a summary line shows the current choice. Saved on the host's PC.
    - *Difficulty:* sliders for enemy health, boss health, enemy count (spawn rate), XP gain, coin drops (25%–300%), and bonus hearts (−2 to +3). Presets: Easy / Normal / Hard.
    - *Custom Game:* full run or a **single stage** on a chosen map (won by clearing it; it always has first-stage toughness whichever map), wave length (1–10 min), boss on/off (off = survive the timer to win), starting level-ups (0–10), start with every auto weapon.
- **Characters (one passive ability each):**
  - **Wanderer:** balanced. Ability **Dash** (0.8s): quick dash, can't be hit while dashing.
  - **Gravekeeper:** slow, 5 hearts, short-range shotgun. Ability **Grave Blast** (14s): clears nearby enemy bullets, damages enemies around you, heals 1 heart.
  - **Hexblade Witch:** fast, 2 hearts, rapid piercing bolts. Ability **Hex Snare** (7s): hurls a hex ~80px ahead; enemies inside (55px) are bound for 3s (can't move or attack) and take +50% damage. Bosses aren't bound but still take the extra damage. *(v0.13.0, replaced Blink: the owner felt it was just another dash.)*
  - **Necromancer** *(v0.13.0, 4th character for 4-player games)*: medium speed, 3 hearts, a fan of 3 bone shards (Extra Bolt adds 2). Ability **Bone Effigy** (10s): raises a decoy ~40px ahead for 4s; regular enemies within 150px chase it instead of players, then it bursts (70px, 45 damage). Bosses ignore it.
  - *Decisions made by Claude while the owner was away (v0.13.0): the two new abilities, the Necromancer's look and stats. Revisit in the next playtest.*
  - (v0.12.0: the old passives Second Wind and Grave Ward were removed when abilities replaced dash/bomb.)
- **Stages** (each has its own floor, enemy mix and boss; data-driven `StageDef` resources):
  1. **The Crypt:** Shamblers, Bats, Ghouls, Cultists. Boss: the Bone Warden.
  2. **The Bone Marsh:** Mire Crawlers (fast swarms), Plague Spitters (slow bullet rings), Ghouls. Boss: the Mire Hag (sweeping bullet walls, random sprays).
  3. **The Burning Cathedral:** Flame Imps (fast, erratic), Fallen Paladins (tanky, aimed lines), Cultists. Boss: the Ashen Bishop (rotating crosses, aimed bursts).

### Polish pass (v0.7.0, by Claude while the owner was away)
- Pause menu (Esc / Start) replaces instant-leave; solo pauses, online only blocks your input.
- Settings: master/effects volume, fullscreen, screen shake (saved).
- Game feel: particles (hit sparks, death puffs), screen shake, hurt flash.
- Sound: 14 synthesized placeholder effects; no music yet (Audio still TBD, see section 6).
- End-of-run stats table (kills, damage, times downed).
- Everything awaiting human review is listed in `docs/PLAYTEST.md`.

### Pixel art pass (v0.8.0, by Claude)
- All characters, enemies, bosses, pickups and orbit skulls are pixel-art sprites drawn as text grids in `src/art/pixel_art.gd`, using one shared limited palette.
- Player sprites are tinted with each player's slot color; bosses are drawn at 2x; bats and imps animate.
- Bullets stay as glowing code-drawn circles and the player's hitbox dot is always visible (readability first).

### Floors and sound pass (v0.9.0, by Claude)
- Floors: each stage's ground is baked into one image from a seed (Crypt slabs, Marsh mud and puddles, Cathedral marble and carpet), with pixel-art props, shadows and candle light.
- Sound: richer synthesized effects, plus music: calm menu/between-stages track, one per stage, and a boss theme, crossfading as the game changes phase. Music volume in Settings.

### UI pass (v0.10.0, by Claude)
- One theme for all menus: dark purple panels, square pixel borders, gold focus ring (gamepad), crisp non-antialiased text.
- Title screen: large gold title, tagline, dimmed Crypt floor backdrop.
- Removed the aim line drawn on players (owner request); sprites face the aim direction.

### Animation pass (v0.11.0, by Claude)
- Walk cycles for all heroes and walking enemies; attack poses for bosses and ranged enemies when they fire; enemies squash and fade on death (bosses take longer); coins spin and pickups bob.
- Fixed: left-facing sprites were drawn one sprite-width off their real position (players and enemy hitboxes didn't line up with what you saw).

### Playtest 1 changes (v0.12.0)
Owner played solo, beat stage 1. Requested and done:
1. Better gem art: three crystal tiers (blue / green / big violet) with a glow.
2. Minimap (top-right) with your view, players, horde, boss, altars; the side near a wall lights up red.
3. Readable text: a hand-drawn pixel font everywhere; shop and level-up cards split into title / description / price.
4. Shop economy: far fewer coins, higher prices, escalating rerolls (see Milestone 4 notes).
5. Character abilities replace dash and bomb (see Milestone 5 notes).
6. Title screen shows version, build commit and date.
Also: lobby cards restyled.

### Playtest 2 changes (v0.14.0)
Owner played a co-op run with one friend ("awesome, a great start"). Requested and done:
1. Your level-up pick stays highlighted (gold border, others dimmed) while others choose; status says "You chose X".
2. Level pips on level-up cards (filled / blinking gold for this pick / hollow up to max).
3. Auto weapons shown as pixel icons with level pips: HUD, run-end cards, and over altars.
4. Arrows at the screen edge point to off-screen teammates (their color; faded for ghosts).
5. Lobby portraits now show your real player color (they never redrew, so everyone saw Blue); color squares show who picked each hero.
6. A 3-second "3, 2, 1" countdown with beeps before play resumes after level-ups and the shop (`Arena.Phase.COUNTDOWN`).
7. Victory / Run over has a "Return to character select" button for the host (R / Select still works).
8. New boss arrival sound: impact, tolling bell and a dissonant horn swell (the old low growl was hard to hear).
9. Far fewer level-ups (see Progression, Pacing). Difficulty was judged good, so enemies are unchanged. **Watch:** with half the upgrades, players are weaker by stage 2–3; if it gets too hard, make upgrades stronger rather than more frequent.
10. *(Added after the playtest list)* Title menu: **Compendium** (heroes, weapons, upgrades, relics, pickups, enemies, bosses; all numbers read from the game data) and **Playtest Checklist** (the items in `docs/PLAYTEST.md`, tick as you test, "Copy what's left" to paste to Claude).
11. *(Added after the playtest list)* Lobby: **Difficulty** and **Custom Game** pages (see Milestone 5, Lobby).
12. *(Reported after)* Slowdown for 10-20 s after a boss spawns with 2 players: boss bullets (7 s lifetime, aimed at each player) were each drawn as two `draw_circle` shapes, hundreds of draw calls rebuilt every physics tick. Now one baked texture per bullet/gem glow, off-screen ones skipped: client physics step with ~110 bullets 4.7 ms -> 1.1 ms, draw calls ~650 -> ~150. Enemy grid also cheaper (~15%).
13. *(Requested after)* In-game updater: the title screen checks GitHub's latest release; if newer, **Update now** downloads the zip, swaps `GameTest.exe` (renames the running one to `.old`) and restarts. Falls back to opening the release page.

### Playtest 3 changes (v0.15.0)
Owner and friend played more v0.14 runs. Requested and done:
1. **Difficulty:** v0.14's level-up pacing made stage 1 unbeatable. Levels are cheaper again and two upgrades are stronger (see Progression, Pacing).
2. **Revives instead of ghosts** (see Co-op rules, Death), and the downed player's screen follows a living teammate.
3. **In-game cursor** (Settings): Crosshair / Ring / Dot / System arrow, 4 sizes, 7 colors, dark outline, scaled to the window (`GameCursor`, a hardware cursor). Menus keep the normal arrow.
4. **Run summary:** a star for the best player in each stat (lowest for Hearts lost and Downed; none on ties or solo); weapons, upgrades and relics as pixel icons (hover for names; the same icons are on level-up and shop cards and in the Compendium); a **Weapons** page with damage, share, DPS (over the time the weapon was owned) and kills for the main gun, ability and each auto weapon (the host tags all damage with a `DamageSource`).
5. **Records** page and per-player Score (see Meta).
6. **Soundtrack** option with four metal tracks (see Art & audio).

Decisions made by Claude (**revisit in the next playtest**): revive numbers (4 s, 30 px circle, half hearts, slow drain, no bleed-out timer), the spectate delay and controls, the Mourner's Bell relic (40 coins, co-op only), the cursor default (cyan crosshair, medium), the score formula, and the metal track arrangements. Test aid: `--test-down=<s>` knocks out the first client's player so revives can be checked without dying; the autopilot now walks to downed teammates.

### In-game feedback (v0.16.0, owner request)
- **Send feedback** on the title menu and the pause menu: your name (remembered), kind (Suggestion / Bug report / Praise), a message, and a **screenshot of the game** (checkbox, on by default in a game; the pause menu hides itself for the picture).
- Game info is added automatically: version and build, OS, stage and map, time into the wave or boss fight, phase, team level, your hero, position, hearts and build counts, solo / co-op (host or client, ping) and the run settings.
- Posts to the Discord `#feedback` channel through a webhook (owner chose Discord over GitHub issues: no accounts for friends, screenshots attach natively, no GitHub token in the game). The link is baked into builds from a git-ignored file. Without it, Send copies the message to the clipboard.
- 20 s between sends; messages are capped at 1500 characters and can't ping anyone.

### More upgrades (v0.16.0, owner request)
16 new level-up upgrades (25 in total), see Progression, In-run. The owner chose the mix (stats, new mechanics, a couple of trade-offs, one per hero). Decisions made by Claude (**revisit in the next playtest**): every number (crit 10% / x2, burst 12 damage in 32 px, +25% vs bosses, +30% vs wounded below 50%, ricochet range 110 px, homing turn 2.5 rad/s per pick within 130 px), the stack limits, which upgrades are trade-offs, and the four hero upgrades. With 22 upgrades offered to each hero instead of 9, a favourite shows up less often; **watch** whether runs feel too random. Test aid: `--give-upgrades=<id,id,...>` (`Upgrades.ALL` ids) gives every player those upgrades at the start.

### Playtest 4 changes (v0.17.0, owner's fourth list)
The owner asked for map events (a reason to explore), arrows to them, quests picked in the shop, more weapons and pickups, and a real host pause. The owner chose in a Q&A: champion lairs, ritual circles and treasure thieves (not cursed shrines); a few events placed at stage start plus pop-ups; edge arrows + minimap; free personal quests (1 of 3, no penalty); all four proposed weapons and pickups; host-only pause; rewards that vary by event.
1. **Map events** (`MapEvents`, host-run, synced as a small snapshot 10 times a second):
   - **Champion lair** (one per stage, placed at the start away from the middle): a dark statue of the stage's champion on a red ring. It wakes when a player comes within 150 px. Champions are crowned, recolored, bigger versions of a stage enemy that shoot back (Ghoul Champion: 8-bullet rings; Plague Champion: 12-bullet bursts; Paladin Champion: 7-bullet aimed fans), 1200–1600 HP in stage 1, +60% per extra player. Killing one drops 10 coins (3 each), a power-up and a **chest**: the first player to touch it gets a random auto weapon they can still level (30 coins if all are maxed).
   - **Ritual circle** (one at the start, one pop-up at 2:20 that fades after 50 s if nobody starts it): stand inside to start it; 15 s of standing fills it, with nobody inside it drains over 30 s. While held, waves of 2 (+1 per extra player) stage enemies come from 200 px away every 1.2 s. When full: XP gems worth 60% of the current level, and everyone inside heals 1.
   - **Grave Robber** (pop-ups at 1:10 and 3:20): a fast thief (88 speed, 220 HP, no contact damage) that runs from the nearest player and turns away from walls, dropping a coin every 1.5 s. Caught within 20 s: 14 coins (2 each). Otherwise it escapes.
   - Pop-ups stop once the boss arrives; everything left is cleared when the stage ends.
   - **Finding them:** edge arrows in the event's color with its icon (crown, ritual sigil, coin, chest), blinking minimap squares, and toasts under the timer with a bell sound.
2. **Quests** (`Quests`, `QuestTracker`): in the shop each player picks 1 of 3 for the next stage (free; a random offer if they don't pick; can change until Ready). Done during that stage = paid at once (coins or a free relic); unfinished ones expire. Nine quests: Champion Hunter (45 coins), Ritualist (relic), Thief Catcher (35), Slayer: 250 kills (40), Untouchable: 60 s without losing a heart (relic), Gold Digger: 40 coins (relic), Arsenal: 4000 auto weapon damage (45), Scavenger: 2 power-ups (35), Guardian: revive a teammate (relic, co-op only). The HUD shows "Quest: Slayer 120/250" under the weapon icons. Quests only exist for stages 2 and 3 (the first shop comes after stage 1).
3. **Four new auto weapons** (7 in total; altars and chests pick from all of them):
   - **Chain Lightning:** every 1.5 s strikes the nearest enemy within 200 px and jumps to 3 more (+1 per level) within 100 px; 12 damage (+5/level).
   - **Reaper's Scythe:** every 1.8 s a scythe flies 110 px out in your aim direction and back to you (1.2 s), cutting each enemy once each way; 18 damage (+7/level); 1 / 2 / 3 scythes spread around you.
   - **Hellfire Trail:** walking leaves a flame every 10 px that burns 2 s; enemies in your flames take 5 damage (+3/level) every 0.5 s (once per tick however many flames).
   - **Bone Spears:** every 2 s (faster per level) 2 (+1/level) random enemies within 220 px get a closing warning ring, then a spear strikes 0.45 s later for 30 damage (+12/level) in 14 px.
   - Networking: only the host deals damage. Scythe throws, lightning paths and spear spots are small events; every peer draws Hellfire from where it sees each player walk.
4. **Power-ups** (a third pickup pool): 1.2% of regular kills drop one (at most one per 10 s), plus one from every champion. Heart (heal 1; 35% of drops), Soul Magnet (every XP gem on the map flies to you; 25%), Holy Bomb (400 damage × stage HP growth to every regular enemy within 260 px, clears enemy bullets there; bosses spared; 20%), Frost Hourglass (regular enemies and every enemy bullet already flying freeze for 4 s; frozen bullets still hurt; 20%). The Holy Bomb is its own line on the run summary's Weapons page.
5. **Host pause** (removed again in v0.18.0, see Co-op rules).
6. Compendium: an **Events** tab (events and every quest), the new pickups and weapons; champions and the Grave Robber on the Enemies tab.

Decisions made by Claude (**revisit in the next playtest**): every number above, the champion designs (recolored stage enemies with a crown instead of new sprites), pop-up times, the quest list and rewards, the weapon and pickup numbers, freezing bullets in place rather than clearing them, and that the Grave Robber does no contact damage.

### Playtest 5 changes (v0.18.0, owner's fifth list)
1. **Shooting enemies on top of you:** a friend reported enemies inside your hitbox couldn't be hit. Bolts appear at the muzzle (9 px out) and fast ones moved ~6 px a tick, checked only where they landed, so they jumped over enemies right next to you. Now each tick checks the whole path the bolt flew, and a new bolt checks back to the shooter's center (`EnemyManager.find_hit_on_path`). Not a design choice, a bug.
2. **Exit Game** on the title menu.
3. **Host pause removed** (it desynced; see Co-op rules).
4. **Run summary fixes:** the Weapons page ran off the bottom of the screen and took the page tabs with it, so you couldn't go back. The cards now sit in a scroll box sized to the screen (wheel or Up / Down), weapon rows are one compact line each (hover for every number; unused weapons as dim icons), and Esc / B returns to Overview.
5. **Run summary, beefed up:** letters drop in and shimmer, gold confetti (victory) or rising embers (defeat), the run's bosses as trophies (slain on a gold plinth / the one that ended the run in red / unreached as silhouettes), a team score chip (hover: difficulty multiplier), a crown and "MVP" on the top scorer's card, victory heroes walk on the spot, ticking count-up, and a third **Highlights** page (MVP, deadliest weapon, kill rate, coins, XP, and co-op leaders).
6. **Lobby party page + hero picker** (see Milestone 5, Lobby).
7. **Display names** (see Co-op rules).
8. **Solo skips the "3, 2, 1"** after level-ups and the shop.
9. **Chests that wouldn't open:** opening needed your center within 12 px of the chest's, so brushing it with your sprite did nothing. Now 20 px (altars 12 -> 16 px). No other cause found (every champion death goes through the same kill path).
10. **Minimap shapes** (owner: "instead of just squares"): you = a big diamond, teammates = small diamonds, a downed teammate = blinking green "+", boss = skull, weapon altar = sword, champion = crown, ritual = ring, Grave Robber = coin, chest = chest; each with a dark outline. Enemies stay dots.
11. **Edge arrows only for map events and downed teammates** (owner request: arrows to every teammate were clutter).
12. **"Compendium" renamed "Game Guide"** (the owner didn't know the word).
13. **Stages 2–3 rebalanced** (owner: "super easy after you defeat stage 1"). Measured with a new `[balance]` line the host prints at every stage end, on solo invincible autopilot runs (`--invincible` now lets hits land and counts them, but refills hearts) with all four heroes, fast-forwarded with `--fixed-fps 60`:
    - Before: hits taken 36–93 / 9–10 / 15–25 per stage, boss fights 38–66 s / 8–36 s / 3–7 s. The team's damage roughly triples by stage 3 (levels 44–53, every weapon, relics) while enemies only had +50% / +100% HP, and each stage's spawn ramp started from zero.
    - After (see Milestone 4 and Progression for the numbers): hits 41 / 52 / 125 on average, boss fights 61 / 76 / 101 s. Stage 2 is a little harder than stage 1, stage 3 is the real test. The Holy Bomb and the Game Guide's HP numbers follow the same tables.
    - *Not measured:* co-op (the per-player factors are unchanged, so the curve should hold) and real humans, who dodge far better than the autopilot. **Watch** in the next playtest: if stage 3 is a wall, lower `ENEMY_HP_BY_DEPTH[2]` / `BOSS_HP_BY_DEPTH[2]` in `src/arena/arena.gd` first.

Decisions made by Claude (**revisit in the next playtest**): names on the title menu (not the lobby), 12 characters, name tags only over teammates; the party card layout; the Highlights lines; the chest radius; the minimap shapes; "Game Guide" as the new name; every balance number in item 13.

### Hero main weapons (v0.19.0, owner request; released)
The owner asked for a unique main weapon per hero instead of everyone's bolt gun (one hero keeps it), reusing the existing weapons. Q&A choices: every main weapon stays **aimed** (Claude advised against heroes that don't aim: half the controls would do nothing and co-op skill levels would drift apart), the three weapons that became main weapons leave the pickup pool, each main weapon gets **its own upgrade set**, and the Wanderer stays as is.
1. **Main weapons** (`CharacterStats.main_weapon`, append-only enum `MainWeapon`; numbers in `characters/*.tres`; pure math in `MainWeapons`):
   - **Bolt Gun** (Wanderer): unchanged.
   - **Reaper's Scythe** (Gravekeeper): every 0.8 s a scythe flies 115 px toward your aim and back to you (0.7 s), 30 damage per cut, each enemy cut once out and once back. Replaces the 5-pellet shotgun.
   - **Chain Lightning** (Hexblade Witch): every 0.3 s lightning strikes the enemy closest to your aim (within 150 px and 35° of the aim, any side within 14 px) for 16, then jumps to 2 more within 70 px. Nothing ahead: a short zap into the air. Replaces the rapid piercing hexes.
   - **Bone Spears** (Necromancer): every 0.5 s a row of 5 spears rises along your aim (22 px apart, from 22 px out), each after a 0.3 s warning plus 0.04 s per spear (the row runs outward), 20 damage in 11 px. In a line rather than at the cursor: the game only sends aim direction, and a gamepad stick has no distance. Replaces the bone-shard fan.
   - Networking: like bolts, an attack is predicted by the shooter and decided by the host; the host tells the other peers (scythe throw: aim; spear row: origin + aim + seed; lightning: the paths it hit). Only the host deals damage. The shooter's own lightning is drawn from its own view of the enemies.
   - **Balance check** (solo invincible autopilot, `--fixed-fps 60`, compared with v0.18.0): Witch and Necromancer within noise of before (both win; stage boss fights 61/49/72 s and 33/53/79 s vs 9/40/49 s and 39/72/181 s). The first scythe (100 px, 24 damage) was clearly weaker (stage 2 boss 181 s vs 92 s); at 115 px / 30 damage two runs won with stage 2 bosses of 117 s and 81 s. Not measured: co-op and real players.
   - All main-weapon damage is still `DamageSource.MAIN_GUN`; the run summary shows the hero's weapon name and icon. Crits (Keen Edge) work on every main weapon.
2. **Upgrades:** Sharpened Bolts became **Sharpened Edge** (+4 main weapon damage), Quick Hands, Keen Edge, Glass Cannon and Reckless Haste work for every main weapon. The six bolt upgrades (Extra Bolt, Piercing Bolts, Long Shot, Swift Bolts, Ricochet, Hunting Bolts) are **Wanderer only** (`Upgrade.for_weapon`). 12 new weapon-only upgrades (37 in total):
   - *Scythe:* Twin Scythes (+1 scythe, fanned 25°; x2), Long Reach (+25% distance; x3), Heavy Blade (+30% size; x3), Grim Harvest (can cut each enemy 3 times per throw; once).
   - *Lightning:* Forked Lightning (+1 jump; x3), Long Arc (+25% strike and jump range; x3), Conductor (each jump +20% damage over the last; x2), Split Bolt (a second chain splits off at the first enemy; once).
   - *Spears:* Longer Row (+1 spear; x3), Wide Spikes (+25% size; x3), Quick Rise (warning 30% shorter; x2), Splinters (each spear sprays 3 bone shards for 40% damage; once).
3. **Relics:** Bone Charm (pierce) and Hunter's Eye (bolt speed) are only offered to bolt heroes (`Relic.for_weapon`).
4. **Auto weapons:** altars, chests, the "start with weapons" custom setting and `--give-weapons` only use `AutoWeapons.PICKUPS` (4 weapons). The old auto-weapon resources stay registered (append-only ids).
5. Three new attack sounds (scythe whoosh, lightning zap, bone crack), 12 upgrade icons, and Game Guide hero entries that describe each main weapon.

Decisions made by Claude (**revisit in the next playtest**): which weapon goes to which hero, every number above, spears in a line instead of at the cursor, the 12 upgrades, and that the auto-weapon pool is down to 4 (more auto weapons could refill it later; see Ideas for Later).

### Where things stand (2026-10-10, v0.17.0 adds map events, quests, 4 weapons, 4 pickups; v0.18.0 implements the fifth list; v0.19.0 gives each hero their own main weapon)
- **v0.15.0** implements the third playtest list (above). Not played by a human yet; checklist section 3.0b in `docs/PLAYTEST.md`.

### Before that (v0.14.1, released on GitHub)
- Playtested by the owner: M1 (online, with a friend), M2 (with a friend), and a solo run of v0.11 that cleared stage 1 (incl. the Bone Warden) and reached the shop. That review produced the v0.12.0 changes.
- v0.13.0 added: level-up card previews (level + stat before -> after), the end-of-run summary screen (`RunStats` + `RunSummaryPanel`), the Necromancer (Bone Effigy) and the Witch's Hex Snare.
- **Co-op playtest (owner + one friend, v0.13.0, 2026-10-09):** "awesome, a great start". Their list became v0.14.0 (Playtest 2 changes above), plus the Compendium, Playtest Checklist, lobby Difficulty / Custom Game pages and the boss-spawn performance fix.
- **v0.14.1:** in-game updater. Friends on v0.14.1+ update with one click from the title screen; anyone older must download once by hand.
- **Not yet verified by a human:** everything new in v0.14.x (checklist section 3.0a in `docs/PLAYTEST.md`, also shown in-game). The perf fix was measured, but my PC never dropped below 120 fps even before it, so the friend's/owner's next boss fight is the real test (`--perf-log` if it still stutters). The updater's `.old` cleanup only runs from v0.14.1 on.
- **Not yet played by a human:** stages 2–3 and their bosses, Victory, Hex Snare, the Necromancer, the end-of-run screen, the shop economy, full co-op runs on v0.6+. See `docs/PLAYTEST.md`.
- **Watch item (unconfirmed bug):** in a v0.12 solo run the owner believed they died during the stage 1 boss but the stage counted as cleared. The log showed `STAGE_CLEAR` ~17s after the boss spawned and the code checks "everyone down" first, so it was likely a real (fast) kill. Since v0.13.0 the host logs `Player <id> downed` and `Boss killed by peer <id> at <t>s`; if it's reported again, read `%APPDATA%\Godotpp_userdata\GameTest\logs\godot.log` (the newest run; older runs are timestamped files).

### Next (proposed, in rough priority)
1. Co-op playtest of v0.15.0: is stage 1 beatable and stage 2–3 still a challenge, do revives feel good, metal music, the run summary pages, and the first one-click update. Then tune numbers.
2. Working title (replace "GameTest" in the title, window, and build file names).
3. Content depth: more relics/weapons with synergies (upgrades done in v0.16.0), more enemy variety per stage, boss attack variety.
4. Meta/feel: hero portraits, records/stats screen, more animation.
5. Release prep later: real audio direction, Steam or a relay for joining without port forwarding (see Ideas for Later).

## 8. Open questions

- Working title?
- Do the four character abilities feel distinct and balanced (Dash / Grave Blast / Hex Snare / Bone Effigy)?
- Enemy roster and boss designs beyond the first set (one boss per stage so far).
- Weapon, auto-weapon, and relic lists; synergy rules (none yet).
- Shop economy: first rebalance done in v0.12.0; needs a playtest.

## 9. Ideas for Later

- **More auto weapons** to refill the pickup pool (4 since v0.19.0 moved three to heroes' main weapons).
- **Cursed shrines** (offered with the v0.17.0 events, not picked): walk up to one for a gamble, e.g. more damage but faster enemies until the stage ends, or a free heal.
- **Risky bounties / team quests** (the quest options not picked in v0.17.0): quests with a cost or curse for a bigger reward, or one shared team quest chosen by vote.
- **Clients asking for a pause** ("Request pause" shown to the host), if friends miss being able to pause.
- **Intense bullet density throughout:** possibly switch from readable patterns to hardcore shmup density across the whole game.
- **Support hero:** a character whose ability or passive heals teammates or revives them faster (`CharacterStats.revive_speed` is already in place; owner idea, v0.15.0).
- **Join codes / no port forwarding at all:** a small relay or matchmaking server (short codes like `KQ7F`), or Steam invites via Steamworks ($100 app fee). Revisit if port forwarding becomes a hurdle or near release.
