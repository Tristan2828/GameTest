class_name WeaponSystem
extends Node2D
## Runs every player's automatic weapons and the weapon altars.
##
## Host: deals all weapon damage, fires Seeking Bolts, spawns altars, and decides
## who grabs them. Everyone: draws the altars. (Players draw their own skulls and
## aura from the shared stage clock, so those never need syncing.)
##
## The newer weapons are shown on every peer from small events (a scythe throw,
## a lightning path, spear spots) or, for Hellfire Trail, from where each player
## walks; only the host's copies deal damage.

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
## Hellfire Trail: a new flame every this many pixels walked.
const TRAIL_SPACING: float = 10.0
## How long a lightning path and an erupted spear stay visible.
const BOLT_SECONDS: float = 0.25
const SPEAR_SHOW_SECONDS: float = 0.35
## Scythes spin this fast (radians per second, drawing only).
const SCYTHE_SPIN: float = 14.0
const SPEAR_COLOR: Color = Color(0.9, 0.86, 0.72)

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
# Host: peers to tell about throws, lightning and spears (set every tick).
var _ready_peers: Array[int] = []
## Everyone: scythes in flight, flames on the ground, spears about to strike,
## lightning paths fading out.
var _scythes: Array[Scythe] = []
var _flames: Array[Flame] = []
var _spears: Array[Spear] = []
var _bolts: Array[Bolt] = []
## Everyone: where each player last dropped a flame (peer id -> position).
var _last_flame_at: Dictionary[int, Vector2] = {}
## Drawn above the enemies: scythes, lightning and erupting spears.
var _overlay: Node2D = null


## A Reaper's Scythe in flight (follows its thrower: out and back).
class Scythe:
	var owner_id: int
	var angle: float
	var age: float = 0.0
	var duration: float
	var reach: float
	var radius: float
	var damage: int
	var position: Vector2 = Vector2.INF
	## Host: enemy pool index -> scythe age when it was last cut (once per pass).
	var hit_at: Dictionary[int, float] = {}


## One patch of Hellfire Trail.
class Flame:
	var owner_id: int
	var position: Vector2
	var age: float = 0.0
	var duration: float
	var radius: float


## A Bone Spear: a warning circle, then the strike.
class Spear:
	var owner_id: int
	var position: Vector2
	var age: float = 0.0
	var warning: float
	var radius: float
	var damage: int
	var struck: bool = false


## A Chain Lightning path, fading out.
class Bolt:
	var points: PackedVector2Array
	var age: float = 0.0
	var seed_value: int


func _ready() -> void:
	_rng.randomize()
	add_to_group("altars")
	_overlay = Node2D.new()
	_overlay.z_index = 2
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)


## Host: called every tick while the stage is being played.
func tick_host(delta: float, clock: float, players: Array[Player], enemies: EnemyManager, ready_peers: Array[int]) -> void:
	_ready_peers = ready_peers
	_maybe_spawn_altar(clock, players, ready_peers)
	_check_altar_pickups(players, ready_peers)
	for player: Player in players:
		if player.is_downed():
			continue
		for weapon_id: int in player.weapon_levels:
			_tick_weapon(player, weapon_id, player.weapon_levels[weapon_id], delta, clock, enemies)


## Everyone, every tick of play: move scythes, light and age flames, count down
## spears and fade lightning. The host also deals the damage here.
func tick_effects(delta: float, players: Array[Player], enemies: EnemyManager, is_host: bool) -> void:
	_drop_flames(players)
	for i: int in range(_scythes.size() - 1, -1, -1):
		var scythe := _scythes[i]
		scythe.age += delta
		var thrower := _find_player(players, scythe.owner_id)
		if scythe.age >= scythe.duration or thrower == null:
			_scythes.remove_at(i)
			continue
		scythe.position = AutoWeapons.scythe_position(thrower.world_position(), scythe.angle, scythe.reach,
			scythe.age / scythe.duration)
		if is_host:
			_scythe_hits(scythe, enemies)
	for i: int in range(_flames.size() - 1, -1, -1):
		_flames[i].age += delta
		if _flames[i].age >= _flames[i].duration:
			_flames.remove_at(i)
	for i: int in range(_spears.size() - 1, -1, -1):
		var spear := _spears[i]
		spear.age += delta
		if not spear.struck and spear.age >= spear.warning:
			spear.struck = true
			if is_host:
				enemies.damage_in_radius(spear.position, spear.radius, spear.damage, spear.owner_id,
					DamageSource.of_weapon(AutoWeapons.Id.BONE_SPEARS))
		if spear.age >= spear.warning + SPEAR_SHOW_SECONDS:
			_spears.remove_at(i)
	for i: int in range(_bolts.size() - 1, -1, -1):
		_bolts[i].age += delta
		if _bolts[i].age >= BOLT_SECONDS:
			_bolts.remove_at(i)


