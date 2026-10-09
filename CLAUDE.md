# CLAUDE.md

Online co-op (1–4 players) twin-stick roguelite bullet-hell shooter, dark fantasy pixel art. **Read `DESIGN.md` before starting work.** It is the source of truth for game design decisions. Update it when a design decision changes or an open question gets answered.

## Context
- The owner is new to Godot and game dev; AI writes most of the code. Explain engine concepts briefly when introducing them, and prefer simple, readable solutions.
- Target: Windows PC only. Input: mouse + keyboard and gamepad, both first-class.

## Engine & language rules
- **Godot 4.x only.** Never use Godot 3 syntax or APIs (e.g. use `@export`, `@onready`, `super()`, `CharacterBody2D`, `velocity` property + `move_and_slide()` with no args, `signal.connect(callable)`, `@rpc`, `FileAccess`, `Tween` via `create_tween()`).
- When unsure about a Godot API, look up current Godot 4 docs rather than guessing.
- **Statically typed GDScript everywhere:** typed variables, parameters, and return types (`func take_damage(amount: int) -> void:`).
- Keep the project fully text-editable: build scenes in `.tscn` files and data in `.tres` resources so they can be edited without the editor GUI. If a step truly requires the editor, say so explicitly.
- Pixel art: nearest-neighbor texture filtering, integer scaling.

## Multiplayer rules
- Godot built-in high-level multiplayer (ENet), direct IP / LAN. **Host-authoritative.**
- Clients send input; the host simulates and syncs state.
- Never sync bullets individually: send pattern events (pattern id, origin, time, seed) and simulate deterministically on each peer.
- Pool enemies, bullets, and pickups.
- Every gameplay feature must work in solo **and** online co-op. Design for networking from the start; don't bolt it on later.

## Verification
- Godot 4.7.2 is **not on PATH**. Use the full path to the console build for command-line work:
  `& "C:\Code Tools\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . <args>`
  (`Godot_v4.7.2-stable_win64.exe` in the same folder is the GUI editor.)
- Run it headless to check scripts and run tests after changes. Report failures honestly.

