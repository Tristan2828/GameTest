class_name Arena
extends Node2D
## One stage of a run: players, the enemy horde, and bullets.
##
## Every physics tick (while the run is being played) runs in a fixed order:
## players -> spawning -> enemies -> contact damage -> bullets -> hits -> phase check.
## The host then sends snapshots to every client that has finished loading.

signal restart_requested

enum Phase { PLAYING, STAGE_CLEAR, RUN_OVER }

const PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")
const BOUNDS: Rect2 = Rect2(0, 0, 1600, 1000)
const STAGE_DURATION: float = 300.0
## 60 physics ticks per second / 2 = 30 player snapshots per second.
const PLAYER_SNAPSHOT_INTERVAL_TICKS: int = 2
## Enemies are smoothed on clients anyway, so 15 per second is plenty.
const ENEMY_SNAPSHOT_INTERVAL_TICKS: int = 4
const SPAWN_OFFSETS: Array[Vector2] = [Vector2(-24, -24), Vector2(24, -24), Vector2(-24, 24), Vector2(24, 24)]
## Enemies appear just off-screen: the screen is 640x360, so ~367 px to a corner.
const SPAWN_DISTANCE_MIN: float = 380.0
const SPAWN_DISTANCE_MAX: float = 440.0
const MIN_SPAWN_DISTANCE_FROM_ANY_PLAYER: float = 340.0
const PACK_RADIUS: float = 28.0
const GRID_SIZE: int = 32
const FLOOR_COLOR: Color = Color(0.09, 0.08, 0.11)
const GRID_COLOR: Color = Color(0.13, 0.12, 0.16)
const WALL_COLOR: Color = Color(0.4, 0.33, 0.5)
const CONTROLS_HINT: String = "WASD / L-stick move   Mouse / R-stick aim   LMB / RT fire   Space / LT dash   Esc leave"
const COPIED_FEEDBACK_SECONDS: float = 4.0
## In --autopilot test mode, the host restarts by itself this long after a stage ends.
const AUTOPILOT_RESTART_DELAY: float = 2.0

var _phase: Phase = Phase.PLAYING
var _elapsed: float = 0.0
var _stage_duration: float = STAGE_DURATION
## Host: peers whose arena has loaded, so they can receive snapshots and shots.
var _ready_peers: Dictionary[int, bool] = {}
var _tick: int = 0
var _director: SpawnDirector = SpawnDirector.new(randi())
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Host: kills per peer id (for reports; scoreboards later).
var _kills_by_peer: Dictionary[int, int] = {}
var _copied_feedback_left: float = 0.0
var _announced_invite: bool = false
var _time_since_stage_end: float = 0.0

@onready var _players: Node2D = $Players
@onready var _player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var _enemies: EnemyManager = $Enemies
@onready var _projectiles: ProjectileManager = $Projectiles
@onready var _hud: Hud = $Hud


func _ready() -> void:
	# Every peer needs the spawn function: the host calls it via spawn(), and
	# clients call it automatically with the same data when the spawn replicates.
	_player_spawner.spawn_function = _spawn_player
	_projectiles.bounds = BOUNDS
	_enemies.bounds = BOUNDS
	_rng.randomize()
	if LaunchOptions.stage_seconds > 0.0:
		_stage_duration = LaunchOptions.stage_seconds
	if multiplayer.is_server():
		Net.invite.changed.connect(_on_invite_changed)
		_on_invite_changed()
		_enemies.enemy_killed.connect(_on_enemy_killed)
		multiplayer.peer_connected.connect(_add_player)
		multiplayer.peer_disconnected.connect(_remove_player)
		_add_player(1)
		for peer_id: int in multiplayer.get_peers():
			_add_player(peer_id)
	else:
		_notify_ready.rpc_id(1)


func _physics_process(delta: float) -> void:
	var is_host := multiplayer.is_server()
	if _phase == Phase.PLAYING:
		_elapsed += delta
		for player: Player in _player_nodes():
			player.tick(delta)
		if is_host:
			_spawn_enemies(delta)
			_enemies.tick_host(delta, _alive_player_positions())
			_apply_contact_damage()
		else:
			_enemies.rebuild_grid()
		_projectiles.step(delta)
		_projectiles.resolve_hits(_enemies, is_host)
		if is_host:
			_update_phase()
	elif is_host and LaunchOptions.autopilot:
		_time_since_stage_end += delta
		if _time_since_stage_end >= AUTOPILOT_RESTART_DELAY:
			_time_since_stage_end = -INF
			restart_requested.emit()
	if is_host:
		_tick += 1
		_send_snapshots()


