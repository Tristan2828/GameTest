# Game Design Document

> Working title: TBD
> Last updated: 2026-10-08

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
- **Health:** 3 hearts, with a hitbox much smaller than the sprite. Enemy contact costs 1 heart, then ~1s of invulnerability (flashing). Dashing is also invulnerable.
- **Downed:** at 0 hearts the player is downed (can't act). Placeholder until ghosts arrive in M4.
- **Movement:** free 8-direction / analog movement.
- **Aiming:** manual 360° aim with the mouse or right stick.
- **Defense:**
  - **Dodge roll / dash:** brief invulnerability or reposition, on a cooldown.
  - **Bomb:** limited-use screen clear for enemy bullets.

### Weapons
- **Main gun:** aimed and fired manually by the player. Defined by the character.
- **Auto weapons:** gained through level-ups and pickups, fire automatically (orbitals, auras, homing shots, etc.).

### Characters
- Multiple playable characters, each with a **unique kit** (main gun, stats, unique ability).
- Encourages team composition in co-op.

## 4. Progression

### In-run
- **XP level-ups:** enemies drop **XP gems**. Any player who walks near pulls them in (magnet radius), and they fill the shared team bar. On level-up, each player picks 1 of 3 upgrades.
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
- **Art style:** Pixel art.
- Bullets must stay readable against backgrounds (high-contrast, glowing projectiles).
- Audio: synthesized placeholder sound effects (v0.7.0). Music and final sounds TBD.

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

### Milestone 3: First stage + first boss (implemented in v0.4.0; awaiting playtest)
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
- **Bomb:** 2 per stage, refilled at stage start. It clears enemy bullets within a large radius around you, damages nearby enemies, and gives brief invulnerability. Bound to Q / middle mouse / RB / Y.
- **Fair dodging online:** enemy bullet patterns are fast-forwarded on clients by the network delay, so what you dodge on your screen matches what the host checks.
- **Arena look:** dark stone floor with seeded variation, plus decorative graves and bones (no collision yet).

### Milestone 4: Multi-stage run, ghosts, coins & shop, relics, auto weapons (implemented in v0.5.0; awaiting playtest)
Decisions made by Claude while the owner was away. **Revisit in the next playtest.**
- **Run = 3 stages** in the same crypt arena (distinct stages/themes come in M5). Each stage is harder:
  - Spawn rate +35% per stage.
  - Enemy and boss HP +50% per stage.
  - Beating the stage 3 boss = **Victory**.
- **Between stages:** a **shop break**. The run keeps your team level, upgrades, relics, weapons and coins.
- **Ghosts:** a downed player becomes a ghost until the next stage.
  - Ghosts float around freely. They can't shoot, bomb or be hurt.
  - Ghosts **can still collect XP gems and coins** for the team.
  - Everyone respawns with full hearts and refilled bombs at the start of the next stage. The run ends if all players are down.
- **Coins:** enemies sometimes drop coins (10% basic, 50% Ghoul/Cultist; the boss drops a pile). First come, first served: coins go to whoever picks them up.
- **Shop:**
  - Each player sees their own 4 relic offers with prices and buys with their own coins.
  - A reroll costs 5 coins.
  - The shop closes when everyone presses Ready, or 45s after the first Ready (same pattern as level-ups).
- **Relics:** passive items with stat effects and trade-offs (e.g. Cursed Skull: +damage, −1 max heart). Each relic can be bought once.
- **Auto weapons:**
  - Found as **weapon altars** that appear twice per stage (~1:20 and ~2:40). First player to touch one takes it. Taking a weapon you already own levels it up (max level 3).
  - Three weapons to start: **Orbiting Skulls** (circle you, hurt on touch), **Seeking Bolts** (auto-fire at the nearest enemy), and **Holy Aura** (pulses damage around you).

### Milestone 5: Characters, lobby, three themed stages (implemented in v0.6.0; awaiting playtest)
The owner approved the plan; details below are Claude's defaults. **Revisit in the next playtest.**
- **Lobby:**
  - Solo/Host/Join leads to a lobby: pick a character, press Ready, and the host starts (solo starts right away).
  - After Victory or Run over, the host returns everyone to the lobby.
  - Friends joining mid-run still drop in, as the Wanderer.
- **Characters (one passive ability each):**
  - **Wanderer:** balanced. *Second Wind:* the first lethal hit each stage leaves you at 1 heart instead.
  - **Gravekeeper:** slow, 5 hearts, short-range shotgun. *Grave Ward:* starts each stage with 3 bombs, and each bomb also heals 1 heart.
  - **Hexblade Witch:** fast, 2 hearts, rapid piercing bolts. *Blink:* longer, faster-recharging dash.
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

### Future milestones (rough)
- M2 (above): A session is **timed survival** (start: 5 min, then "Stage clear"), or "Run over" if everyone is downed. Both lead to a restart.
- M3 (above): First arena stage + first boss with bullet patterns.
- M4 (above): Shop, relics, weapon pickups, ghost/respawn.
- M5: Multiple characters, multiple stages, full 15–20 min run.

## 8. Open questions

- Working title?
- Enemy roster and boss designs.
- Weapon, auto-weapon, and relic lists; synergy rules.
- Shop economy: how coins are earned, what's sold.

## 9. Ideas for Later

- **Intense bullet density throughout:** possibly switch from readable patterns to hardcore shmup density across the whole game.
- **Join codes / no port forwarding at all:** a small relay or matchmaking server (short codes like `KQ7F`), or Steam invites via Steamworks ($100 app fee). Revisit if port forwarding becomes a hurdle or near release.
