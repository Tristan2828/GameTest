class_name Player
extends Node2D
## One player character.
##
## Who simulates what:
## - Host: simulates every player from their inputs. Its result is the truth.
## - Owning client: also simulates its own player right away ("prediction") so
##   controls feel instant, then quietly corrects toward the host's result.
## - Other clients: just show the host's positions, smoothed between snapshots.
##
## The arena calls tick() every physics frame; this node doesn't run its own
## physics loop, so the order of updates is always the same.

signal shot_requested(shooter: Player, input_seq: int)
## Every peer: this player just lost hearts (for effects).
signal hurt(victim: Player)
## Host: this player used a bomb (already paid for).
signal bomb_requested(bomber: Player)

const SLOT_COLORS: Array[Color] = [
	Color(0.36, 0.78, 0.95),
	Color(0.95, 0.45, 0.4),
	Color(0.55, 0.9, 0.45),
	Color(0.95, 0.8, 0.35),
]
## Shown in co-op UI ("Waiting for Red..."); matches SLOT_COLORS.
const SLOT_NAMES: Array[String] = ["Blue", "Red", "Green", "Gold"]
const MUZZLE_DISTANCE: float = 9.0
## Host: inputs from a client wait here until simulated. Too many queued = drop oldest.
const MAX_QUEUED_INPUTS: int = 6
## Host: if more than this many inputs are waiting, simulate two per tick to catch up.
const CATCH_UP_THRESHOLD: int = 3
const REMOTE_SMOOTHING: float = 18.0
const CORRECTION_SMOOTHING: float = 10.0
const HEART_COLOR: Color = Color(0.9, 0.2, 0.3)
const HEART_EMPTY_COLOR: Color = Color(0.25, 0.15, 0.18)
const HITBOX_OUTLINE_COLOR: Color = Color(0.1, 0.05, 0.12)
## Steps per second of the walk cycle (matches the bob).
const WALK_STEPS_PER_SECOND: float = 7.6
const SECOND_WIND_INVULNERABILITY: float = 2.0

@export var stats: CharacterStats

var peer_id: int = 1
var slot: int = 0
## Characters id (same on all peers; comes with the spawn data).
var character_id: int = 0
var bounds: Rect2 = Rect2()
var state: PlayerState = PlayerState.new()
## Host-owned; clients get copies from snapshots.
var health: PlayerHealth = PlayerHealth.new()
## Bombs left this stage (host-owned, synced in snapshots).
var bombs_left: int = 0
## Every upgrade this player has taken, in order (same on all peers).
var upgrade_ids: Array[int] = []
## Relics owned, in purchase order (same on all peers).
var relic_ids: Array[int] = []
## Automatic weapons owned: weapon id -> level (same on all peers).
var weapon_levels: Dictionary[int, int] = {}
## The shared stage clock, set by the arena each frame (orbiting skulls use it).
var weapon_clock: float = 0.0
## Coins in this player's pocket (host-owned, synced in snapshots).
var coins: int = 0
## Host: kills since the last Vampire Fang heal.
var kills_toward_heal: int = 0
## Host: how many times this player went down this run.
var times_downed: int = 0
## Host: Second Wind already saved this player this stage.
var second_wind_used: bool = false
## Host: sequence number of the last input it simulated for this player.
var last_processed_seq: int = -1
## Client debug stats for the local player.
var correction_count: int = 0
var largest_correction: float = 0.0

var _local_input: LocalInput = null
var _next_input_seq: int = 0
var _input_queue: Array[PlayerInput] = []
var _newest_received_seq: int = -1
## Host: last bomb_count seen from this player's input.
var _last_bomb_count: int = 0
var _predictor: ClientPredictor = ClientPredictor.new()
## Drawn offset from the simulated position; shrinks to zero so corrections look smooth.
var _visual_offset: Vector2 = Vector2.ZERO
var _remote_target: Vector2 = Vector2.ZERO
var _last_seen_hearts: int = -1
var _was_dashing: bool = false
## Walk bob height in pixels, and the last movement direction (for dash trails).
var _bob: float = 0.0
var _walk_time: float = 0.0
var _walking: bool = false
var _last_move: Vector2 = Vector2.RIGHT
var _last_drawn_position: Vector2 = Vector2.ZERO
var _shake: float = 0.0
var _remote_dashing: bool = false

