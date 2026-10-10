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
## Host: this player used their ability (the movement part already happened).
signal ability_used(user: Player)
## Every peer: this player got back up (revived by a teammate, or a new stage).
signal revived(player: Player)

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
## Remote players further than this from their new snapshot position jump there
## (blinks, respawns) instead of sliding.
const REMOTE_SNAP_DISTANCE: float = 48.0
## The revive circle fills in this color.
const REVIVE_COLOR: Color = Color(0.55, 0.95, 0.5)
## How quickly the camera glides to a spectated teammate (higher = faster).
const SPECTATE_PAN_SPEED: float = 6.0

@export var stats: CharacterStats

var peer_id: int = 1
var slot: int = 0
## Characters id (same on all peers; comes with the spawn data).
var character_id: int = 0
var bounds: Rect2 = Rect2()
var state: PlayerState = PlayerState.new()
## Host-owned; clients get copies from snapshots.
var health: PlayerHealth = PlayerHealth.new()
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
## Host: hearts lost to hits this run.
var hearts_lost: int = 0
## Downed: how full the revive circle is, 0..1 (host-owned, synced in snapshots).
var revive_progress: float = 0.0
## This stage's quest (Quests id, -1 = none) and its progress (host-owned, synced in snapshots).
var quest_id: int = -1
var quest_progress: int = 0
## Local player only: while downed, the camera shows this teammate (null = yourself).
var spectate_target: Player = null
## Host: sequence number of the last input it simulated for this player.
var last_processed_seq: int = -1
## Client debug stats for the local player.
var correction_count: int = 0
var largest_correction: float = 0.0

var _local_input: LocalInput = null
var _next_input_seq: int = 0
var _input_queue: Array[PlayerInput] = []
var _newest_received_seq: int = -1
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
		character: int = Characters.Id.WANDERER, hearts_bonus: int = 0) -> void:
	peer_id = owner_peer_id
	slot = player_slot
	bounds = arena_bounds
	character_id = character
	name = str(owner_peer_id)
	# Each player gets its own copy so upgrades only change this player.
	stats = Characters.get_character(character).duplicate()
	stats.max_hearts = maxi(stats.max_hearts + hearts_bonus, 1)  # Difficulty setting.
	health.reset(stats.max_hearts)
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
func take_hit(amount: int) -> bool:
	var hearts_before := health.hearts
	var landed := health.take_hit(amount, stats.hit_invulnerability)
	hearts_lost += hearts_before - health.hearts
	if landed and health.is_downed():
		times_downed += 1
		print("Player %d downed" % peer_id)
	return landed


## Host: a teammate filled the revive circle. Back up with some hearts and a
## moment of safety, right where they fell.
func revive() -> void:
	health.hearts = Revive.hearts_after(health.max_hearts)
	health.invulnerable_left = Revive.INVULNERABILITY
	revive_progress = 0.0
	print("Player %d revived" % peer_id)


## Host: back to full strength at a new spot (start of a stage).
func respawn(at: Vector2) -> void:
	health.reset(stats.max_hearts)
	revive_progress = 0.0
	state.position = at
	state.dash_time_left = 0.0
	state.ability_cooldown_left = 0.0
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


## Host: count a kill toward heal-on-kill relics.
func register_kill() -> void:
	if stats.heal_every_kills <= 0 or health.is_downed():
		return
	kills_toward_heal += 1
	if kills_toward_heal >= stats.heal_every_kills:
		kills_toward_heal = 0
		health.heal(1)


## 0 = just used, 1 = ready (for the HUD).
func ability_ready_ratio() -> float:
	if stats.ability_cooldown <= 0.0:
		return 1.0
	return 1.0 - clampf(state.ability_cooldown_left / stats.ability_cooldown, 0.0, 1.0)


func is_downed() -> bool:
	return health.is_downed()


## Checked when an enemy or enemy bullet touches this player. Dashing dodges
## hits. Works on clients too, using the latest known state.
func can_be_hit() -> bool:
	if LaunchOptions.invincible:
		return false  # Test flag (performance and visual checks).
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
		_submit_input.rpc_id(1, input.seq, input.move, input.aim, input.fire, input.ability_count)
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
		if position.distance_to(server_position) > REMOTE_SNAP_DISTANCE:
			position = server_position
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
	elif _last_seen_hearts == 0 and health.hearts > 0:
		revived.emit(self)
	var dashing := is_dashing()
	if dashing and not _was_dashing and is_local():
		Sfx.play(&"dash", -6.0)
	_was_dashing = dashing
	_last_seen_hearts = health.hearts
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 20.0, 0.0)
		_camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)).round()
	if is_local():
		# Downed: the camera glides over to the teammate we're watching (and back).
		var pan := Vector2.ZERO
		if is_instance_valid(spectate_target) and spectate_target != self:
			pan = spectate_target.position - position
		_camera.position = _camera.position.lerp(pan, 1.0 - exp(-SPECTATE_PAN_SPEED * delta))
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
		_draw_downed(color)
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


## Lying on the ground inside the revive circle, with a bobbing "+" asking for help.
func _draw_downed(color: Color) -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0)
	draw_circle(Vector2.ZERO, Revive.RADIUS, Color(color, 0.05 + 0.04 * pulse))
	var dashes := 20
	for i: int in range(0, dashes, 2):
		draw_arc(Vector2.ZERO, Revive.RADIUS, TAU * i / dashes, TAU * (i + 1) / dashes, 4, Color(color, 0.45 + 0.35 * pulse), 1.0)
	if revive_progress > 0.0:
		draw_arc(Vector2.ZERO, Revive.RADIUS, -PI / 2.0, -PI / 2.0 + TAU * revive_progress, 48, REVIVE_COLOR, 2.0)
	draw_set_transform(Vector2(0, 1), PI / 2.0)
	PixelArt.draw(self, stats.sprite, Vector2.ZERO, color, false, false, 1.0, Color(0.7, 0.65, 0.75))
	draw_set_transform(Vector2.ZERO)
	var top := Vector2(0, -15 - roundf(pulse * 2.0))
	draw_rect(Rect2(top + Vector2(-2, -4), Vector2(5, 9)), HITBOX_OUTLINE_COLOR)
	draw_rect(Rect2(top + Vector2(-4, -2), Vector2(9, 5)), HITBOX_OUTLINE_COLOR)
	draw_rect(Rect2(top + Vector2(-1, -3), Vector2(3, 7)), REVIVE_COLOR)
	draw_rect(Rect2(top + Vector2(-3, -1), Vector2(7, 3)), REVIVE_COLOR)


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
		# Downed players lie still until revived: no moving, shooting or ability.
		input.move = Vector2.ZERO
		input.fire = false
		state.last_ability_count = input.ability_count
		state.dash_time_left = 0.0
	var result := PlayerMotor.step(state, input, stats, bounds, delta)
	if result & PlayerMotor.FIRED:
		shot_requested.emit(self, input.seq)
	if result & PlayerMotor.ABILITY_USED:
		if multiplayer.is_server():
			ability_used.emit(self)
		if is_local() and stats.ability == CharacterStats.Ability.BLINK:
			Sfx.play(&"dash", -4.0, 1.6)


## Client -> host, every tick. Unreliable: a lost packet is cheaper than a delay.
@rpc("any_peer", "call_remote", "unreliable_ordered", 2)
func _submit_input(seq: int, move: Vector2, aim: float, fire: bool, ability_count: int) -> void:
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
	input.ability_count = ability_count
	_input_queue.append(input)
	while _input_queue.size() > MAX_QUEUED_INPUTS:
		_input_queue.pop_front()