func _process(delta: float) -> void:
	_copied_feedback_left = maxf(_copied_feedback_left - delta, 0.0)
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("copy_invite") and Net.invite.copy_to_clipboard():
		_copied_feedback_left = COPIED_FEEDBACK_SECONDS
	if event.is_action_pressed("restart") and multiplayer.is_server() and _phase != Phase.PLAYING:
		restart_requested.emit()


func _draw() -> void:
	draw_rect(BOUNDS, FLOOR_COLOR)
	for x: int in range(int(BOUNDS.position.x), int(BOUNDS.end.x), GRID_SIZE):
		draw_line(Vector2(x, BOUNDS.position.y), Vector2(x, BOUNDS.end.y), GRID_COLOR)
	for y: int in range(int(BOUNDS.position.y), int(BOUNDS.end.y), GRID_SIZE):
		draw_line(Vector2(BOUNDS.position.x, y), Vector2(BOUNDS.end.x, y), GRID_COLOR)
	draw_rect(BOUNDS, WALL_COLOR, false, 2.0)


## A text summary for headless smoke tests (see LaunchOptions --run-for).
func debug_report() -> String:
	var lines := PackedStringArray()
	var role := "host" if multiplayer.is_server() else "client"
	lines.append("[report] peer %d (%s)  phase=%s  time=%.1fs" % [multiplayer.get_unique_id(), role, Phase.keys()[_phase], _elapsed])
	for player: Player in _player_nodes():
		var line := "[report]   player %d slot %d at %s  hearts %d/%d" % [
			player.peer_id, player.slot, player.position.round(), player.health.hearts, player.health.max_hearts]
		if player.is_local() and not multiplayer.is_server():
			line += "  corrections=%d largest=%.2fpx" % [player.correction_count, player.largest_correction]
		lines.append(line)
	lines.append("[report]   active enemies: %d" % _enemies.active_count())
	if multiplayer.is_server():
		lines.append("[report]   damage by peer: %s" % [_enemies.damage_by_peer])
		lines.append("[report]   kills by peer: %s" % [_kills_by_peer])
		lines.append("[report]   invite: '%s'  %s" % [Net.invite.address, Net.invite.status])
	lines.append("[report]   bullets alive: %d   physics time: %.2f ms/tick" % [_projectiles.count(), Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	return "\n".join(lines)


# --- Players -----------------------------------------------------------------

func _player_nodes() -> Array[Player]:
	var result: Array[Player] = []
	for child: Node in _players.get_children():
		var player := child as Player
		if player != null and not player.is_queued_for_deletion():
			result.append(player)
	return result


func _player_by_id(peer_id: int) -> Player:
	return _players.get_node_or_null(str(peer_id)) as Player


func _local_player() -> Player:
	return _player_by_id(multiplayer.get_unique_id())


func _alive_player_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for player: Player in _player_nodes():
		if not player.is_downed():
			positions.append(player.state.position)
	return positions


func _add_player(peer_id: int) -> void:
	_player_spawner.spawn({"peer_id": peer_id, "slot": _free_slot()})


func _remove_player(peer_id: int) -> void:
	_ready_peers.erase(peer_id)
	var player := _player_by_id(peer_id)
	if player != null:
		player.queue_free()


func _spawn_player(data: Variant) -> Node:
	var info: Dictionary = data
	var peer_id: int = info["peer_id"]
	var slot: int = info["slot"]
	var player: Player = PLAYER_SCENE.instantiate()
	player.setup(peer_id, slot, BOUNDS.get_center() + SPAWN_OFFSETS[slot], BOUNDS)
	player.shot_requested.connect(_on_player_shot_requested)
	return player


func _free_slot() -> int:
	var used: Array[int] = []
	for player: Player in _player_nodes():
		used.append(player.slot)
	for slot: int in Net.MAX_PLAYERS:
		if not used.has(slot):
			return slot
	return 0


# --- Host simulation ---------------------------------------------------------

func _spawn_enemies(delta: float) -> void:
	var alive_players := _alive_player_positions()
	if alive_players.is_empty():
		return
	for type_id: int in _director.tick(delta, _elapsed, alive_players.size(), _enemies.active_count()):
		var point := _offscreen_spawn_point(alive_players)
		if point.is_finite():
			_enemies.spawn(type_id, point)
	if _director.pack_due(_elapsed, _enemies.active_count()):
		var center := _offscreen_spawn_point(alive_players)
		if center.is_finite():
			for i: int in SpawnDirector.PACK_SIZE:
				var offset := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.0, PACK_RADIUS)
				_enemies.spawn(EnemyTypes.Id.SHAMBLER, (center + offset).clamp(BOUNDS.position, BOUNDS.end))


## A point just off-screen from a random player, inside the arena and not too
## close to anyone. Returns Vector2.INF if none was found (spawn is skipped).
func _offscreen_spawn_point(alive_players: Array[Vector2]) -> Vector2:
	var inner := BOUNDS.grow(-16.0)
	for attempt: int in 12:
		var around := alive_players[_rng.randi() % alive_players.size()]
		var distance := _rng.randf_range(SPAWN_DISTANCE_MIN, SPAWN_DISTANCE_MAX)
		var point := around + Vector2.from_angle(_rng.randf() * TAU) * distance
		if inner.has_point(point) and _far_from_players(point, alive_players):
			return point
	return Vector2.INF


func _far_from_players(point: Vector2, alive_players: Array[Vector2]) -> bool:
	for player_position: Vector2 in alive_players:
		if point.distance_to(player_position) < MIN_SPAWN_DISTANCE_FROM_ANY_PLAYER:
			return false
	return true


func _apply_contact_damage() -> void:
	for player: Player in _player_nodes():
		if not player.can_be_hit():
			continue
		var enemy := _enemies.find_hit(player.state.position, player.stats.hitbox_radius)
		if enemy != null:
			player.health.take_hit(enemy.type.contact_damage, player.stats.hit_invulnerability)


func _update_phase() -> void:
	var players := _player_nodes()
	if not players.is_empty() and _alive_player_positions().is_empty():
		_end_stage(Phase.RUN_OVER)
	elif _elapsed >= _stage_duration:
		_end_stage(Phase.STAGE_CLEAR)


func _end_stage(phase: Phase) -> void:
	_phase = phase
	_enemies.clear_all()
	_projectiles.clear()
	print("Stage ended: %s at %.1fs" % [Phase.keys()[phase], _elapsed])


func _on_enemy_killed(_enemy: Enemy, killer_peer_id: int) -> void:
	_kills_by_peer[killer_peer_id] = _kills_by_peer.get(killer_peer_id, 0) + 1


# --- Shots -------------------------------------------------------------------

## Runs on the host for every player's shot, and on a client for its own
## predicted shots. Only the host tells other peers about it.
func _on_player_shot_requested(shooter: Player, input_seq: int) -> void:
	var pattern := shooter.stats.shot_pattern
	var origin := shooter.muzzle_position()
	var aim := shooter.state.aim
	var seed_value := ShotPatterns.make_seed(shooter.peer_id, input_seq)
	_spawn_shot(shooter.peer_id, pattern, origin, aim, seed_value)
	if multiplayer.is_server():
		for peer_id: int in _ready_peers:
			# The shooter already predicted this shot itself.
			if peer_id != shooter.peer_id:
				_receive_shot.rpc_id(peer_id, shooter.peer_id, pattern, origin, aim, seed_value)


func _spawn_shot(shooter_id: int, pattern: ShotPatterns.Id, origin: Vector2, aim: float, seed_value: int) -> void:
	var shooter := _player_by_id(shooter_id)
	if shooter == null:
		return
	var stats := shooter.stats
	for angle: float in ShotPatterns.angles(pattern, aim, seed_value):
		_projectiles.spawn(origin, Vector2.from_angle(angle) * stats.bullet_speed, stats.bullet_damage, stats.bullet_lifetime, shooter_id)


# --- HUD ---------------------------------------------------------------------

func _update_hud() -> void:
	var local := _local_player()
	if local != null:
		_hud.set_hearts(local.health.hearts, local.health.max_hearts)
	_hud.set_time_left(_stage_duration - _elapsed)

	var status := "Solo"
	if Net.is_online():
		status = "Host" if multiplayer.is_server() else "Client  ping %d ms" % Net.ping_ms()
	_hud.set_status("%s   players %d" % [status, _player_nodes().size()])

	var info := CONTROLS_HINT
	if Net.is_online() and multiplayer.is_server():
		info = _invite_hud_text() + "\n" + info
	_hud.set_info(info)

	var restart_hint := "Press R / Start to play again" if multiplayer.is_server() else "Waiting for the host to restart..."
	match _phase:
		Phase.STAGE_CLEAR:
			_hud.show_banner("Stage clear!", restart_hint)
		Phase.RUN_OVER:
			_hud.show_banner("Run over", restart_hint)
		_:
			if local != null and local.is_downed():
				_hud.show_banner("You're down", "Your friends fight on. (Ghosts come in a later milestone.)")
			else:
				_hud.hide_banner()


func _invite_hud_text() -> String:
	var invite := Net.invite
	var line := "Invite: finding your public address..."
	if not invite.address.is_empty():
		var hint := "copied to clipboard!" if _copied_feedback_left > 0.0 else "F1 to copy"
		line = "Invite: %s   (%s)" % [invite.address, hint]
	return line + "\n" + invite.status


func _on_invite_changed() -> void:
	# The invite is copied automatically the moment the address is known.
	if not Net.invite.address.is_empty() and not _announced_invite:
		_announced_invite = true
		_copied_feedback_left = COPIED_FEEDBACK_SECONDS


# --- Networking --------------------------------------------------------------

func _send_snapshots() -> void:
	if _ready_peers.is_empty():
		return
	var peers: Array[int] = []
	peers.assign(_ready_peers.keys())
	if _tick % PLAYER_SNAPSHOT_INTERVAL_TICKS == 0:
		var ids := PackedInt32Array()
		var positions := PackedVector2Array()
		var aims := PackedFloat32Array()
		var acks := PackedInt32Array()
		var hearts := PackedByteArray()
		var max_hearts := PackedByteArray()
		var flags := PackedByteArray()
		for player: Player in _player_nodes():
			ids.append(player.peer_id)
			positions.append(player.state.position)
			aims.append(player.state.aim)
			acks.append(player.last_processed_seq)
			hearts.append(player.health.hearts)
			max_hearts.append(player.health.max_hearts)
			flags.append((1 if player.state.is_dashing() else 0) | (2 if player.health.is_invulnerable() else 0))
		for peer_id: int in peers:
			_receive_player_snapshot.rpc_id(peer_id, ids, positions, aims, acks, hearts, max_hearts, flags, _elapsed, _phase)
	if _tick % ENEMY_SNAPSHOT_INTERVAL_TICKS == 0:
		_enemies.send_snapshot(peers)


## Client -> host, once, when this client's arena has loaded.
@rpc("any_peer", "call_remote", "reliable")
func _notify_ready() -> void:
	if multiplayer.is_server():
		_ready_peers[multiplayer.get_remote_sender_id()] = true


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _receive_player_snapshot(ids: PackedInt32Array, positions: PackedVector2Array, aims: PackedFloat32Array,
		acks: PackedInt32Array, hearts: PackedByteArray, max_hearts: PackedByteArray, flags: PackedByteArray,
		elapsed: float, phase: int) -> void:
	for i: int in ids.size():
		var player := _player_by_id(ids[i])
		if player != null:
			player.apply_server_state(positions[i], aims[i], (flags[i] & 1) != 0, acks[i], hearts[i], max_hearts[i], (flags[i] & 2) != 0)
	_elapsed = elapsed
	if phase != _phase:
		_phase = phase as Phase
		if _phase != Phase.PLAYING:
			_projectiles.clear()


@rpc("authority", "call_remote", "reliable")
func _receive_shot(shooter_id: int, pattern: int, origin: Vector2, aim: float, seed_value: int) -> void:
	_spawn_shot(shooter_id, pattern as ShotPatterns.Id, origin, aim, seed_value)
