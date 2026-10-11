# Game Design Document

> Name: **Medieval Survival** (owner's choice, v0.24.0). The GitHub repo is `Tristan2828/medieval-survival` (renamed from `GameTest`). From v0.25.0 the files are `MedievalSurvival.exe` / `MedievalSurvival-<version>-windows.zip`; the save folder stays `%APPDATA%\Godot\app_userdata\GameTest`.
> Last updated: 2026-10-11 (v0.25.0)

A 2D top-down roguelite bullet-hell survivor for online co-op with friends: Vampire Survivors-style hordes, auto-firing weapons and build power fantasy, with readable, dodgeable bullet patterns. Movement is the only control (since v0.22.0; it was a twin-stick shooter before, see §7 *Auto-fire redesign*).

---

## 1. Vision

- **Pillars**
  1. **Power fantasy through builds.** Start weak, end the run with the screen full of your own attacks.
  2. **Real dodging.** Tiny hitbox, a small HP bar, readable enemy bullet patterns. Movement is the only control, so where you stand is the skill.
  3. **Better with friends.** Online co-op for 1–4 players, but solo is fully supported.
  4. **Easy to pick up.** Simple controls, short runs, friends can jump in quickly.
- **Audience:** Me and my friends; not for sale. Long-term goal is a complete game.
- **Platform:** Windows PC.

## 2. Tech

| Item | Decision |
|---|---|
| Engine | Godot 4.x |
| Language | GDScript, **statically typed** throughout |
| Development | AI-assisted coding. Keep everything text-editable and verifiable via `godot --headless` |
| Networking | Godot built-in high-level multiplayer (ENet), host-authoritative |
| Connection | Direct IP. The **host** makes the game reachable: Host Game tries UPnP to open the router port automatically, otherwise the host forwards UDP 7777 once by hand. The host gets an invite (`public IP:port`) copied to the clipboard; **friends paste it into Join Game**, no extra apps. Doesn't work if the host is behind CGNAT; fallback is a host-side tunnel such as playit.gg |
| Input | Mouse + keyboard and gamepad, both fully supported |
| Base resolution | **640x360**, integer-scaled (3x at 1080p, 4x at 1440p, 6x at 4K) |
| Tests | GUT addon, plus a headless host+client smoke test script |
| Updates | The title screen checks GitHub's latest release; **Update now** downloads the zip, swaps the running exe and restarts |

### Networking approach
- One player hosts; the host owns the true game state. Solo uses the same code with an offline peer (acts as a host with nobody connected).
- **Lobby, then drop-in:** everyone meets in the lobby (hero picks, ready-up, host's settings); friends who connect during a run drop straight into it (as Kael the Wanderer).
- Clients send one input per tick (60/s) to the host. The host simulates and sends snapshots at **30/s**.
- **Own player: predict and correct.** The client simulates its own movement (and when its main weapon fires) with the same deterministic code as the host. When a host snapshot disagrees, it corrects, smoothing small errors and snapping big ones.
- **Targeting:** each player's own computer picks its main weapon's target (`AutoAim`, from the enemies its screen shows) and sends it in its input, so the shooter's prediction and the host's attack match.
- Other players and enemies on clients: smoothed toward the latest snapshot positions.
- Enemies: host simulates; positions and HP sent in compact batches, interpolated on clients.
- Bullets: **never synced individually.** Send pattern events (`pattern id, origin, aim, seed`) and let every client simulate the bullets deterministically. Bullet position = `origin + velocity * age`.
  - Player shots spawn on receipt. Enemy and boss patterns carry the host's clock, so clients fast-forward late-arriving patterns by the network delay: what you dodge on your screen matches what the host checks.
  - Only the host deals damage. Client bullets and weapon effects are visual.
- Every change to a player's build is one **card** number announced by the host (§4); late joiners replay each player's `card_history`.
- Heavy use of object pooling for enemies, bullets, and pickups.

## 3. Core gameplay

### Format
- Movement-only roguelite (weapons fire by themselves) with runs made of **3 arena stages in sequence**.
- Each stage: **4:00 of enemy waves**, then a boss; **stage clear = boss dead**. A shop between stages. Beating the stage 3 boss = **Victory**.
- **Run length target:** 15–20 minutes.

### Stages
Each has its own floor, enemy mix, champion, boss and music (data-driven `StageDef` resources).
1. **The Crypt:** Shamblers, Bats, Ghouls, Cultists (ranged, from 2:00). Boss: the **Bone Warden** (rings, spiral, aimed fans).
2. **The Bone Marsh:** Mire Crawlers (fast swarms), Plague Spitters (slow bullet rings), Ghouls. Boss: the **Mire Hag** (sweeping bullet walls with a gap, random sprays, rings).
3. **The Burning Cathedral:** Flame Imps (fast, erratic), Fallen Paladins (tanky, aimed lines), Cultists. Boss: the **Ashen Bishop** (rotating crosses, aimed bursts, fans).
- Every boss gets faster with extra attacks below 50% HP (phase 2). Boss HP 6000, +75% per extra player.

### Threat model (hybrid)
- Hordes that swarm the player (contact damage). **Spawning:** a continuous ramp off-screen around the players, with occasional **pack surges** (a tight cluster from one direction every 35–50 s).
- Some enemy types, all champions and all bosses fire readable bullet patterns (Enter the Gungeon-like density, not hardcore shmup).
- **Stage scaling** (stage 1 / 2 / 3): enemy HP x1 / x4 / x9, boss HP x1 / x4.5 / x12, spawn rate x1 / x1.4 / x1.8, enemy damage x1 / x1.3 / x1.6; stages 2 and 3 start their spawn ramp 45 s / 90 s in. Auto weapons grow x1 / x1.5 / x2.25 to keep up (`AUTO_DAMAGE_BY_DEPTH`).
- **Boss fights:** when the boss arrives every regular enemy crumbles away (no drops; awake champions and the Grave Robber stay) and the boss brings an **escort** of 12 stage enemies (+6 per extra player). Then the horde trickles in at 25% without growing, with at most 40 + 25 per player regular enemies alive. (Playtest 7: the 4-player boss fight was "way too much stuff and can't get to the boss".)

### Player
- **Controls:** movement only (WASD / arrows / left stick). Weapons fire by themselves; there is no aim, fire or ability button. Heroes face the way they last moved. The mouse cursor hides during play and comes back for level-up cards, the shop and menus.
- **Health:** an **HP bar** (Kael 100, Morwen 70, Vesper 90, Mortimer 150), with a hitbox much smaller than the sprite. Touching enemies drains their contact damage (all of them together) every 0.5 s with no safe time, so being surrounded is deadly. An enemy bullet takes its damage and then bullets pass through you for 0.5 s (`hit_invulnerability`). Damage: Shambler 5, Bat 3, Ghoul 8, Cultist / Imp / Crawler 4, Spitter 5, Paladin 8, champions 10, bosses 15 to touch; bullets 15, champions 18, bosses 20 (times the stage scaling).
- **Healing:** Recovery (HP per second: Mortimer's perk, Ghoul Blood, Bloodstone), Heart pickups (30% of max HP), every team level-up (5%), finished rituals (25%), Grave Blast (10%), Vampire Fang (1 HP per 3 kills), and full HP at every stage start.
- **Downed:** at 0 HP the player is downed and lies in a revive circle until a teammate revives them (§5).

### Weapons
- **Main weapon:** each hero has their own, which picks its own target (`AutoAim`) and has levels 2–6 plus an evolution (§4).
  - Kael: **Bolt Gun** at the nearest enemy.
  - Mortimer: **Reaper's Scythe** thrown the way he faces and back, **plus one behind him** (with only the front throw, running from a crowd meant facing away from it; his boss fights took 4+ minutes).
  - Morwen: **Chain Lightning** at a random enemy nearby, jumping on; with a boss in reach it goes for the boss half the time, and a jump with nobody new to reach strikes the last enemy again for 60%.
  - Vesper: **Bone Spears**, a row rising toward a random enemy nearby after a short warning.
  - Targeting reach: bolts as far as they fly (~384 px); the scythe throws with an enemy within 1.5x its reach; lightning and spears pick from enemies within their reach. Nothing in reach: no attack.
- **Auto weapons:** 11, offered on level-up cards, altars and champion chests, up to level 5: Orbiting Skulls, Seeking Bolts, Holy Aura, Hellfire Trail, Grave Blast, Hex Snare, Bone Effigy, Storm Lantern, Bone Cleaver, Grave Spikes (auto versions of the heroes' weapons) and Spirit Daggers (thrown ahead and behind). Four of them evolve (§4).
  - **Grave Blast** goes off when an enemy is close: damage around you, clears enemy bullets within 150 px, heals 10%, 1 s safe. **Hex Snare** binds the biggest nearby crowd for 3 s (+50% damage taken; bosses aren't bound). **Bone Effigy** lures regular enemies within 150 px for 4 s, then bursts. Hex Snare and the Effigy go at the middle of the biggest crowd within reach (`AutoWeapons.crowd_center`). Arcane Focus and Holy Water also make the Snare and Effigy last longer (owner: keep it; their cards say so).

### Characters
- Each hero has a **unique kit**: main weapon with its own level steps, stats (HP, speed) and a small **perk**: Kael **Light Feet** (moves 10% faster), Mortimer **Undying** (regenerates 0.5 HP/s), Morwen **Hexborn** (+10% crit chance), Vesper **Grave Harvest** (her kills burst for 8 damage).
- Names (owner's pick): **Kael** the Wanderer, **Mortimer** the Gravekeeper, **Morwen** the Hexblade Witch, **Vesper** the Necromancer (`CharacterStats.hero_name`). The name leads in the UI; logs and reports use the class.
- **Unlocks:** you start with Kael only; winning a full run as a hero unlocks the next (§4 Meta).
- The hero picker has a **Watch** demo per hero (`HeroDemo`): a scripted ~8 s loop drawn in code with the hero's real numbers, their weapon for ~4 s, then a dodge through a bullet fan. Local only.

## 4. Progression

### In-run
- **XP:** enemies drop **XP gems**. Any player who walks near pulls them in (magnet radius), and they fill the shared team bar. Level n costs 10 + 9·(n−1) XP, +1.5·(n−15)² from level 15 on (so teams stop snowballing through stages 2–3), times +40% per extra player (spawns grow 60%, so bigger teams level slightly faster).
- **Level-up cards (`Cards`):** each player picks 1 of 3. A card is a new weapon, a weapon level (the main weapon too) or a passive level. Cards show level pips (owned / this pick / left to max) and the real stat before -> after. Weights: levels of what you carry x2, the main weapon's next level x3, anything new x1. Nothing left to offer: **Blood Draught** (heal 40, only when hurt) and **Coin Pouch** (+20 coins). Everyone starts a run with 1 card **reroll**; the shop sells more.
- **Slots:** 6 weapons (the main weapon is one) and 6 passives. Auto weapons go to level 5, main weapons to level 6, evolutions have one level.
- **Main weapon levels 2–6** (`CharacterStats.main_levels`; each also adds ~15% of the hero's starting damage): Kael: Extra Bolt, Piercing Bolts, Ricochet, Extra Bolt, Hunting Bolts. Mortimer: Twin Scythes, Heavy Blade, Long Reach, Grim Harvest, Twin Scythes. Morwen: Forked Lightning, Long Arc, Conductor, Split Bolt, Forked Lightning. Vesper: Longer Row, Wide Spikes, Quick Rise, Splinters, Longer Row.
- **12 passives, 5 levels each** (`Upgrade.passive`): Sharpened Edge (+20% of the hero's starting damage, all weapons; a share rather than a flat number so every hero gains alike), Quick Hands (all weapons 10% faster), Fleet Foot (+8% speed), Heart Container (+20 HP), Grave Magnet (+25% pickup range), Steady Nerves (+0.1 s bullet safety), Arcane Focus (+15% auto weapon damage and Hex Snare / Bone Effigy time), Keen Edge (+8% main weapon crit), Corpse Blast (kills burst for 8 in 32 px), Giant Slayer (+15% vs bosses), Executioner (+15% vs wounded), Ghoul Blood (+0.4 HP/s). Damage bonuses and crits are rolled by the host (`HitBonus`).
- **Evolutions (8):** max the weapon, carry its passive (any level), then open a champion's chest (the opener) or beat a boss (everyone who's ready). Bolt Gun + Quick Hands = **Storm Bolter**; Reaper's Scythe + Heart Container = **Harvester**; Chain Lightning + Keen Edge = **Tempest**; Bone Spears + Corpse Blast = **Bone Cathedral**; Orbiting Skulls + Arcane Focus = **Death Spiral**; Seeking Bolts + Quick Hands = **Soul Barrage**; Holy Aura + Ghoul Blood = **Sanctuary**; Hellfire Trail + Fleet Foot = **Inferno Path**. Listed in the Game Guide.
- **Altars** (at 1:20 and 2:40; 1 / 2 / 2 / 3 at a time for 1–4 players, each near a different player): the weapon on the altar (new, or a level), else a level of a weapon you carry, else 10 coins. First touch takes it.
- **Power-ups** (1% of regular kills, at most one per 18 s, plus one from every champion): Heart (30% HP; 40% of drops), Soul Magnet (every XP gem flies to you; 25%), Holy Bomb (400 damage x stage HP growth to regular enemies within 260 px, clears enemy bullets there; 15%), Frost Hourglass (regular enemies and enemy bullets freeze for 4 s; frozen bullets still hurt; 20%).
- **Coins:** enemies sometimes drop them (4% basic, 20% tougher enemies, x0.75 / 0.25 / 0.25 by stage), plus events and a boss bounty for everyone (25, +15 per stage).
- **Shop between stages:** each player sees their own 4 relic offers (45–100 coins; one of each per player, no slot limit; some have drawbacks, e.g. Cursed Skull and Iron Boots) and buys with their own coins. Relic rerolls cost 10, then +10 each within the same shop; card rerolls cost 15. It closes when everyone presses Ready, or 45 s after the first Ready. `co_op_only` relics (Mourner's Bell) aren't offered solo.
- **Quests:** in the shop each player picks 1 of 3 for the next stage (free; a random one if they don't pick; changeable until Ready). Done during that stage = paid at once (coins or a free relic). Champion Hunter (45 coins), Ritualist (relic), Thief Catcher (35), Slayer: 1000 kills (40), Untouchable: 45 s without losing HP (relic), Gold Digger: 80 coins (relic), Arsenal: 12000 auto weapon damage (45), Scavenger: 2 power-ups (35), Guardian: revive a teammate (relic, co-op only).

### Map events (`MapEvents`, host-run, synced as a small snapshot)
- **Champion lair** (one per stage, away from the middle): a dark statue of the stage's champion (a crowned, bigger, recolored stage enemy that shoots back) that wakes when a player comes within 150 px. 1200–1600 HP in stage 1, +60% per extra player. Drops coins, a power-up and a **chest**: the first player to touch it gets a ready evolution, else a random weapon or weapon level.
- **Ritual circle** (one at the start, one pop-up at 2:20 that fades after 50 s if unused): stand inside for 15 s to fill it (+50% speed per extra player inside; it drains over 30 s when empty) while waves of stage enemies come. Full: XP worth 1.5 levels and 25% HP for everyone inside.
- **Grave Robber** (pop-ups at 1:10 and 3:20): a fast thief that runs from the nearest player, dropping coins. Caught within 20 s: 14 coins.
- Pop-ups stop once the boss arrives. Events show as edge arrows with their icon, minimap shapes and toasts with a bell.

### Meta
- **Embers (owner decision, v0.21.0: a very light permanent stat shop):** every finished run earns Embers on your own PC (`user://embers.cfg`); the title menu's **Ember Shrine** sells small permanent boosts. Owner choices: a tiny stat shop, a fully upgraded hero only ~5–10% stronger, about 100 runs to buy everything, earned from progress, a free **Refund all**, each player can switch their own boosts off. Records scores ignore boosts.
  - Earning: 8 per boss killed + 6 for a victory + 1 per 100 of your kills (max 10), times the run's score multiplier (clamped 0.25–2). A victory is ~40, dying in stage 2 ~15.
  - Boosts (3 ranks each, prices 50 / 100 / 175, ~1950 in total): **Keen Eye** +2% main-weapon crit chance, **Swiftness** +2% move speed, **Focus** −3% auto weapon cooldowns, **Greed** +5% chance a coin is worth 1 more, **Reach** +6% pickup radius, **Resolve** +0.05 s of bullet safety. (No +% XP: XP is shared.)
  - Co-op: everyone brings their own boosts (sent to the host on connecting, applied through the spawn data). The host can turn them off for everyone in Custom Game.
- **Hero unlocks (owner request, after v0.24.0):** a new player has Kael. **Winning a full run** (any difficulty, not a single-stage custom game) as a hero unlocks the next in `Characters.ALL` order: Kael -> Mortimer -> Morwen -> Vesper (`user://unlocks.cfg`, `HeroUnlocks`). In co-op each player picks from their own unlocks, and a team win counts for everyone, downed or not. Locked heroes show dark in the picker with "Win a run as X to unlock" (their Watch demo still plays); the run summary shows "NEW HERO: ...". Mid-run joiners are Kael; autopilot, headless runs and `--character` ignore locks and unlock nothing.
- **Records:** each PC keeps its best runs (top 10 per hero, `user://records.cfg`) with a score: 10 per kill + 1 per 10 damage + 3000 per boss + 5000 for a victory, times the difficulty factor. Bragging rights only.

### Run setup (lobby, host only; saved on the host's PC, clients see it read-only)
- **Difficulty:** sliders for enemy health, boss health, enemy count, XP gain, coin drops (25%–300%) and bonus HP (−40..+60). Presets Easy / Normal / Hard; a **Custom** chip lights when the sliders match none.
- **Custom Game:** full run or a **single stage** on a chosen map (first-stage toughness), wave length (1–10 min), boss on/off (off = survive the timer), starting level-ups (0–10), **Full arsenal** (5 random weapons), soundtrack, Ember boosts on/off.

## 5. Co-op rules

| Topic | Rule |
|---|---|
| Players | 1–4 |
| Friendly fire | Off |
| XP | **Shared** team XP bar; each player picks their **own** card |
| Level-up flow | **Pauses for everyone.** All players choose at once. After the first pick the rest have a **30 s countdown**; anyone who hasn't picked gets a random card. Several level-ups are chosen one after another. While waiting your pick stays highlighted and you can **pick another card instead**. Cards are picked with a click, A, Enter or the **left trigger** (one-handed gamepad play). Online, play resumes after a **"3, 2, 1"** during which your hero gets a ring and a "YOU" arrow; solo resumes at once |
| Loot (weapons, coins, power-ups, chests) | **Shared world drops, first come first served** (relics are bought with your own coins). Downed players don't pick up coins or power-ups (they still pull XP gems) |
| Death | **Downed and revivable** (owner request, v0.15.0). At 0 HP you lie in a 30 px circle. A teammate standing in it revives you in **4 s** (two helpers: 2 s; Mourner's Bell is faster); you get up with half your max HP and 2 s of safety. Nobody in the circle: progress drains slowly. Not revived: you get up at the next stage. Your screen follows a living teammate after 1.5 s (Space / Enter / click / A / RB cycles). Teammates see a pulsing edge arrow with a "+", a blinking "+" on the minimap and a "Red is down!" line. Run ends if everyone is down at once |
| Difficulty scaling | **More enemies, same toughness:** spawn rate +60% per extra player; regular enemy HP stays the same; bosses +75% and champions +60% HP per extra player |
| Pause | Solo: the Esc menu pauses. Online: nobody can pause; the Esc menu only blocks your own controls. (A host pause in v0.17.0 desynced and was removed) |
| Names | Each player types a display name on the title menu (saved on their PC, max 12 characters). Without one you're called by your slot color ("Red"). Shown on lobby cards, over teammates' heroes, on edge arrows, in toasts and on the run summary |
| Edge arrows | Only map events and downed teammates; healthy teammates are on the minimap (owner: arrows to everyone were clutter) |
| Map events and quests | Events are shared (anyone can wake a champion, hold a ritual, catch a thief); a chest goes to whoever touches it first. Quests are personal |

## 6. Art & audio

- **Setting:** Dark fantasy (undead hordes, demons, dark magic).
- **Art style:** Pixel art. Sprites are text grids with a shared palette (`src/art/pixel_art.gd`); bosses drawn at 2x; player sprites recolored per player. Floor props are small, faded and outline-free so they never compete with monsters (owner, v0.20.0).
- Bullets must stay readable against backgrounds (high-contrast, glowing projectiles; the player's hitbox dot is always visible).
- **Audio:** sound effects come from a small code synth (filters, layering, echo). Music is 5 classic chiptune tracks (menu, Crypt, Marsh, Cathedral, boss) plus 4 metal ones (distorted power-chord riffs; owner request, v0.15.0), written as text scores in `Tracks`. The host picks Classic / Metal / Metal boss fights / Shuffle in Custom Game; the menu stays classic.
- **Real art and audio files (owner decision, 2026-10-11):** the text sprites and synth are being replaced by files a few at a time: PNG in `assets/art/` (one per frame, named like the sprites), WAV in `assets/audio/sfx/`, looping OGG in `assets/audio/music/`. Any ID without a file keeps its text sprite or synth sound. What each asset should be: `docs/ART_BRIEF.md` / `docs/AUDIO_BRIEF.md`; status: `assets.yaml`, kept with the [gamekit](https://github.com/Tristan2828/gamekit) tools. Levels: sound effects peak at −3 dBFS, music at −16 LUFS. So far: the hero sprites, and the 9 music tracks (rendered from today's scores by `tools/render_music.gd`, played 4 dB down, `Music.FILE_VOLUME_DB`, so the mix stays as it was).

## 7. History and status

### Where things stand (2026-10-11)
- **Released:** v0.25.0 (the Playtest 8 changes below and the first art/audio files). It is the first with `MedievalSurvival` file names and the first after the repo rename: **v0.24.0 and older can't update to it** (their updater only trusts links under the old repo name), so friends download it once by hand; later versions update in place.
- **Played by humans:** M1 and M2 online with a friend; a solo v0.11 run; two-player co-op runs of v0.13 and v0.14; a full 4-player run of v0.23.0 ("It was a fun time!").
- **Not yet played:** v0.24.0 and v0.25.0 (checklist 3.0n / 3.0o in `docs/PLAYTEST.md`), and whatever the 4-player run didn't get to from v0.22–v0.23. Balance numbers since v0.18.0 come from the solo invincible autopilot (it picks cards at random and dodges badly), so they compare stages and heroes, not real difficulty.
- Logs: `%APPDATA%\Godot\app_userdata\GameTest\logs\godot.log` (newest run; older runs are timestamped). The host logs downs and boss kills.

### Releases
Details: `docs/releases/v<version>.md` and the git history. "Claude's call" items are defaults to revisit in a playtest (`docs/PLAYTEST.md` §4).
- **M1 (2026-10-09):** online movement and shooting; internet playtest felt smooth.
- **M2:** hordes, XP gems, shared level, networked level-up pause. Playtested: fun.
- **M3:** stage flow (waves then boss), the Bone Warden, Cultists, enemy bullet fast-forward on clients, seeded floors.
- **M4:** 3 stages, shop and relics, coins, altars with auto weapons.
- **M5:** lobby (hero pick, ready-up), four characters, three themed stages, Difficulty and Custom Game pages.
- **v0.7–v0.11 (Claude's passes):** pause menu and settings, particles and screen shake, pixel-art sprites, baked floors, synthesized music and sounds, one UI theme, animations.
- **v0.12.0 (playtest 1):** better gems, minimap, pixel font, fewer coins, hero abilities (since removed).
- **v0.13.0:** 4th hero, run summary.
- **v0.14.0 (playtest 2):** fewer level-ups, pick highlight and level pips, weapon icons, resume countdown, Game Guide and Playtest Checklist on the title menu, Difficulty / Custom Game pages, a boss-fight frame-rate fix (one baked texture per bullet glow instead of `draw_circle`). v0.14.1: in-game updater.
- **v0.15.0 (playtest 3):** cheaper levels again (v0.14 made stage 1 unbeatable), revives instead of ghosts, run summary stars and Weapons page, Records, metal soundtrack.
- **v0.16.0:** in-game feedback (Discord `#feedback` webhook baked into builds from a git-ignored file; owner chose Discord over GitHub issues: no accounts, screenshots attach); 16 more upgrades (since folded into passives).
- **v0.17.0 (playtest 4):** map events, quests, 4 auto weapons, power-ups, a host pause (removed in v0.18.0). Owner's Q&A picks: champion lairs, rituals and thieves (not cursed shrines), free personal quests.
- **v0.18.0 (playtest 5):** display names, Exit Game, lobby party page + hero picker, run summary Highlights and scrolling, minimap shapes, edge arrows only for events and downed teammates, "Compendium" renamed "Game Guide" (plain words), stages 2–3 much harder (owner: "super easy"), point-blank hits and chest pickup radius fixed.
- **v0.19.0:** a main weapon per hero (scythe, lightning and spears moved from the auto-weapon pool).
- **v0.20.0 (playtest 6):** quieter floor props, hero names, Watch demos. v0.20.1: 4-player performance pass.
- **v0.21.0:** Embers and the Ember Shrine. v0.21.1: exe name, version and icon; Windows download warning help.
- **v0.22.0 / v0.22.1:** auto-fire redesign step 1 and a balance pass (below).
- **v0.23.0:** auto-fire redesign step 2 (below).
- **v0.24.0 (playtest 7, after the 4-player run):** boss sweep + escort and a capped boss-fight horde; rituals fill faster together; knife-shaped Spirit Daggers; a "YOU" marker during the countdown; 16x16 card icons; cards that fit their text; changing your pick; left trigger picks; run summary rebuild (fixed-width cards, difficulty chip, Stages page); Join Game dialog; Difficulty page Custom chip; the name Medieval Survival. Claude's calls: the boss-fight numbers, no XP from the swept horde, +50% ritual speed per player, the marker and icon art, the run summary's contents.

### Auto-fire redesign (owner decision, 2026-10-10)
**Why:** aiming and dodging fought over the same hands: the game became either "aim well" or "dodge well", and builds couldn't take over aiming the way they do in Vampire Survivors. New direction: a close Vampire Survivors-style game with our own flavor (dark fantasy, co-op, real bullet patterns, stages + bosses + shop). The owner chose to finish both steps before the next playtest.
- **Step 1 (v0.22.0):** movement only; main weapons target themselves; the hero abilities became auto weapons anyone can find (Dash removed); perks instead of abilities; an HP bar instead of hearts. Claude's calls: Mortimer's back throw, the reach rules, every HP and damage number, the perks, Ghoul Blood and Bloodstone. Plan change: the client picks its own target (it reuses the tested shot prediction).
- **Balance pass (v0.22.1, autopilot only):** Sharpened Edge became a share of each hero's own damage (flat +4 was +40% for Kael, +13% for Mortimer); Morwen's boss focus; auto weapons much stronger (together they did under 5% of the damage); Corpse Blast weaker; fewer coins and pricier relics (runs ended with 500–1000 unspent); rarer power-ups; rituals worth more; co-op gets more altars; harder quest targets. Added the `[balance-detail]` / `[balance-picks]` report lines.
- **Step 2 (v0.23.0):** level-up cards offer weapons, weapon levels and passives; 6 + 6 slots; the old weapon-only upgrades became main weapon levels; 25 upgrades merged into 12 passives (Shadow Step, Glass Cannon, Reckless Haste, Long Shot, Swift Bolts retired; the shop's Cursed Skull and Iron Boots are the trade-offs now); 8 evolutions; 11 auto weapons; card rerolls. Claude's calls: card weights, passive numbers, evolution ingredients, Spirit Daggers, damage tuning so main weapons still do ~20–50% of a hero's damage in stage 3.

### Playtest 8 changes (v0.25.0, owner's eighth list)
1. **Update button didn't work for some people:** the repo rename from `GameTest` to `medieval-survival` made GitHub's API answer with download links under the new name, which the updater didn't trust. `ReleaseInfo` now trusts both names. Also sturdier: when the API refuses (60 checks an hour per connection) it falls back to the release page's redirect (`ReleaseInfo.from_tag_url`); a failed check shows "Check again"; it refuses to update when running from inside the zip or without write access; a locked `.old` file gets another name; downloads run on a thread; if Windows won't start the new exe, the menu says to restart.
2. **Hellfire Trail more muted:** about a quarter of the glow; darker, see-through flames.
3. **Opened chests stayed on screen** (host and solo): `MapEvents` stopped redrawing when the last event went. Now it redraws once more.
4. **Hero unlocks** (§4 Meta). Owner choices: a won full run, own unlocks only in co-op.

Claude's calls: a single-stage custom game doesn't unlock, easier difficulties do; a downed player still gets the unlock when the team wins; how much Hellfire is muted.

### Open code items (from the 2026-10-10 code review)
None left.

Done after v0.25.0: the dead code, unused sounds and sprites and pre-card names are gone, and the game stops its audio before quitting (`Main.quit_game`), so the online smoke test no longer fails on "resources still in use at exit". Arcane Focus and Holy Water keep lengthening Hex Snare and Bone Effigy (owner), and their cards now say so. Left as is: the lobby's per-frame label refresh (cheap) and `ArenaAbilities.Effigy.source`'s default (always overwritten). `src/arena/arena.gd` was split from ~2300 to ~1500 lines: map event and power-up rewards (`ArenaRewards`), quests (`ArenaQuests`), Grave Blast / Hex Snare / Bone Effigy and Corpse Blast (`ArenaAbilities`), the `[balance]` lines and stage rows (`BalanceLog`) and the HUD / minimap feed (`ArenaHudFeed`) are child nodes of the arena with their own RPCs; nothing in the game changed. `src/ui/run_summary_panel.gd` was split the same way (~1100 to ~400 lines): `SummaryPlayerCards` (Overview, Weapons), `SummaryTeamPages` (Stages, Highlights), `SummaryStyle` (colors, widgets), `SummaryBanner`, `BossTrophy`, `SummaryParticles`.

### Next (proposed, in rough priority)
1. **Playtest** of v0.25.0 with friends, then tune numbers.
2. **More boss and enemy variety** (`arena.gd` is split, so it can start). Two possible bosses per stage, more attacks with clear warnings, an elite enemy or two per stage that changes how you move (chargers, ground hazards). Mostly `StageDef` / `BossStep` data plus a few new shot patterns and behaviours.
3. **Easier joining: parked (owner, 2026-10-11).** Direct IP invites stay. No Steam and no paid server; if hosting ever happens, noray join codes on the owner's home lab is the plan. Options, costs and the plan: `docs/EASIER_JOINING.md`.
4. **Real art and audio files** (§6): more sprites (common enemies next); new, longer music (60–120 s loops, `docs/AUDIO_BRIEF.md`).
5. Meta/feel: hero portraits, more animation.

## 8. Open questions

- Hero names: picked by the owner from Claude's suggestions; confirm with friends.
- Auto-fire: do the targeting rules feel fair, is the HP bar too forgiving or too harsh, do heroes still feel different with perks?
- Enemy roster and boss designs beyond the first set (one boss per stage so far).
- Synergies beyond the 8 evolutions; more weapons and relics.
- Shop economy: needs a playtest since v0.22.1's cuts.

## 9. Ideas for Later

### After 1.0 (owner's list, 2026-10-11)
- **Announcer voices:** a Halo-style announcer (e.g. "Game over"), and an arena announcer for evolutions, the Grave Robber, game over and other big moments.
- **More and better metal music** (the owner listed it twice; `Tracks.SOUNDTRACKS`).
- **AI-generated art and music** to replace the text sprites and synth scores (§6).
- **Tags on the Playtest Checklist**, e.g. to filter questions by topic.
- **More heroes:** Priest, Knight, Joker, Executioner, Barbarian, Wizard, Butcher, Minotaur. They'd join the unlock chain (§4 Meta).

### Other ideas
- **Cursed shrines** (offered with the v0.17.0 events, not picked): a gamble, e.g. more damage but faster enemies until the stage ends, or a free heal.
- **Risky bounties / team quests** (not picked in v0.17.0): quests with a cost for a bigger reward, or one shared team quest chosen by vote.
- **Clients asking for a pause** ("Request pause" shown to the host), if friends miss pausing.
- **Intense bullet density throughout:** hardcore shmup density instead of readable patterns.
- **Support hero** that heals teammates or revives faster (`CharacterStats.revive_speed` exists; owner idea, v0.15.0).
- **Join codes / no port forwarding** (parked, see Next 3 and `docs/EASIER_JOINING.md`).