@onready var _camera: Camera2D = $Camera2D


## Called by the arena's spawn function, before the node enters the tree.
func setup(owner_peer_id: int, player_slot: int, spawn_position: Vector2, arena_bounds: Rect2,
		character: int = Characters.Id.WANDERER) -> void:
	peer_id = owner_peer_id
	slot = player_slot
	bounds = arena_bounds
	character_id = character
	name = str(owner_peer_id)
	# Each player gets its own copy so upgrades only change this player.
	stats = Characters.get_character(character).duplicate()
	health.reset(stats.max_hearts)
	bombs_left = stats.bombs_per_stage
	state.position = spawn_position
	position = spawn_position
	_remote_target = spawn_position


func _ready() -> void:
	if is_local():
		_local_input = LocalInput.new()
		add_child(_local_input)
		_camera.limit_left = int(bounds.position.x)
		_camera.limit_top = int(bounds.position.y)
		_camera.limit_right = int(bounds.end.x)
		_camera.limit_bottom = int(bounds.end.y)
		_camera.enabled = true
		_camera.make_current()


func is_local() -> bool:
	return peer_id == multiplayer.get_unique_id()


func is_dashing() -> bool:
	if _shows_remote_state():
		return _remote_dashing
	return state.is_dashing()


func display_name() -> String:
	return SLOT_NAMES[slot % SLOT_NAMES.size()]


## Runs on every peer when the host announces this player's pick.
func apply_upgrade(upgrade_id: int) -> void:
	upgrade_ids.append(upgrade_id)
	Upgrades.apply(upgrade_id, stats, health)
	queue_redraw()


## Host: an enemy or enemy bullet hit this player. Returns true if it landed.
## Second Wind (Wanderer) turns the first lethal hit each stage into 1 heart left.
func take_hit(amount: int) -> bool:
	if stats.second_wind and not second_wind_used and health.hearts > 0 and health.hearts <= amount \
			and not health.is_invulnerable():
		second_wind_used = true
		health.hearts = 1
		health.invulnerable_left = SECOND_WIND_INVULNERABILITY
		return true
	var landed := health.take_hit(amount, stats.hit_invulnerability)
	if landed and health.is_downed():
		times_downed += 1
	return landed


## Host: back to full strength at a new spot (start of a stage).
func respawn(at: Vector2) -> void:
	second_wind_used = false
	health.reset(stats.max_hearts)
	bombs_left = stats.bombs_per_stage
	state.position = at
	state.dash_time_left = 0.0
	state.dash_cooldown_left = 0.0
	state.fire_cooldown_left = 0.0
	position = at


## Runs on every peer when the host announces a purchase.
func apply_relic(relic_id: int) -> void:
	relic_ids.append(relic_id)
	Relics.apply(relic_id, stats, health)
	queue_redraw()


## Runs on every peer when the host announces a weapon pickup.
func gain_weapon(weapon_id: int) -> void:
	weapon_levels[weapon_id] = mini(weapon_levels.get(weapon_id, 0) + 1, AutoWeapons.MAX_LEVEL)


## e.g. "Skulls 2  Aura 1" for the HUD.
func weapons_summary() -> String:
	var parts := PackedStringArray()
	for weapon_id: int in weapon_levels:
		parts.append("%s %d" % [AutoWeapons.get_weapon(weapon_id).title, weapon_levels[weapon_id]])
	return "   ".join(parts)


## Host: count a kill toward heal-on-kill relics.
func register_kill() -> void:
	if stats.heal_every_kills <= 0 or health.is_downed():
		return
	kills_toward_heal += 1
	if kills_toward_heal >= stats.heal_every_kills:
		kills_toward_heal = 0
		health.heal(1)


func is_downed() -> bool:
	return health.is_downed()


## Checked when an enemy or enemy bullet touches this player. Dashing dodges
## hits. Works on clients too, using the latest known state.
func can_be_hit() -> bool:
	return not health.is_downed() and not health.is_invulnerable() and not is_dashing()