## Host: new stage. Altars and timers reset; owned weapons stay.
func reset_stage() -> void:
	_altars.clear()
	_next_altar_index = 0
	_timers.clear()
	_orbit_ready_at.clear()
	clear_effects()
	queue_redraw()


func clear_altars() -> void:
	_altars.clear()
	clear_effects()
	queue_redraw()


## Everyone: no scythes, flames, spears or lightning left (stage over).
func clear_effects() -> void:
	_scythes.clear()
	_flames.clear()
	_spears.clear()
	_bolts.clear()
	_last_flame_at.clear()
	if _overlay != null:
		_overlay.queue_redraw()


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


## For tests and the debug report: how many of each effect are alive.
func effect_counts() -> Dictionary[String, int]:
	return {"scythes": _scythes.size(), "flames": _flames.size(), "spears": _spears.size(), "bolts": _bolts.size()}


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


## Below the enemies: flames, spear warnings and altars.
func _draw() -> void:
	var view := PixelArt.visible_rect(self)
	var now := Time.get_ticks_msec()
	var flame_glow := PixelArt.disc_texture(8.0, Color(1.0, 0.45, 0.15, 0.22))
	for flame: Flame in _flames:
		if not view.has_point(flame.position):
			continue
		var fade := 1.0 - flame.age / flame.duration
		var glow_size := Vector2(flame_glow.get_size()) * (flame.radius / 8.0)
		draw_texture_rect(flame_glow, Rect2(flame.position - glow_size / 2.0, glow_size), false, Color(1, 1, 1, fade))
		var frame := "flame" if (now / 120 + int(flame.position.x)) % 2 == 0 else "flame_1"
		PixelArt.draw(self, frame, flame.position + Vector2(0, -2), Color.WHITE, false, false, 1.0,
			Color(1, 1, 1, 0.3 + 0.7 * fade))
	for spear: Spear in _spears:
		if spear.struck or not view.has_point(spear.position):
			continue
		# The warning: a ring of bone dust closing in on the spot.
		var t := spear.age / maxf(spear.warning, 0.01)
		draw_arc(spear.position, spear.radius * (1.6 - 0.6 * t), 0.0, TAU, 20, Color(SPEAR_COLOR, 0.3 + 0.5 * t), 1.0)
		draw_rect(Rect2(spear.position - Vector2(1, 1), Vector2(2, 2)), Color(SPEAR_COLOR, 0.7))
	for altar_id: int in _altars:
		var at: Vector2 = _altars[altar_id][0]
		var weapon := AutoWeapons.get_weapon(_altars[altar_id][1])
		var glow := 0.25 + 0.15 * sin(now / 200.0)
		draw_circle(at, 16.0, Color(weapon.color, glow * 0.4))
		draw_rect(Rect2(at + Vector2(-7, 2), Vector2(14, 6)), ALTAR_BASE_COLOR)
		draw_rect(Rect2(at + Vector2(-5, -2), Vector2(10, 4)), ALTAR_TOP_COLOR)
		PixelArt.draw(self, weapon.icon, at + Vector2(0, -9 + 1.5 * sin(now / 300.0)).round())


## Above the enemies: spinning scythes, lightning paths and erupting spears.
func _draw_overlay() -> void:
	for scythe: Scythe in _scythes:
		if not scythe.position.is_finite():
			continue
		_overlay.draw_set_transform(scythe.position.round(), snappedf(scythe.age * SCYTHE_SPIN, PI / 4.0))
		PixelArt.draw(_overlay, "scythe", Vector2.ZERO)
	_overlay.draw_set_transform(Vector2.ZERO)
	var bolt_color := AutoWeapons.get_weapon(AutoWeapons.Id.CHAIN_LIGHTNING).color
	for bolt: Bolt in _bolts:
		var fade := 1.0 - bolt.age / BOLT_SECONDS
		var path := jagged_path(bolt.points, bolt.seed_value)
		_overlay.draw_polyline(path, Color(bolt_color, 0.4 * fade), 3.0)
		_overlay.draw_polyline(path, Color(1, 1, 1, fade), 1.0)
	for spear: Spear in _spears:
		if not spear.struck:
			continue
		var shown := spear.age - spear.warning
		var rise := clampf(shown / 0.08, 0.0, 1.0)
		var fade := clampf((1.0 - shown / SPEAR_SHOW_SECONDS) * 1.5, 0.0, 1.0)
		PixelArt.draw(_overlay, "bone_spear", spear.position + Vector2(0, roundf(-6.0 * rise)), Color.WHITE, false, false,
			1.0, Color(1, 1, 1, fade))


## Whether anything was drawn last frame (one more redraw clears the last of it).
var _ground_busy: bool = false
var _overlay_busy: bool = false


