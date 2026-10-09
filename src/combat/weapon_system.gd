class_name WeaponSystem
extends Node2D
## Runs every player's automatic weapons and the weapon altars.
##
## Host: deals all weapon damage, fires Seeking Bolts, spawns altars, and decides
## who grabs them. Everyone: draws the altars. (Players draw their own skulls and
## aura from the shared stage clock, so those never need syncing.)

## Every peer: this player gained a level in this weapon (the arena applies it).
signal weapon_gained(peer_id: int, weapon_id: int)
## Host: fire a Seeking Bolts volley (the arena spawns it and tells clients).
signal seeker_fired(shooter: Player, aim: float, level: int)

## Stage times (seconds) when an altar appears.
const ALTAR_TIMES: Array[float] = [80.0, 160.0]
const ALTAR_DISTANCE_MIN: float = 140.0
const ALTAR_DISTANCE_MAX: float = 240.0
const ALTAR_PICKUP_RADIUS: float = 12.0
## Coins instead, when the weapon on the altar is already at max level.
const MAXED_WEAPON_COINS: int = 10
const ALTAR_BASE_COLOR: Color = Color(0.3, 0.27, 0.35)
const ALTAR_TOP_COLOR: Color = Color(0.42, 0.38, 0.48)

var bounds: Rect2 = Rect2(0, 0, 1600, 1000)

## altar id -> [position, weapon id]
var _altars: Dictionary[int, Array] = {}
var _next_altar_id: int = 0
var _next_altar_index: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
# Host weapon timers: "peer:weapon" -> seconds until next volley/pulse.
var _timers: Dictionary[String, float] = {}
# Host orbit hit cooldowns: "peer:enemy" -> stage time when that enemy can be bitten again.
var _orbit_ready_at: Dictionary[String, float] = {}


func _ready() -> void:
	_rng.randomize()
	add_to_group("altars")


## Host: called every tick while the stage is being played.
func tick_host(delta: float, clock: float, players: Array[Player], enemies: EnemyManager, ready_peers: Array[int]) -> void:
	_maybe_spawn_altar(clock, players, ready_peers)
	_check_altar_pickups(players, ready_peers)
	for player: Player in players:
		if player.is_downed():
			continue
		for weapon_id: int in player.weapon_levels:
			_tick_weapon(player, weapon_id, player.weapon_levels[weapon_id], delta, clock, enemies)


## Host: new stage. Altars and timers reset; owned weapons stay.
func reset_stage() -> void:
	_altars.clear()
	_next_altar_index = 0
	_timers.clear()
	_orbit_ready_at.clear()
	queue_redraw()


func clear_altars() -> void:
	_altars.clear()
	queue_redraw()


## Position of the closest altar, or Vector2.INF (used by the autopilot).
func nearest_altar(from: Vector2) -> Vector2:
	var best := Vector2.INF
	for altar_id: int in _altars:
		var at: Vector2 = _altars[altar_id][0]
		if best == Vector2.INF or from.distance_squared_to(at) < from.distance_squared_to(best):
			best = at
	return best


func altar_positions() -> PackedVector2Array:
	var positions := PackedVector2Array()
	for altar_id: int in _altars:
		positions.append(_altars[altar_id][0])
	return positions


func altar_count() -> int:
	return _altars.size()


## Host: send every altar on the ground to a newly joined peer.
func send_full_state(peer_id: int) -> void:
	for altar_id: int in _altars:
		_receive_altar_spawned.rpc_id(peer_id, altar_id, _altars[altar_id][0], _altars[altar_id][1])


## Host: tell a late joiner every player's weapon levels.
func send_history(peer_id: int, players: Array[Player]) -> void:
	for player: Player in players:
		for weapon_id: int in player.weapon_levels:
			for i: int in player.weapon_levels[weapon_id]:
				_receive_weapon_gained.rpc_id(peer_id, player.peer_id, weapon_id)


func _draw() -> void:
	for altar_id: int in _altars:
		var at: Vector2 = _altars[altar_id][0]
		var weapon := AutoWeapons.get_weapon(_altars[altar_id][1])
		var glow := 0.25 + 0.15 * sin(Time.get_ticks_msec() / 200.0)
		draw_circle(at, 16.0, Color(weapon.color, glow * 0.4))
		draw_rect(Rect2(at + Vector2(-7, 2), Vector2(14, 6)), ALTAR_BASE_COLOR)
		draw_rect(Rect2(at + Vector2(-5, -2), Vector2(10, 4)), ALTAR_TOP_COLOR)
		PixelArt.draw(self, weapon.icon, at + Vector2(0, -9 + 1.5 * sin(Time.get_ticks_msec() / 300.0)).round())


func _process(_delta: float) -> void:
	if not _altars.is_empty():
		queue_redraw()


# --- Host: weapons -----------------------------------------------------------

