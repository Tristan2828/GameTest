# CLAUDE.md

Online co-op (1–4 players) twin-stick roguelite bullet-hell shooter, dark fantasy pixel art. **Read `DESIGN.md` before starting work.** It is the source of truth for game design decisions. Update it when a design decision changes or an open question gets answered. **`docs/PLAYTEST.md`** is the human playtest checklist; keep it current when adding features or changing what needs human judgment. The game ships it and shows it as the title menu's Playtest Checklist (`PlaytestDoc`): only `### Heading` sections with `- [ ] question` lines are read, indented lines (Tune hints) are skipped, so keep that format.

## Context
- The owner is new to Godot and game dev; AI writes most of the code. Explain engine concepts briefly when introducing them, and prefer simple, readable solutions.
- Target: Windows PC only. Input: mouse + keyboard and gamepad, both first-class.
- Current state (v0.14.0): Milestones 1–5 plus polish, art, audio, UI and animation passes are done; v0.13.0 added a 4th character, unique abilities and the end-of-run summary; v0.14.0 implements the first co-op playtest's requests (level-up pacing, resume countdown, weapon icons, teammate arrows). See `DESIGN.md` §7 for what's been playtested and what hasn't.

## Engine & language rules
- **Godot 4.x only.** Never use Godot 3 syntax or APIs (e.g. use `@export`, `@onready`, `super()`, `CharacterBody2D`, `velocity` property + `move_and_slide()` with no args, `signal.connect(callable)`, `@rpc`, `FileAccess`, `Tween` via `create_tween()`).
- When unsure about a Godot API, look up current Godot 4 docs rather than guessing.
- **Statically typed GDScript everywhere:** typed variables, parameters, and return types (`func take_damage(amount: int) -> void:`). `untyped_declaration` is an error in project settings, so type `for` loop variables too (`for i: int in n:`).
- Keep the project fully text-editable: scenes in `.tscn`, data in `.tres`, and art, fonts and audio as text (see below). If a step truly requires the editor, say so explicitly.
- Pixel art: nearest-neighbor texture filtering, integer scaling (640x360 base resolution).

## Multiplayer rules
- Godot built-in high-level multiplayer (ENet), direct IP. **Host-authoritative.** The host forwards UDP 7777 (UPnP is tried automatically); friends paste an `IP:port` invite.
- Clients send input; the host simulates and syncs state. Your own movement (including Dash) is client-predicted by running the same `PlayerMotor` code.
- Never sync bullets individually: send pattern events (pattern id, origin, aim, seed, host time) and simulate deterministically on each peer.
- Pool enemies, bullets, and pickups.
- Every gameplay feature must work in solo **and** online co-op. Design for networking from the start; don't bolt it on later.
- RPC channels: 0 = reliable events, 1 = host snapshots, 2 = client inputs. The host only sends to peers in `_ready_peers` (scene loaded).
- Registries whose index is a network id are **append only**: `EnemyTypes.ALL`, `ShotPatterns.Id`, `Upgrades.ALL`, `Relics.ALL`, `AutoWeapons.ALL`, `Characters.ALL`, `Arena.Phase`, `CharacterStats.Ability`, `Upgrade.Stat` (also stored as numbers in `.tres` files).

## Verification
- Godot 4.7.2 is **not on PATH**. Use the full path to the console build:
  `& "C:\Code Tools\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . <args>`
  (`Godot_v4.7.2-stable_win64.exe` in the same folder is the GUI editor.)
