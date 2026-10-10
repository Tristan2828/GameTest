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
## Every peer: this player just lost HP (for effects; `amount` = how much).
signal hurt(victim: Player, amount: int)
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
const HP_COLOR: Color = Color(0.9, 0.2, 0.3)
const HP_EMPTY_COLOR: Color = Color(0.25, 0.15, 0.18)
## The little HP bar under every hero.
const HP_BAR_WIDTH: float = 14.0
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
## Host: HP lost to hits this run.
var hp_lost: int = 0
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
var _last_seen_hp: int = -1
## Walk bob height in pixels, and the last movement direction (the hero faces it).
var _bob: float = 0.0
var _walk_time: float = 0.0
var _walking: bool = false
var _last_move: Vector2 = Vector2.RIGHT
var _last_drawn_position: Vector2 = Vector2.ZERO
var _shake: float = 0.0

@onready var _camera: Camera2D = $Camera2D


## Called by the arena's spawn function, before the node enters the tree.
func setup(owner_peer_id: int, player_slot: int, spawn_position: Vector2, arena_bounds: Rect2,
		character: int = Characters.Id.WANDERER, hp_bonus: int = 0,
		boost_ranks: PackedInt32Array = PackedInt32Array()) -> void:
	peer_id = owner_peer_id
	slot = player_slot
	bounds = arena_bounds
	character_id = character
	name = str(owner_peer_id)
	# Each player gets its own copy so upgrades only change this player.
	stats = Characters.get_character(character).duplicate()
	stats.max_hp = maxi(stats.max_hp + hp_bonus, 1)  # Difficulty setting.
	Embers.apply(boost_ranks, stats)  # This player's Ember Shrine boosts (empty when off).
	health.reset(stats.max_hp)
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


## The player's chosen name (title menu), or their slot color ("Red").
func display_name() -> String:
	return Net.name_of(peer_id, slot)


## Runs on every peer when the host announces this player's pick.
func apply_upgrade(upgrade_id: int) -> void:
	upgrade_ids.append(upgrade_id)
	Upgrades.apply(upgrade_id, stats, health)
	queue_redraw()


## Host: an enemy bullet hit this player. Returns true if it landed.
func take_bullet(amount: int) -> bool:
	var before := health.hp
	return _after_hit(before, health.take_bullet(amount, stats.hit_invulnerability))


## Host: enemies are touching this player (`amount` = all of them together).
## Drains every PlayerHealth.CONTACT_INTERVAL. Returns true if it landed.
func take_contact(amount: int) -> bool:
	var before := health.hp
	return _after_hit(before, health.take_contact(amount))


func _after_hit(hp_before: int, landed: bool) -> bool:
	hp_lost += hp_before - health.hp
	if LaunchOptions.invincible:
		# Test flag: hits still count (balance numbers) but HP refills.
		health.hp = health.max_hp
		return landed
	if landed and health.is_downed():
		times_downed += 1
		print("Player %d downed" % peer_id)
	return landed


## Host: a teammate filled the revive circle. Back up with some HP and a
## moment of safety, right where they fell.
func revive() -> void:
	health.hp = Revive.hp_after(health.max_hp)
	health.invulnerable_left = Revive.INVULNERABILITY
	revive_progress = 0.0
	print("Player %d revived" % peer_id)


## Host: back to full strength at a new spot (start of a stage).
func respawn(at: Vector2) -> void:
	health.reset(stats.max_hp)
	revive_progress = 0.0
	state.position = at
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


func is_downed() -> bool:
	return health.is_downed()


## Checked when an enemy bullet touches this player (bullets pass through
## otherwise). Works on clients too, using the latest known state.
func can_be_shot() -> bool:
	return not health.is_downed() and not health.is_bullet_safe()


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
		health.tick(delta, stats.recovery)
		if is_local():
			_simulate(_read_local_input(), delta)
		else:
			_simulate_queued_inputs(delta)
	elif is_local():
		var input := _read_local_input()
		_submit_input.rpc_id(1, input.seq, input.move, input.aim, input.fire)
		_simulate(input, delta)
		_predictor.record(input.seq, state.position)