func _process(_delta: float) -> void:
	var ground := not _altars.is_empty() or not _flames.is_empty() or not _spears.is_empty()
	if ground or _ground_busy:
		queue_redraw()
	_ground_busy = ground
	var overlay := not _scythes.is_empty() or not _bolts.is_empty() or not _spears.is_empty()
	if overlay or _overlay_busy:
		_overlay.queue_redraw()
	_overlay_busy = overlay


## A lightning path with a little zig-zag between its points (the same every frame).
static func jagged_path(points: PackedVector2Array, seed_value: int) -> PackedVector2Array:
	var result := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i: int in points.size():
		if i > 0:
			var from := points[i - 1]
			var to := points[i]
			var side := (to - from).orthogonal().normalized()
			for step: int in [1, 2]:
				result.append(from.lerp(to, step / 3.0) + side * rng.randf_range(-6.0, 6.0))
		result.append(points[i])
	return result


func _find_player(players: Array[Player], peer_id: int) -> Player:
	for player: Player in players:
		if player.peer_id == peer_id:
			return player
	return null


## Everyone: players with Hellfire Trail leave a flame every few steps.
func _drop_flames(players: Array[Player]) -> void:
	var weapon := AutoWeapons.get_weapon(AutoWeapons.Id.HELLFIRE_TRAIL)
	for player: Player in players:
		var level: int = player.weapon_levels.get(AutoWeapons.Id.HELLFIRE_TRAIL, 0)
		if level <= 0 or player.is_downed():
			continue
		var at := player.world_position()
		var last: Vector2 = _last_flame_at.get(player.peer_id, Vector2.INF)
		if last.is_finite() and last.distance_to(at) < TRAIL_SPACING:
			continue
		_last_flame_at[player.peer_id] = at
		var flame := Flame.new()
		flame.owner_id = player.peer_id
		flame.position = at
		flame.duration = weapon.duration
		flame.radius = weapon.radius_at(level)
		_flames.append(flame)


## Host: a scythe cuts each enemy it touches once on the way out and once back.
func _scythe_hits(scythe: Scythe, enemies: EnemyManager) -> void:
	for enemy: Enemy in enemies.enemies_in_radius(scythe.position, scythe.radius):
		var last: float = scythe.hit_at.get(enemy.pool_index, -INF)
		if scythe.age - last < scythe.duration / 2.0:
			continue
		scythe.hit_at[enemy.pool_index] = scythe.age
		if enemy.active:
			enemies.damage(enemy, scythe.damage, scythe.owner_id, DamageSource.of_weapon(AutoWeapons.Id.REAPERS_SCYTHE))


## Everyone: a throw of scythes from this player.
func _throw_scythes(owner_id: int, aim: float, level: int) -> void:
	var weapon := AutoWeapons.get_weapon(AutoWeapons.Id.REAPERS_SCYTHE)
	for angle: float in AutoWeapons.scythe_angles(weapon.count_at(level), aim):
		var scythe := Scythe.new()
		scythe.owner_id = owner_id
		scythe.angle = angle
		scythe.duration = weapon.duration
		scythe.reach = weapon.reach
		scythe.radius = weapon.radius_at(level)
		scythe.damage = weapon.damage_at(level)
		_scythes.append(scythe)


## Everyone: spears are coming up at these spots.
func _add_spears(owner_id: int, spots: PackedVector2Array, level: int) -> void:
	var weapon := AutoWeapons.get_weapon(AutoWeapons.Id.BONE_SPEARS)
	for at: Vector2 in spots:
		var spear := Spear.new()
		spear.owner_id = owner_id
		spear.position = at
		spear.warning = weapon.duration
		spear.radius = weapon.radius_at(level)
		spear.damage = weapon.damage_at(level)
		_spears.append(spear)


func _add_bolt(points: PackedVector2Array, seed_value: int) -> void:
	var bolt := Bolt.new()
	bolt.points = points
	bolt.seed_value = seed_value
	_bolts.append(bolt)
	_overlay.queue_redraw()


# --- Host: weapons -----------------------------------------------------------

