# Game Design Document

> Working title: TBD
> Last updated: 2026-10-09

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
- **Downed:** at 0 hearts the player is downed (can't act). Placeholder until ghosts arrive in M4.
- **Movement:** free 8-direction / analog movement.
- **Aiming:** manual 360° aim with the mouse or right stick.
- **Defense:**
  - **One character ability** on one button, on a cooldown (owner decision after the first playtest; replaces the separate dash and bomb). Dash and a bomb-like blast are abilities of specific characters.

### Weapons
- **Main gun:** aimed and fired manually by the player. Defined by the character.
- **Auto weapons:** gained through level-ups and pickups, fire automatically (orbitals, auras, homing shots, etc.).

### Characters
- Multiple playable characters, each with a **unique kit** (main gun, stats, unique ability).
- Encourages team composition in co-op.

## 4. Progression

### In-run
- **XP level-ups:** enemies drop **XP gems**. Any player who walks near pulls them in (magnet radius), and they fill the shared team bar. On level-up, each player picks 1 of 3 upgrades. Each card shows its current level (and max) and the player's real stat before -> after taking it.
  - M2 upgrades are **stat upgrades only** (damage, fire rate, move speed, max hearts, extra bolt, pierce, pickup radius, dash cooldown, heal). Auto weapons come later.
- **Weapon pickups:** new auto weapons found during stages.
- **Passive items / relics:** stat boosts and synergies.
- **Shop between stages:** spend coins on items.

### Meta
- **None.** Each run stands alone, with no unlocks or permanent upgrades.

## 5. Co-op rules

| Topic | Rule |
|---|---|
| Players | 1–4 |
| Friendly fire | Off |
| XP | **Shared** team XP bar; each player picks their **own** upgrade |
| Level-up flow | **Pauses for everyone.** Since XP is shared, all players level up at once and choose simultaneously. The pause waits until someone picks, then the rest have a **30s countdown**. It resumes early once everyone has picked, and anyone who hasn't picked when time runs out gets a random upgrade. Several level-ups at once are chosen one after another |
| Loot (weapons, relics, coins) | **Shared world drops, first come first served** |
| Death | Player becomes a **ghost until the next stage** and then respawns. Ghosts can move and collect gems/coins but can't shoot or be hurt. Run ends if all players are dead |
| Difficulty scaling | **More enemies, same toughness:** spawn rate rises with player count (start: +60% per extra player). Enemy HP stays the same. Tune in playtests |

## 6. Art & audio

- **Setting:** Dark fantasy (undead hordes, demons, dark magic).
- **Art style:** Pixel art. Sprites are text grids with a shared palette (`src/art/pixel_art.gd`).
- Bullets must stay readable against backgrounds (high-contrast, glowing projectiles).
- Audio: everything is synthesized in code from text (no audio files). Sound effects use a small synth with filters, layering and echo; music is five looping chiptune-style tracks written as text scores (menu, Crypt, Marsh, Cathedral, boss). Final audio direction TBD after playtesting.

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
  - Spawn rate +35% per stage.
  - Enemy and boss HP +50% per stage.
  - Beating the stage 3 boss = **Victory**.
- **Between stages:** a **shop break**. The run keeps your team level, upgrades, relics, weapons and coins.
- **Ghosts:** a downed player becomes a ghost until the next stage.
  - Ghosts float around freely. They can't shoot, use abilities or be hurt.
  - Ghosts **can still collect XP gems and coins** for the team.
  - Everyone respawns with full hearts and a ready ability at the start of the next stage. The run ends if all players are down.
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
- **Characters (one passive ability each):**
  - **Wanderer:** balanced. Ability **Dash** (0.8s): quick dash, can't be hit while dashing.
  - **Gravekeeper:** slow, 5 hearts, short-range shotgun. Ability **Grave Blast** (14s): clears nearby enemy bullets, damages enemies around you, heals 1 heart.
  - **Hexblade Witch:** fast, 2 hearts, rapid piercing bolts. Ability **Blink** (2.5s): instant short teleport, briefly untouchable.
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

### Where things stand (2026-10-09, v0.12.0)
- Playtested by the owner: M1 (online, with a friend), M2 (with a friend), and a solo run of v0.11 that cleared stage 1 (incl. the Bone Warden) and reached the shop. That review produced the v0.12.0 changes.
- **Not yet played by a human:** stages 2–3 and their bosses, Victory, the reworked abilities and shop economy, full co-op runs on v0.6+. See `docs/PLAYTEST.md`.

### Next (proposed, in rough priority)
1. Full co-op playtest of v0.12.0 (everything above), then tune numbers.
2. Working title (replace "GameTest" in the title, window, and build file names).
3. Content depth: more upgrades/relics/weapons with synergies, more enemy variety per stage, boss attack variety.
4. Meta/feel: hero portraits, records/stats screen, more animation.
5. Release prep later: real audio direction, Steam or a relay for joining without port forwarding (see Ideas for Later).

## 8. Open questions

- Working title?
- Do the three character abilities feel distinct and balanced (Dash / Grave Blast / Blink)? More characters later?
- Enemy roster and boss designs beyond the first set (one boss per stage so far).
- Weapon, auto-weapon, and relic lists; synergy rules (none yet).
- Shop economy: first rebalance done in v0.12.0; needs a playtest.

## 9. Ideas for Later

- **Intense bullet density throughout:** possibly switch from readable patterns to hardcore shmup density across the whole game.
- **Join codes / no port forwarding at all:** a small relay or matchmaking server (short codes like `KQ7F`), or Steam invites via Steamworks ($100 app fee). Revisit if port forwarding becomes a hurdle or near release.