## Client: apply this player's entry from a host snapshot.
func apply_server_state(server_position: Vector2, aim: float, ack_seq: int,
		hp: int, max_hp: int, bullet_safe: bool) -> void:
	health.max_hp = max_hp
	health.hp = hp
	# Lets bullets pass through on this screen too, and makes the hero flash.
	health.bullet_safe_left = 1.0 if bullet_safe else 0.0
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


## Local player only: shake the camera (strength in pixels, fades quickly).
func add_shake(strength: float) -> void:
	if is_local() and Settings.screen_shake:
		_shake = maxf(_shake, strength)


func _process(delta: float) -> void:
	if _last_seen_hp >= 0 and health.hp < _last_seen_hp:
		var lost := _last_seen_hp - health.hp
		hurt.emit(self, lost)
		add_shake(clampf(1.5 + lost / 4.0, 2.0, 6.0))
	elif _last_seen_hp == 0 and health.hp > 0:
		revived.emit(self)
	_last_seen_hp = health.hp
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
	if not is_local() and Net.is_online():
		_draw_name_tag(color)
	if health.is_downed():
		_draw_downed(color)
		return
	_draw_hp_bar()
	_draw_weapons()
	var modulate := Color.WHITE
	# Blink while safe from bullets after a hit (or after a revive).
	if health.is_bullet_safe() and int(Time.get_ticks_msec() / 80.0) % 2 == 0:
		modulate = Color(1, 1, 1, 0.3)
	var sprite := PixelArt.walk_frame(stats.sprite, _bob > 0.0 or _walking, _walk_time * WALK_STEPS_PER_SECOND)
	# Heroes face the way they last moved (nobody aims any more).
	PixelArt.draw(self, sprite, Vector2(0, -2 - _bob), color, false, _last_move.x < 0.0, 1.0, modulate)
	# The real hitbox, always visible: in a bullet hell you dodge with this dot.
	draw_circle(Vector2.ZERO, stats.hitbox_radius + 0.5, HITBOX_OUTLINE_COLOR)
	draw_circle(Vector2.ZERO, stats.hitbox_radius, Color.WHITE)


## Teammates' names float over their heads (co-op), in their color.
func _draw_name_tag(color: Color) -> void:
	var text := display_name()
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	var top := -24.0 if health.is_downed() else -2.0 - PixelArt.size_of(stats.sprite).y / 2.0 - 4.0
	var at := Vector2(-width / 2.0, top).round()
	draw_string(font, at + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, HITBOX_OUTLINE_COLOR)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, color.lightened(0.25))


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


## A small HP bar under the hero (everyone's, so teammates see who's hurting).
func _draw_hp_bar() -> void:
	var top := stats.body_radius + 4.0
	var left := -HP_BAR_WIDTH / 2.0
	draw_rect(Rect2(left - 1.0, top - 1.0, HP_BAR_WIDTH + 2.0, 4.0), HITBOX_OUTLINE_COLOR)
	draw_rect(Rect2(left, top, HP_BAR_WIDTH, 2.0), HP_EMPTY_COLOR)
	draw_rect(Rect2(left, top, ceilf(HP_BAR_WIDTH * health.ratio()), 2.0), HP_COLOR)


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
		# Downed players lie still until revived: no moving or attacking.
		input.move = Vector2.ZERO
		input.fire = false
	var result := PlayerMotor.step(state, input, stats, bounds, delta)
	if result & PlayerMotor.FIRED:
		shot_requested.emit(self, input.seq)


## Client -> host, every tick. Unreliable: a lost packet is cheaper than a delay.
@rpc("any_peer", "call_remote", "unreliable_ordered", 2)
func _submit_input(seq: int, move: Vector2, aim: float, fire: bool) -> void:
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
	_input_queue.append(input)
	while _input_queue.size() > MAX_QUEUED_INPUTS:
		_input_queue.pop_front()
