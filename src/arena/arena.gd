class_name Arena
extends Node2D
## Milestone 1 test arena: players, training dummies, and bullets.
##
## Every physics tick runs in a fixed order: players -> enemies -> bullets -> hits.
## The host then sends snapshots (30 per second) to every client that has
## finished loading the arena.

const PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")
const BOUNDS: Rect2 = Rect2(0, 0, 960, 540)
## 60 physics ticks per second / 2 = 30 snapshots per second.
const SNAPSHOT_INTERVAL_TICKS: int = 2
const DUMMY_COUNT: int = 6
const DUMMY_RING_RADIUS: float = 140.0
const SPAWN_OFFSETS: Array[Vector2] = [Vector2(-24, -24), Vector2(24, -24), Vector2(-24, 24), Vector2(24, 24)]
const GRID_SIZE: int = 32
const FLOOR_COLOR: Color = Color(0.09, 0.08, 0.11)
const GRID_COLOR: Color = Color(0.13, 0.12, 0.16)
const WALL_COLOR: Color = Color(0.4, 0.33, 0.5)
const CONTROLS_HINT: String = "WASD / L-stick move   Mouse / R-stick aim   LMB / RT fire   Space / LT dash   Esc leave"

const COPIED_FEEDBACK_SECONDS: float = 4.0

## Host: peers whose arena has loaded, so they can receive snapshots and shots.
var _ready_peers: Dictionary[int, bool] = {}
var _tick: int = 0
var _copied_feedback_left: float = 0.0
var _announced_invite: bool = false

@onready var _players: Node2D = $Players
@onready var _player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var _enemies: EnemyManager = $Enemies
@onready var _projectiles: ProjectileManager = $Projectiles
@onready var _hud_label: Label = %HudLabel


func _ready() -> void:
	# Every peer needs the spawn function: the host calls it via spawn(), and
	# clients call it automatically with the same data when the spawn replicates.
	_player_spawner.spawn_function = _spawn_player
	_projectiles.bounds = BOUNDS
	if multiplayer.is_server():
		Net.invite.changed.connect(_on_invite_changed)
		_on_invite_changed()
		multiplayer.peer_connected.connect(_add_player)
		multiplayer.peer_disconnected.connect(_remove_player)
		_enemies.spawn_dummies(_dummy_spots())
		_add_player(1)
		for peer_id: int in multiplayer.get_peers():
			_add_player(peer_id)
	else:
		_notify_ready.rpc_id(1)


func _physics_process(delta: float) -> void:
	var is_host := multiplayer.is_server()
	for player: Player in _player_nodes():
		player.tick(delta)
	if is_host:
		_enemies.tick_host(delta)
	_projectiles.step(delta)
	_projectiles.resolve_hits(_enemies, is_host)
	if is_host:
		_tick += 1
		if _tick % SNAPSHOT_INTERVAL_TICKS == 0:
			_send_snapshots()


func _process(delta: float) -> void:
	_copied_feedback_left = maxf(_copied_feedback_left - delta, 0.0)
	var role := "Solo"
	if Net.is_online():
		role = "Host" if multiplayer.is_server() else "Client  ping %d ms" % Net.ping_ms()
	var text := "%s   players %d\n%s" % [role, _player_nodes().size(), CONTROLS_HINT]
	if Net.is_online() and multiplayer.is_server():
		text += "\n" + _invite_hud_text()
	_hud_label.text = text


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("copy_invite") and Net.invite.copy_to_clipboard():
		_copied_feedback_left = COPIED_FEEDBACK_SECONDS


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
	lines.append("[report] peer %d (%s)" % [multiplayer.get_unique_id(), role])
	for player: Player in _player_nodes():
		var line := "[report]   player %d slot %d at %s" % [player.peer_id, player.slot, player.position.round()]
		if player.is_local() and not multiplayer.is_server():
			line += "  corrections=%d largest=%.2fpx" % [player.correction_count, player.largest_correction]
		lines.append(line)
	lines.append("[report]   active enemies: %d" % _enemies.active_count())
	if multiplayer.is_server():
		lines.append("[report]   damage by peer: %s" % [_enemies.damage_by_peer])
		lines.append("[report]   invite: '%s'  %s" % [Net.invite.address, Net.invite.status])
	lines.append("[report]   bullets alive: %d" % _projectiles.count())
	return "\n".join(lines)


func _player_nodes() -> Array[Player]:
	var result: Array[Player] = []
	for child: Node in _players.get_children():
		var player := child as Player
		if player != null and not player.is_queued_for_deletion():
			result.append(player)
	return result


func _player_by_id(peer_id: int) -> Player:
	return _players.get_node_or_null(str(peer_id)) as Player


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


func _dummy_spots() -> Array[Vector2]:
	var spots: Array[Vector2] = []
	for i: int in DUMMY_COUNT:
		spots.append(BOUNDS.get_center() + Vector2.from_angle(TAU * i / DUMMY_COUNT) * DUMMY_RING_RADIUS)
	return spots


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


func _send_snapshots() -> void:
	if _ready_peers.is_empty():
		return
	var ids := PackedInt32Array()
	var positions := PackedVector2Array()
	var aims := PackedFloat32Array()
	var dashing := PackedByteArray()
	var acks := PackedInt32Array()
	for player: Player in _player_nodes():
		ids.append(player.peer_id)
		positions.append(player.state.position)
		aims.append(player.state.aim)
		dashing.append(1 if player.state.is_dashing() else 0)
		acks.append(player.last_processed_seq)
	var peers: Array[int] = []
	peers.assign(_ready_peers.keys())
	for peer_id: int in peers:
		_receive_player_snapshot.rpc_id(peer_id, ids, positions, aims, dashing, acks)
	_enemies.send_snapshot(peers)


## Client -> host, once, when this client's arena has loaded.
@rpc("any_peer", "call_remote", "reliable")
func _notify_ready() -> void:
	if multiplayer.is_server():
		_ready_peers[multiplayer.get_remote_sender_id()] = true


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _receive_player_snapshot(ids: PackedInt32Array, positions: PackedVector2Array, aims: PackedFloat32Array, dashing: PackedByteArray, acks: PackedInt32Array) -> void:
	for i: int in ids.size():
		var player := _player_by_id(ids[i])
		if player != null:
			player.apply_server_state(positions[i], aims[i], dashing[i] != 0, acks[i])


@rpc("authority", "call_remote", "reliable")
func _receive_shot(shooter_id: int, pattern: int, origin: Vector2, aim: float, seed_value: int) -> void:
	_spawn_shot(shooter_id, pattern as ShotPatterns.Id, origin, aim, seed_value)
