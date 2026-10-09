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

## Project layout
- To be established in Milestone 1 (see `DESIGN.md` §7). Document the chosen folder structure here once created.
