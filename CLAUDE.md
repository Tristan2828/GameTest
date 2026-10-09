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
- Game launch flags (after `--`): `--solo | --host | --join=<ip>`, `--port=<n>`, `--autopilot`, `--run-for=<seconds>`. See `src/main/launch_options.gd`.
- Test helpers must not reuse Node callback names (`_input`, `_process`, `_ready`...): `GutTest` is a Node.

## Project layout
Folders are grouped by feature. Each scene (`.tscn`) sits next to its script.
- `src/autoload/`: global singletons. `Net` (ENet/offline session) and `GameInput` (all input bindings, registered in code).
- `src/main/`: root scene `main.tscn` (menu plus `Level` slot plus `LevelSpawner`) and `LaunchOptions`.
- `src/ui/`: menus and HUD widgets.
- `src/arena/`: arena scene. Owns the fixed tick order (players, then enemies, then bullets, then hits) and host snapshots.
- `src/player/`: `Player` node, pure `PlayerMotor` sim, `ClientPredictor`, `LocalInput`, `CharacterStats` resource. Character `.tres` files live in `characters/`.
- `src/combat/`: `ProjectileManager` (flat-array bullet pool) and `ShotPatterns` (seeded, deterministic patterns).
- `src/enemies/`: `EnemyManager` (node pool and snapshots) and enemy scenes.
- `tests/unit/`: GUT tests (`test_*.gd`, extend `GutTest`).
- `tools/`: PowerShell helper scripts.

## Code conventions
- Gameplay simulation that must match across peers goes in **pure static functions or RefCounted classes** (e.g. `PlayerMotor`, `ShotPatterns`) so it's deterministic and unit-testable. Nodes call into it.
- Nodes don't run their own `_physics_process` for gameplay; the arena calls `tick()` in a fixed order. `_process` is for visuals only.
- RPC channels: 0 = reliable events, 1 = host snapshots, 2 = client inputs. Host only sends to peers in `_ready_peers` (arena loaded).
- `untyped_declaration` is an error in project settings, so type every declaration, including `for` loop variables (`for i: int in n:`).
- Placeholder art is drawn with `_draw()` for now. It will be replaced by pixel-art sprites later.
