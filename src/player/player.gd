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
const TOMBSTONE_COLOR: Color = Color(0.35, 0.33, 0.4)

@export var stats: CharacterStats

var peer_id: int = 1
var slot: int = 0
var bounds: Rect2 = Rect2()
var state: PlayerState = PlayerState.new()
## Host-owned; clients get copies from snapshots.
var health: PlayerHealth = PlayerHealth.new()
## Every upgrade this player has taken, in order (same on all peers).
var upgrade_ids: Array[int] = []
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
var _remote_dashing: bool = false

@onready var _camera: Camera2D = $Camera2D


## Called by the arena's spawn function, before the node enters the tree.
func setup(owner_peer_id: int, player_slot: int, spawn_position: Vector2, arena_bounds: Rect2) -> void:
	peer_id = owner_peer_id
	slot = player_slot
	bounds = arena_bounds
	name = str(owner_peer_id)
	# Each player gets its own copy so upgrades only change this player.
	stats = stats.duplicate()
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


func is_downed() -> bool:
	return health.is_downed()


## Host: checked when an enemy touches this player. Dashing dodges hits.
func can_be_hit() -> bool:
	return not health.is_downed() and not health.is_invulnerable() and not state.is_dashing()


## Best known position of this player on this peer: simulated on the host and
## for your own player; smoothed snapshot position for other players on clients.
func world_position() -> Vector2:
	return position if _shows_remote_state() else state.position


func muzzle_position() -> Vector2:
	return state.position + Vector2.from_angle(state.aim) * MUZZLE_DISTANCE


## Advances this player by one physics tick (only while the run is being played).
func tick(delta: float) -> void:
	if multiplayer.is_server():
		health.tick(delta)
	if health.is_downed():
		return
	if multiplayer.is_server():
		if is_local():
			_simulate(_read_local_input(), delta)
		else:
			_simulate_queued_inputs(delta)
	elif is_local():
		var input := _read_local_input()
		_submit_input.rpc_id(1, input.seq, input.move, input.aim, input.fire, input.dash_count)
		_simulate(input, delta)
		_predictor.record(input.seq, state.position)


## Client: apply this player's entry from a host snapshot.
func apply_server_state(server_position: Vector2, aim: float, dashing: bool, ack_seq: int,
		hearts: int, max_hearts: int, invulnerable: bool) -> void:
	health.max_hearts = max_hearts
	health.hearts = hearts
	# Only used for the flashing effect on clients.
	health.invulnerable_left = 1.0 if invulnerable else 0.0
	if is_local() and health.is_downed():
		state.position = server_position
		_visual_offset = Vector2.ZERO
		return
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


func _process(delta: float) -> void:
	if multiplayer.is_server():
		position = state.position
	elif is_local():
		_visual_offset = _visual_offset.lerp(Vector2.ZERO, 1.0 - exp(-CORRECTION_SMOOTHING * delta))
		position = state.position + _visual_offset
	else:
		position = position.lerp(_remote_target, 1.0 - exp(-REMOTE_SMOOTHING * delta))
	queue_redraw()


func _draw() -> void:
	var color: Color = SLOT_COLORS[slot % SLOT_COLORS.size()]
	_draw_heart_pips()
	if health.is_downed():
		_draw_tombstone(color)
		return
	# Blink while invulnerable after a hit.
	if health.is_invulnerable() and int(Time.get_ticks_msec() / 80.0) % 2 == 0:
		color = Color(color, 0.25)
	if is_dashing():
		draw_circle(Vector2.ZERO, stats.body_radius + 3.0, Color(color, 0.35))
		color = color.lightened(0.4)
	draw_circle(Vector2.ZERO, stats.body_radius, color)
	var aim_direction := Vector2.from_angle(state.aim)
	draw_line(aim_direction * 4.0, aim_direction * MUZZLE_DISTANCE, Color(0.92, 0.92, 0.98), 2.0)
	draw_circle(Vector2.ZERO, stats.hitbox_radius, Color.WHITE)


func _draw_heart_pips() -> void:
	var spacing := 4.0
	var start_x := -(health.max_hearts - 1) * spacing / 2.0
	for i: int in health.max_hearts:
		var filled := i < health.hearts
		draw_circle(Vector2(start_x + i * spacing, stats.body_radius + 5.0), 1.5,
			HEART_COLOR if filled else HEART_EMPTY_COLOR)


func _draw_tombstone(color: Color) -> void:
	draw_rect(Rect2(-5, -7, 10, 12), TOMBSTONE_COLOR)
	draw_circle(Vector2(0, -7), 5.0, TOMBSTONE_COLOR)
	draw_rect(Rect2(-1, -9, 2, 8), color)
	draw_rect(Rect2(-3, -6, 6, 2), color)


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
	if PlayerMotor.step(state, input, stats, bounds, delta):
		shot_requested.emit(self, input.seq)


## Client -> host, every tick. Unreliable: a lost packet is cheaper than a delay.
@rpc("any_peer", "call_remote", "unreliable_ordered", 2)
func _submit_input(seq: int, move: Vector2, aim: float, fire: bool, dash_count: int) -> void:
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
	_input_queue.append(input)
	while _input_queue.size() > MAX_QUEUED_INPUTS:
		_input_queue.pop_front()