- Tests use **GUT** (`addons/gut`, v9.7.1). Run them with `pwsh tools/run_tests.ps1`. Don't call GUT directly: GUT silently skips test files that fail to parse and still says "All tests passed", and the wrapper catches that.
- Online smoke test: `pwsh tools/net_smoke_test.ps1` starts a headless host and client on autopilot and checks that they connected and that the client's shots damaged dummies on the host. Run it after any networking change.
- Build the Windows exe: `pwsh tools/build.ps1`. It writes `builds/windows/GameTest.exe` (one file, game data embedded) and `builds/GameTest-<version>-windows.zip`. The export preset is `export_presets.cfg` (excludes GUT, tests and tools). Bump `config/version` in `project.godot` for each build you send to friends; the menu shows it. Needs the 4.7.2 export templates in `%APPDATA%\Godot\export_templates\4.7.2.stable\`.
- Game launch flags (after `--`): `--solo | --host | --join=<ip>`, `--port=<n>`, `--autopilot`, `--run-for=<seconds>`, `--local-only`, `--stage-seconds=<n>` (horde wave length before the boss, default 240), `--start-at=<seconds>` (host starts the stage clock there, to test late-stage content quickly), `--weak-bosses` (2% boss HP, to test stage transitions), `--give-weapons` (all auto weapons at level 2), `--start-stage=<n>` (begin the run at stage n), `--character=<n>` (host's character before the lobby exists), `--screenshot-dir=<folder>` (needs a real window: run without `--headless`; saves gameplay every 10s plus the first level-up screen, so you can check visuals by reading the PNGs). With `--autopilot`, the host also restarts automatically 2s after a stage ends. See `src/main/launch_options.gd`. Automated tests must host with `--local-only` so they don't touch the router (UPnP) or call the public-IP web service.
- After adding a new `class_name` script, run `--import` before running scripts headless. Godot only learns about new global classes during an import, and without it you get "Could not find type" parse errors. The tools scripts already do this.
- Test helpers must not reuse Node callback names (`_input`, `_process`, `_ready`...): `GutTest` is a Node.

## Project layout
Folders are grouped by feature. Each scene (`.tscn`) sits next to its script.
- `src/autoload/`: global singletons. `Sfx` (sound effects synthesized in code at startup; `Sfx.play(&"name")`; rate-limited; plays on the "SFX" bus), `Settings` (volume, fullscreen, screen shake; saved to user://settings.cfg), `Net` (ENet/offline session, invite parsing) and `GameInput` (all input bindings, registered in code). Also `HostInvite`, owned by `Net`: UPnP port opening, public-IP lookup, invite text.
- `src/main/`: root scene `main.tscn` (menu plus `Level` slot plus `LevelSpawner`) and `LaunchOptions`.
- `src/lobby/`: `Lobby` scene (character select + ready-up, host-owned state broadcast on change; spawned by `LevelSpawner` like the arena) with pure `LobbyState` rules and `CharacterPortrait`. `RunSetup` (in `src/main/`) carries choices and join order into the arena.
- `src/ui/`: main menu, `Hud` scene (hearts, timer, banners), and HUD widgets.
- `src/stages/`: `StageDef` resources (one `.tres` per stage: spawn table of `SpawnEntry`, pack type, boss type, boss attack script of `BossStep`s, floor palette and prop style) registered in `Stages.ALL`. New stage content is mostly data here.
- `src/arena/`: arena scene, `ArenaFloor` (seeded decorative ground, drawn once, palette from the stage), and `SpawnDirector` (spawn pacing; enemy mix from the stage table). The arena owns the fixed tick order (players, then spawning, then enemies, then contact damage, then bullets, then hits, then the phase check), the stage timer and end states, and host snapshots.
- `src/player/`: `Player` node, pure `PlayerMotor` sim, `ClientPredictor`, `PlayerHealth`, `LocalInput`, `CharacterStats` resource. Characters are `.tres` files in `characters/`, registered in `Characters.ALL` (index = network id, append only); the character id travels in the player spawn data, and each player duplicates its character's stats so upgrades stay per-player. All damage to players goes through `Player.take_hit()` (handles Second Wind).
- `src/combat/`: `WeaponSystem` (auto weapons + altars; host deals all weapon damage; orbit skulls/aura are drawn from the shared stage clock, so they need no sync), `AutoWeapons` registry (`weapons/*.tres`, index = network id, append only), `ProjectileManager` (flat-array bullet pool; two instances: player bullets and enemy bullets; negative age = delayed bullet) and `ShotPatterns` (seeded, deterministic patterns; `build()` returns 5 floats per bullet: angle, speed, delay, offset x, offset y; ids are network ids, append only). Enemy patterns travel as batched reliable events (id, origin, aim, seed, host fire time), and clients fast-forward them by about one round trip.
- `src/enemies/`: `EnemyManager` (pool of 300, separation, byte-packed snapshots; bosses live in the same pool), `BossBrain` (pure interpreter of a stage's boss script), `Enemy`, `EnemyType` resources in `types/` registered in `EnemyTypes.ALL` (index = network id; append only).
- `src/core/`: engine-agnostic helpers (`SpatialGrid`).
- `src/progression/`: `ShopController` + pure `ShopSession` (between-stage shop: per-player offers, buy/reroll/ready validated by the host), `Relics` registry (`relics/*.tres`, each a list of `Upgrade` stat effects; index = network id, append only), `TeamProgress` (shared XP/level curve), `LevelUpController` (networked level-up pause: choices, picks, announcements) with pure `LevelUpSession` rules, `Upgrades` registry (`upgrades/*.tres`, index = network id, append only; `Upgrades.apply` runs on every peer so stats match for prediction), and `GemManager` (flat-array pickup pool, two instances: XP gems for the team and coins for whoever grabs them; reliable batched spawn/collect events; clients animate the magnet pull, and only host pickups count).
- `tests/unit/`: GUT tests (`test_*.gd`, extend `GutTest`).
- `tools/`: PowerShell helper scripts.

## Code conventions
- Gameplay simulation that must match across peers goes in **pure static functions or RefCounted classes** (e.g. `PlayerMotor`, `ShotPatterns`) so it's deterministic and unit-testable. Nodes call into it.
- Nodes don't run their own `_physics_process` for gameplay; the arena calls `tick()` in a fixed order. `_process` is for visuals only.
- RPC channels: 0 = reliable events, 1 = host snapshots, 2 = client inputs. Host only sends to peers in `_ready_peers` (arena loaded).
- `untyped_declaration` is an error in project settings, so type every declaration, including `for` loop variables (`for i: int in n:`).
- Placeholder art is drawn with `_draw()` for now. It will be replaced by pixel-art sprites later.
- RPC gotcha: an **empty** `PackedByteArray` sent as an RPC's only argument arrives as "no arguments" and the call fails. Always send a count or another argument alongside packed data.
- Never remove or free the arena (or other ticking nodes) in the middle of its own tick; defer it (`CONNECT_DEFERRED` / `call_deferred`).
- `-s some_script.gd` runs do NOT get autoloads (`Net`, `GameInput`), so game scenes can't run that way. To check visuals, launch the real game with `--screenshot-dir`.
- Gamepad must work in every menu. Esc / Start opens the pause menu (`pause` action); R / Select (`restart`) returns to the lobby after a run.
- Visual effects (`EffectsLayer` particles, screen shake, hurt flash) are spawned locally on every peer from events they already see (`enemy_vanished`, `hit_at`, `hurt`); never send effects over the network.
- Packed arrays are values: putting them in an Array and calling `resize()` in a loop only resizes copies. Resize each one directly.
- Gamepad must work in every menu. Godot's default `ui_accept` has no gamepad button, so `GameInput` adds A to it. `tests/unit/test_input_bindings.gd` guards this; extend it when adding new UI.