func _tick_weapon(player: Player, weapon_id: int, level: int, delta: float, clock: float, enemies: EnemyManager) -> void:
	var weapon := AutoWeapons.get_weapon(weapon_id)
	match weapon.kind:
		AutoWeapon.Kind.ORBIT:
			for skull: Vector2 in AutoWeapons.orbit_positions(player.state.position, level, clock):
				var enemy := enemies.find_hit(skull, weapon.radius_at(level))
				if enemy == null:
					continue
				var key := "%d:%d" % [player.peer_id, enemy.pool_index]
				if _orbit_ready_at.get(key, -1.0) > clock:
					continue
				_orbit_ready_at[key] = clock + weapon.interval_at(level)
				enemies.damage(enemy, weapon.damage_at(level), player.peer_id, DamageSource.of_weapon(weapon_id))
		AutoWeapon.Kind.SEEKER:
			if _cooldown_done(player, weapon_id, delta, weapon.interval_at(level)):
				var target := enemies.find_nearest(player.state.position, weapon.reach)
				if target != null:
					seeker_fired.emit(player, (target.position - player.state.position).angle(), level)
				else:
					# Nothing in range: try again soon instead of waiting a full interval.
					_timers["%d:%d" % [player.peer_id, weapon_id]] = 0.2
		AutoWeapon.Kind.AURA:
			if _cooldown_done(player, weapon_id, delta, weapon.interval_at(level)):
				enemies.damage_in_radius(player.state.position, weapon.radius_at(level), weapon.damage_at(level), player.peer_id,
					DamageSource.of_weapon(weapon_id))


## Counts down this weapon's timer; true (and restarted) when it's time to fire.
func _cooldown_done(player: Player, weapon_id: int, delta: float, interval: float) -> bool:
	var key := "%d:%d" % [player.peer_id, weapon_id]
	var left: float = _timers.get(key, interval) - delta
	if left > 0.0:
		_timers[key] = left
		return false
	_timers[key] = interval
	return true


# --- Host: altars ------------------------------------------------------------

func _maybe_spawn_altar(clock: float, players: Array[Player], ready_peers: Array[int]) -> void:
	if _next_altar_index >= ALTAR_TIMES.size() or clock < ALTAR_TIMES[_next_altar_index]:
		return
	_next_altar_index += 1
	var alive: Array[Player] = []
	for player: Player in players:
		if not player.is_downed():
			alive.append(player)
	if alive.is_empty():
		return
	var around := alive[_rng.randi() % alive.size()].state.position
	var inner := bounds.grow(-30.0)
	var at := around
	for attempt: int in 10:
		var distance := _rng.randf_range(ALTAR_DISTANCE_MIN, ALTAR_DISTANCE_MAX)
		at = around + Vector2.from_angle(_rng.randf() * TAU) * distance
		if inner.has_point(at):
			break
	at = at.clamp(inner.position, inner.end).round()
	var altar_id := _next_altar_id
	_next_altar_id += 1
	var weapon_id := _rng.randi() % AutoWeapons.ALL.size()
	_add_altar(altar_id, at, weapon_id)
	for peer_id: int in ready_peers:
		_receive_altar_spawned.rpc_id(peer_id, altar_id, at, weapon_id)


func _check_altar_pickups(players: Array[Player], ready_peers: Array[int]) -> void:
	for altar_id: int in _altars.keys():
		var at: Vector2 = _altars[altar_id][0]
		var weapon_id: int = _altars[altar_id][1]
		for player: Player in players:
			if player.is_downed() or player.state.position.distance_to(at) > ALTAR_PICKUP_RADIUS:
				continue
			_altars.erase(altar_id)
			queue_redraw()
			for peer_id: int in ready_peers:
				_receive_altar_taken.rpc_id(peer_id, altar_id)
			if player.weapon_levels.get(weapon_id, 0) >= AutoWeapons.MAX_LEVEL:
				player.coins += MAXED_WEAPON_COINS
			else:
				grant(player.peer_id, weapon_id, ready_peers)
			break


## Host: give a player a weapon level, here and on every client.
func grant(peer_id: int, weapon_id: int, ready_peers: Array[int]) -> void:
	weapon_gained.emit(peer_id, weapon_id)
	for target: int in ready_peers:
		_receive_weapon_gained.rpc_id(target, peer_id, weapon_id)


func _add_altar(altar_id: int, at: Vector2, weapon_id: int) -> void:
	_altars[altar_id] = [at, weapon_id]
	queue_redraw()


# --- Network messages ------------------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func _receive_altar_spawned(altar_id: int, at: Vector2, weapon_id: int) -> void:
	if AutoWeapons.is_valid_id(weapon_id):
		_add_altar(altar_id, at, weapon_id)


@rpc("authority", "call_remote", "reliable")
func _receive_altar_taken(altar_id: int) -> void:
	_altars.erase(altar_id)
	queue_redraw()


@rpc("authority", "call_remote", "reliable")
func _receive_weapon_gained(peer_id: int, weapon_id: int) -> void:
	if AutoWeapons.is_valid_id(weapon_id):
		weapon_gained.emit(peer_id, weapon_id)