## Best known position of this player on this peer: simulated on the host and
## for your own player; smoothed snapshot position for other players on clients.
func world_position() -> Vector2:
	return position if _shows_remote_state() else state.position


## Center of what this player's screen shows (their camera), for the minimap.
func view_center() -> Vector2:
	return _camera.get_screen_center_position() if is_local() else position


func muzzle_position() -> Vector2:
	return state.position + Vector2.from_angle(state.aim) * MUZZLE_DISTANCE


## Advances this player by one physics tick (only while the run is being played).
func tick(delta: float) -> void:
	if multiplayer.is_server():
		health.tick(delta)
	if multiplayer.is_server():
		if is_local():
			_simulate(_read_local_input(), delta)
		else:
			_simulate_queued_inputs(delta)
	elif is_local():
		var input := _read_local_input()
		_submit_input.rpc_id(1, input.seq, input.move, input.aim, input.fire, input.dash_count, input.bomb_count)
		_simulate(input, delta)
		_predictor.record(input.seq, state.position)


## Client: apply this player's entry from a host snapshot.
func apply_server_state(server_position: Vector2, aim: float, dashing: bool, ack_seq: int,
		hearts: int, max_hearts: int, invulnerable: bool) -> void:
	health.max_hearts = max_hearts
	health.hearts = hearts
	# Only used for the flashing effect on clients.
	health.invulnerable_left = 1.0 if invulnerable else 0.0
	if is_local():
		var error := _predictor.reconcile(ack_seq, server_position)
		if error == Vector2.ZERO:
			return
		correction_count += 1
		largest_correction = maxf(largest_correction, error.length())
		state.position = PlayerMotor.clamp_to_bounds(state.position + error, bounds, stats.body_radius)
		if error.length() >= ClientPredictor.SNAP_DISTANCE:
			_visual_offset = Vector2.ZERO
		else:
			# Keep drawing where we were, then glide to the corrected spot.
			_visual_offset -= error
	else:
		_remote_target = server_position
		state.aim = aim
		_remote_dashing = dashing


## Local player only: shake the camera (strength in pixels, fades quickly).
func add_shake(strength: float) -> void:
	if is_local() and Settings.screen_shake:
		_shake = maxf(_shake, strength)


func _process(delta: float) -> void:
	if _last_seen_hearts >= 0 and health.hearts < _last_seen_hearts:
		hurt.emit(self)
		add_shake(5.0)
	var dashing := is_dashing()
	if dashing and not _was_dashing and is_local():
		Sfx.play(&"dash", -6.0)
	_was_dashing = dashing
	_last_seen_hearts = health.hearts
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 20.0, 0.0)
		_camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)).round()
	if multiplayer.is_server():
		position = state.position
	elif is_local():
		_visual_offset = _visual_offset.lerp(Vector2.ZERO, 1.0 - exp(-CORRECTION_SMOOTHING * delta))
		position = state.position + _visual_offset
	else:
		position = position.lerp(_remote_target, 1.0 - exp(-REMOTE_SMOOTHING * delta))
	_update_walk(delta)
	queue_redraw()


func _update_walk(delta: float) -> void:
	var moved := position - _last_drawn_position
	_last_drawn_position = position
	_walking = moved.length() > 0.2
	if _walking:
		_last_move = moved.normalized()
		_walk_time += delta
		_bob = roundf(absf(sin(_walk_time * 12.0)))
	else:
		_bob = 0.0