- **Tests:** `pwsh tools/run_tests.ps1` (GUT 9.7.1 in `addons/gut`). Don't call GUT directly: it silently skips test files that fail to parse and still says "All tests passed"; the wrapper catches that. It also runs `--import` first, which is needed after adding a `class_name` script.
- **Online smoke test:** `pwsh tools/net_smoke_test.ps1` starts a headless host and client on autopilot (through the lobby) and checks they connected and the client's shots damaged enemies on the host. Run it after any networking change. The client plays the Wanderer; `-ClientCharacter <0-3>` tests another (the Gravekeeper needs `-Seconds 30`: short range).
- **Build:** `pwsh tools/build.ps1` writes `builds/windows/GameTest.exe` (one file) and `builds/GameTest-<version>-windows.zip` (with `tools/README-friends.txt`). It stamps `build_info.cfg` (version, commit, date; git-ignored, included in the export) so the title screen shows the exact build. Bump `config/version` in `project.godot` for each build you send to friends. Needs the 4.7.2 export templates in `%APPDATA%\Godot\export_templates\4.7.2.stable\` (Windows x86_64 only are installed).
- **Release (playtest builds for friends):** public repo `Tristan2828/GameTest`. Bump `config/version`, optionally write `docs/releases/v<version>.md` (highlights / what to test), commit and push `main`, then `pwsh tools/release.ps1` (`-DryRun` previews the notes). Full guide incl. Discord setup: `docs/RELEASING.md`. It builds, then `gh release create v<version>` with the zip. Publishing triggers `.github/workflows/discord-release.yml`, which posts to Discord `#builds` using the repo secret `DISCORD_BUILDS_WEBHOOK`. Never put webhook URLs in the repo. Commits use the GitHub noreply email (set in the repo's git config).
- **Seeing visuals:** headless runs can't render. Launch the real game in a window with `--screenshot-dir=<folder>` and read the PNGs. `-s some_script.gd` runs do NOT get autoloads, so game scenes can't run that way (pure classes like `PixelArt` and `PixelFont` can).
- **Launch flags** (after `--`; see `src/main/launch_options.gd`): `--solo | --host | --join=<ip[:port]>`, `--port=<n>`, `--autopilot` (plays itself; the host auto-starts the lobby and restarts runs), `--run-for=<s>` (print a report and quit), `--local-only` (no UPnP / public-IP lookup; **automated tests must use it**), `--stage-seconds=<n>` (wave length before the boss, default 240), `--start-at=<s>`, `--start-stage=<n>`, `--weak-bosses` (2% boss HP), `--give-weapons`, `--character=<0-3>`, `--screenshot-dir=<folder>`.
- Report failures honestly.