func _tick_weapon(player: Player, weapon_id: int, level: int, delta: float, clock: float, enemies: EnemyManager) -> void:
	var weapon := AutoWeapons.get_weapon(weapon_id)
	var retry_key := "%d:%d" % [player.peer_id, weapon_id]
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
					_timers[retry_key] = 0.2
		AutoWeapon.Kind.AURA:
			if _cooldown_done(player, weapon_id, delta, weapon.interval_at(level)):
				enemies.damage_in_radius(player.state.position, weapon.radius_at(level), weapon.damage_at(level), player.peer_id,
					DamageSource.of_weapon(weapon_id))
		AutoWeapon.Kind.CHAIN:
			if _cooldown_done(player, weapon_id, delta, weapon.interval_at(level)):
				var path := _chain_strike(player, weapon, level, enemies)
				if path.size() < 2:
					_timers[retry_key] = 0.2
				else:
					var seed_value := _rng.randi() & 0xffff
					_add_bolt(path, seed_value)
					for peer_id: int in _ready_peers:
						_receive_bolt.rpc_id(peer_id, path, seed_value)
		AutoWeapon.Kind.BOOMERANG:
			if _cooldown_done(player, weapon_id, delta, weapon.interval_at(level)):
				if enemies.find_nearest(player.state.position, weapon.reach * 1.5) == null:
					_timers[retry_key] = 0.2
				else:
					_throw_scythes(player.peer_id, player.state.aim, level)
					for peer_id: int in _ready_peers:
						_receive_scythes.rpc_id(peer_id, player.peer_id, player.state.aim, level)
		AutoWeapon.Kind.TRAIL:
			if _cooldown_done(player, weapon_id, delta, weapon.interval_at(level)):
				_burn(player.peer_id, weapon.damage_at(level), enemies)
		AutoWeapon.Kind.ERUPTION:
			if _cooldown_done(player, weapon_id, delta, weapon.interval_at(level)):
				var spots := _spear_spots(player.state.position, weapon.reach, weapon.count_at(level), enemies)
				if spots.is_empty():
					_timers[retry_key] = 0.2
				else:
					_add_spears(player.peer_id, spots, level)
					for peer_id: int in _ready_peers:
						_receive_spears.rpc_id(peer_id, player.peer_id, spots, level)


## Host: lightning hits the nearest enemy, then jumps on to the closest ones it
## hasn't hit yet. Returns the path (player first) for drawing.
func _chain_strike(player: Player, weapon: AutoWeapon, level: int, enemies: EnemyManager) -> PackedVector2Array:
	var path := PackedVector2Array([player.state.position])
	var hit: Dictionary[int, bool] = {}
	var source := DamageSource.of_weapon(AutoWeapons.Id.CHAIN_LIGHTNING)
	var target := enemies.find_nearest_except(player.state.position, weapon.reach, hit)
	for jump: int in weapon.count_at(level) + 1:
		if target == null:
			break
		var at := target.position
		hit[target.pool_index] = true
		path.append(at)
		enemies.damage(target, weapon.damage_at(level), player.peer_id, source)
		target = enemies.find_nearest_except(at, weapon.radius_at(level), hit)
	return path


## Host: every enemy in one of this player's flames burns (once per tick, however
## many flames it stands in).
func _burn(owner_id: int, damage: int, enemies: EnemyManager) -> void:
	var burning: Dictionary[Enemy, bool] = {}
	for flame: Flame in _flames:
		if flame.owner_id != owner_id:
			continue
		for enemy: Enemy in enemies.enemies_in_radius(flame.position, flame.radius):
			burning[enemy] = true
	var source := DamageSource.of_weapon(AutoWeapons.Id.HELLFIRE_TRAIL)
	for enemy: Enemy in burning:
		if enemy.active:
			enemies.damage(enemy, damage, owner_id, source)


## Host: up to `count` different enemies near `center` to put spears under.
func _spear_spots(center: Vector2, reach: float, count: int, enemies: EnemyManager) -> PackedVector2Array:
	var candidates := enemies.enemies_in_radius(center, reach)
	var spots := PackedVector2Array()
	while not candidates.is_empty() and spots.size() < count:
		spots.append(candidates.pop_at(_rng.randi() % candidates.size()).position.round())
	return spots


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


## A random weapon this player can still level up (or -1 if every one is maxed).
## Unowned and low-level weapons are as likely as the rest.
func random_upgradable_weapon(player: Player) -> int:
	var choices: Array[int] = []
	for weapon_id: int in AutoWeapons.ALL.size():
		if player.weapon_levels.get(weapon_id, 0) < AutoWeapons.MAX_LEVEL:
			choices.append(weapon_id)
	return -1 if choices.is_empty() else choices[_rng.randi() % choices.size()]


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
func _receive_bolt(path: PackedVector2Array, seed_value: int) -> void:
	_add_bolt(path, seed_value)


@rpc("authority", "call_remote", "reliable")
func _receive_scythes(owner_id: int, aim: float, level: int) -> void:
	_throw_scythes(owner_id, aim, level)


@rpc("authority", "call_remote", "reliable")
func _receive_spears(owner_id: int, spots: PackedVector2Array, level: int) -> void:
	_add_spears(owner_id, spots, level)


@rpc("authority", "call_remote", "reliable")
func _receive_weapon_gained(peer_id: int, weapon_id: int) -> void:
	if AutoWeapons.is_valid_id(weapon_id):
		weapon_gained.emit(peer_id, weapon_id)