func _draw() -> void:
	var color: Color = SLOT_COLORS[slot % SLOT_COLORS.size()]
	_draw_heart_pips()
	if health.is_downed():
		var bob := sin(Time.get_ticks_msec() / 250.0)
		PixelArt.draw(self, "ghost", Vector2(0, -2 + bob), Color.WHITE, false, false, 1.0, Color(color.lightened(0.6), 0.55))
		return
	_draw_weapons()
	var aim_direction := Vector2.from_angle(state.aim)
	var modulate := Color.WHITE
	# Blink while invulnerable after a hit.
	if health.is_invulnerable() and int(Time.get_ticks_msec() / 80.0) % 2 == 0:
		modulate = Color(1, 1, 1, 0.3)
	var sprite := PixelArt.walk_frame(stats.sprite, _bob > 0.0 or _walking, _walk_time * WALK_STEPS_PER_SECOND)
	if is_dashing():
		PixelArt.draw(self, sprite, -_last_move * 6.0, color, false, aim_direction.x < 0.0, 1.0, Color(1, 1, 1, 0.3))
	PixelArt.draw(self, sprite, Vector2(0, -2 - _bob), color, false, aim_direction.x < 0.0, 1.0, modulate)
	# The real hitbox, always visible: in a bullet hell you dodge with this dot.
	draw_circle(Vector2.ZERO, stats.hitbox_radius + 0.5, HITBOX_OUTLINE_COLOR)
	draw_circle(Vector2.ZERO, stats.hitbox_radius, Color.WHITE)


func _draw_heart_pips() -> void:
	var spacing := 4.0
	var start_x := -(health.max_hearts - 1) * spacing / 2.0
	for i: int in health.max_hearts:
		var filled := i < health.hearts
		draw_circle(Vector2(start_x + i * spacing, stats.body_radius + 5.0), 1.5,
			HEART_COLOR if filled else HEART_EMPTY_COLOR)


## Character silhouette details, drawn over the body in a darker shade.
func _draw_weapons() -> void:
	for weapon_id: int in weapon_levels:
		var weapon := AutoWeapons.get_weapon(weapon_id)
		var level: int = weapon_levels[weapon_id]
		match weapon.kind:
			AutoWeapon.Kind.AURA:
				var pulse := 0.5 + 0.5 * sin(weapon_clock * TAU / weapon.interval_at(level))
				var radius := weapon.radius_at(level)
				draw_circle(Vector2.ZERO, radius, Color(weapon.color, 0.05 + 0.05 * pulse))
				draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(weapon.color, 0.25 + 0.2 * pulse), 1.0)
			AutoWeapon.Kind.ORBIT:
				# Same math as the host's hit checks, relative to where we're drawn.
				for skull: Vector2 in AutoWeapons.orbit_positions(Vector2.ZERO, level, weapon_clock):
					PixelArt.draw(self, "skull", skull)


func _shows_remote_state() -> bool:
	return not multiplayer.is_server() and not is_local()


func _read_local_input() -> PlayerInput:
	var input := _local_input.sample(self, get_physics_process_delta_time())
	input.seq = _next_input_seq
	_next_input_seq += 1
	return input


func _simulate_queued_inputs(delta: float) -> void:
	# No input arrived in time: wait instead of guessing, so the client's
	# prediction (which used the real input) stays in sync with us.
	if _input_queue.is_empty():
		return
	var steps := 2 if _input_queue.size() > CATCH_UP_THRESHOLD else 1
	for i: int in steps:
		_simulate(_input_queue.pop_front(), delta)


func _simulate(input: PlayerInput, delta: float) -> void:
	last_processed_seq = input.seq
	if health.is_downed():
		# Ghosts float around but can't shoot or bomb.
		input.fire = false
	if multiplayer.is_server() and input.bomb_count != _last_bomb_count:
		_last_bomb_count = input.bomb_count
		if bombs_left > 0 and not health.is_downed():
			bombs_left -= 1
			bomb_requested.emit(self)
	if PlayerMotor.step(state, input, stats, bounds, delta):
		shot_requested.emit(self, input.seq)


## Client -> host, every tick. Unreliable: a lost packet is cheaper than a delay.
@rpc("any_peer", "call_remote", "unreliable_ordered", 2)
func _submit_input(seq: int, move: Vector2, aim: float, fire: bool, dash_count: int, bomb_count: int) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != peer_id:
		return
	if seq <= _newest_received_seq:
		return
	_newest_received_seq = seq
	var input := PlayerInput.new()
	input.seq = seq
	input.move = move.limit_length(1.0)
	input.aim = aim
	input.fire = fire
	input.dash_count = dash_count
	input.bomb_count = bomb_count
	_input_queue.append(input)
	while _input_queue.size() > MAX_QUEUED_INPUTS:
		_input_queue.pop_front()