## Project layout
Folders are grouped by feature. Each scene (`.tscn`) sits next to its script.
- `src/autoload/`: global singletons. `Net` (ENet/offline session, invite parsing; owns `HostInvite`: UPnP, public IP, invite text), `GameInput` (all input bindings, registered in code), `Settings` (volumes, fullscreen, screen shake; user://settings.cfg; installs the pixel font), `Sfx` (`Sfx.play(&"name")`), `Music` (`Music.play(&"crypt")`).
- `src/main/`: root scene `main.tscn` (menu, pause menu, `Level` slot + `LevelSpawner`), `LaunchOptions`, `RunSetup` (lobby choices into the arena), `BuildInfo` (title-screen build text).
- `src/lobby/`: `Lobby` scene (character select + ready-up; host-owned state; spawned by `LevelSpawner` like the arena), pure `LobbyState`, `CharacterPortrait`.
- `src/arena/`: arena scene (fixed tick order: players, spawning, enemies, contact damage, bullets, hits, gems, phase check; stage timer, end states, snapshots, ability resolution), `SpawnDirector` (spawn pacing from the stage table), `FloorBaker` (paints a stage's whole floor, props, walls and candle light into one image from a seed) + `ArenaFloor`.
- `src/stages/`: `StageDef` resources (spawn table, pack type, boss, boss attack script of `BossStep`s, floor palette, prop style, music track) in `Stages.ALL`. New stage content is mostly data.
- `src/player/`: `Player` node, pure `PlayerMotor` (movement, Dash, firing; returns FIRED/ABILITY_USED bits), `ClientPredictor`, `PlayerHealth`, `LocalInput`, `CharacterStats` + `characters/*.tres` in `Characters.ALL`. Each player duplicates its character's stats so upgrades stay per-player. All damage to players goes through `Player.take_hit()`.
- `src/enemies/`: `EnemyManager` (pool of 300 incl. bosses, separation, byte-packed snapshots), `Enemy`, `BossBrain` (interprets a stage's boss script), `EnemyType` + `types/*.tres` in `EnemyTypes.ALL`.
- `src/combat/`: `ProjectileManager` (flat-array bullet pool; player and enemy instances; negative age = delayed bullet), `ShotPatterns` (`build()` returns 5 floats per bullet: angle, speed, delay, offset x/y), `WeaponSystem` + `AutoWeapons` (`weapons/*.tres`; altars; host deals weapon damage), `EffectsLayer` (particles + death animations), `BombBlast` (blast ring visual).
- `src/progression/`: `TeamProgress` (shared XP), `GemManager` (pickup pool; XP gems and coins), `LevelUpController` + `LevelUpSession`, `Upgrades` (`upgrades/*.tres`), `ShopController` + `ShopSession`, `Relics` (`relics/*.tres`, lists of `Upgrade` stat effects).
- `src/art/pixel_art.gd`: **every sprite as text rows** (one character per pixel, shared `PALETTE`; `P`/`p` recolored per player), built into cached textures. Edit sprites directly in this file; keep rows equal length.
- `src/audio/`: `Synth` (waveforms, envelopes, filter, vibrato, layering, echo), `Tracks` (music as text scores), `MusicComposer` (score -> seamless loop; rendered on background threads at startup).
- `src/ui/`: main menu, `Hud` (hearts, XP bar, ability readout, weapon icons, minimap, teammate arrows, boss bar, banners, level-up and shop panels), `LevelPips`, `WeaponIcons`, `TeammateArrows`, `ListScreen` (full-screen menu page base) with `Compendium` (info pages built from the registries) and `PlaytestChecklist` (+ `PlaytestDoc` parser; ticks in user://playtest.cfg), `SpriteIcon`, `PauseMenu`, `SettingsPanel`, `Minimap`, `PixelFont` (**every glyph as text rows**; edit directly), `theme/game_theme.tres` (the one Theme for all UI).
- `src/core/`: engine-agnostic helpers (`SpatialGrid`).
- `tests/unit/`: GUT tests (`test_*.gd`, extend `GutTest`).
- `tools/`: `run_tests.ps1`, `net_smoke_test.ps1`, `build.ps1`, `README-friends.txt`.

## Code conventions
- Gameplay simulation that must match across peers goes in **pure static functions or RefCounted classes** (e.g. `PlayerMotor`, `ShotPatterns`, `BossBrain`) so it's deterministic and unit-testable. Nodes call into it.
- Nodes don't run their own `_physics_process` for gameplay; the arena calls `tick()` in a fixed order. `_process` is for visuals only.
- Character abilities: one `ability` action; `CharacterStats.ability` picks Dash / Grave Blast / Hex Snare / Bone Effigy (Blink is unused but kept: append-only enum). Movement abilities run in `PlayerMotor` (predicted); the host resolves the rest in `Arena._on_player_ability_used` and broadcasts a small event; every peer draws it (`AbilityMarker` for lingering ones). Enemy effects (hex root, effigy lure) are host-only in `EnemyManager.tick_host`; snapshots carry a hexed flag for the tint.
- Visual effects (particles, death animations, screen shake, hurt flash, attack poses) are spawned locally on every peer from events they already see (`enemy_vanished`, `hit_at`, `hurt`, pattern events); never send effects over the network.
- Text: `PixelFont` is the default font. Only use font sizes 9 / 18 / 27 (1x/2x/3x). Labels get a 1px drop shadow from the theme; outlines don't work with the bitmap font. Style controls through `game_theme.tres`.
- Animation frames are extra sprites named `<sprite>_walk_1/_walk_2`, `<sprite>_attack`, `<sprite>_1`; same size as the base sprite (tested).
- Gamepad must work in every menu. Godot's default `ui_accept` has no gamepad button, so `GameInput` adds A to it; `tests/unit/test_input_bindings.gd` guards this. Esc / Start opens the pause menu (`pause`); R / Select (`restart`) returns to the lobby after a run.
- Test helpers must not reuse Node callback names (`_input`, `_process`, `_ready`...): `GutTest` is a Node.

## Gotchas (learned the hard way)
- An **empty** `PackedByteArray` sent as an RPC's only argument arrives as "no arguments" and the call fails. Always send a count or another argument alongside packed data.
- Never remove or free the arena (or other ticking nodes) in the middle of its own tick; defer it (`CONNECT_DEFERRED` / `call_deferred`).
- A negative width in `draw_texture_rect` does NOT mirror in Godot 4; it shifts the image a full width sideways. Use `PixelArt.draw()` / `PixelArt.draw_rect_flipped()`.
- Packed arrays are values: putting them in an Array and calling `resize()` in a loop only resizes copies. Resize each one directly.
- Constants can't call constructors (e.g. `PackedStringArray([...])` in a `const`); use plain arrays.
- When editing with scripts, replace exact text and verify the result: large regex or slice edits have deleted neighbouring functions before. Review `git diff` after big edits.
