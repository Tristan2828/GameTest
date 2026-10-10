class_name WeaponSystem
extends Node2D
## Runs every player's automatic weapons, the aimed main weapons that aren't
## bolts (Reaper's Scythe, Chain Lightning, Bone Spears; see `fire_main`) and
## the weapon altars.
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
## Everyone: a Bone Spear with Splinters struck; the arena spawns its shards.
signal shards_requested(owner_id: int, at: Vector2, angles: PackedFloat32Array, damage: int)
## Host: Grave Blast, Hex Snare or Bone Effigy goes off at `at` (the arena
## resolves it and shows it everywhere).
signal ability_cast(caster: Player, weapon_id: int, level: int, at: Vector2)

## Stage times (seconds) when an altar appears.
const ALTAR_TIMES: Array[float] = [80.0, 160.0]
## Altars that appear at each of those times, by team size (1-4 players), each
## near a different player: loot is first come, first served, so a bigger team
## needs more of it.
const ALTARS_BY_PLAYERS: Array[int] = [1, 2, 2, 3]
const ALTAR_DISTANCE_MIN: float = 140.0
const ALTAR_DISTANCE_MAX: float = 240.0
const ALTAR_PICKUP_RADIUS: float = 16.0
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
## Main-weapon scythes are drawn one size bigger per this much hit radius.
const MAIN_SCYTHE_RADIUS_PER_SCALE: float = 5.0
const SPEAR_COLOR: Color = Color(0.9, 0.86, 0.72)

var bounds: Rect2 = Rect2(0, 0, 1600, 1000)
## Auto weapon damage multiplier for this stage (the arena sets it on every peer
## from Arena.AUTO_DAMAGE_BY_DEPTH, so found weapons keep up with tougher enemies).
var stage_power: float = 1.0
## Set by the arena: peer id -> Player (or null), for main-weapon messages.
var find_player: Callable = func(_peer_id: int) -> Player: return null

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
	## How often it can cut the same enemy in one throw (2: out and back).
	var cuts: int = 2
	var source: int
	## Drawing size (main-weapon scythes are bigger, and grow with Heavy Blade).
	var scale: float = 1.0
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
	var source: int
	## Splinters: shards sprayed on the strike, and their seed.
	var shards: int = 0
	var shard_seed: int = 0
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
				enemies.damage_in_radius(spear.position, spear.radius, spear.damage, spear.owner_id, spear.source)
			if spear.shards > 0:
				shards_requested.emit(spear.owner_id, spear.position,
					MainWeapons.shard_angles(spear.shard_seed, spear.shards), MainWeapons.shard_damage(spear.damage))
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
		PixelArt.draw(_overlay, "scythe", Vector2.ZERO, Color.WHITE, false, false, scythe.scale)
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
		if scythe.age - last < scythe.duration / maxi(scythe.cuts, 1):
			continue
		scythe.hit_at[enemy.pool_index] = scythe.age
		if enemy.active:
			enemies.damage(enemy, scythe.damage, scythe.owner_id, scythe.source)


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
		scythe.source = DamageSource.of_weapon(AutoWeapons.Id.REAPERS_SCYTHE)
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
		spear.source = DamageSource.of_weapon(AutoWeapons.Id.BONE_SPEARS)
		_spears.append(spear)


func _add_bolt(points: PackedVector2Array, seed_value: int) -> void:
	var bolt := Bolt.new()
	bolt.points = points
	bolt.seed_value = seed_value
	_bolts.append(bolt)
	_overlay.queue_redraw()


# --- Main weapons ------------------------------------------------------------

## Runs on the host for every player's attack, and on a client for its own
## (predicted) attacks, like the Bolt Gun's shots. Only the host deals damage
## and tells the other peers.
func fire_main(shooter: Player, origin: Vector2, seed_value: int, enemies: EnemyManager, is_host: bool) -> void:
	var aim := shooter.state.aim
	match shooter.stats.main_weapon:
		CharacterStats.MainWeapon.SCYTHE:
			_throw_main_scythes(shooter, aim)
			if is_host:
				for peer_id: int in _others(shooter):
					_receive_main_scythes.rpc_id(peer_id, shooter.peer_id, aim)
		CharacterStats.MainWeapon.SPEARS:
			_raise_spear_row(shooter, origin, aim, seed_value)
			if is_host:
				for peer_id: int in _others(shooter):
					_receive_spear_row.rpc_id(peer_id, shooter.peer_id, origin, aim, seed_value)
		CharacterStats.MainWeapon.LIGHTNING:
			var seed_bits := seed_value & 0xffff
			for path: PackedVector2Array in _main_lightning(shooter, origin, aim, enemies, is_host):
				_add_bolt(path, seed_bits)
				if is_host:
					for peer_id: int in _others(shooter):
						_receive_bolt.rpc_id(peer_id, path, seed_bits)


## Host: every ready peer except the shooter (who already showed its own attack).
func _others(shooter: Player) -> Array[int]:
	var peers: Array[int] = []
	for peer_id: int in _ready_peers:
		if peer_id != shooter.peer_id:
			peers.append(peer_id)
	return peers


func _throw_main_scythes(thrower: Player, aim: float) -> void:
	var stats := thrower.stats
	for angle: float in MainWeapons.scythe_throw_angles(stats.projectile_count, aim):
		var scythe := Scythe.new()
		scythe.owner_id = thrower.peer_id
		scythe.angle = angle
		scythe.duration = stats.weapon_duration
		scythe.reach = stats.weapon_reach
		scythe.radius = stats.weapon_radius
		scythe.damage = stats.bullet_damage
		scythe.cuts = stats.scythe_cuts
		scythe.source = DamageSource.MAIN_GUN
		scythe.scale = maxf(roundf(stats.weapon_radius / MAIN_SCYTHE_RADIUS_PER_SCALE), 1.0)
		_scythes.append(scythe)


func _raise_spear_row(raiser: Player, origin: Vector2, aim: float, seed_value: int) -> void:
	var stats := raiser.stats
	var spots := MainWeapons.spear_row(origin, aim, stats.projectile_count)
	for i: int in spots.size():
		var spear := Spear.new()
		spear.owner_id = raiser.peer_id
		spear.position = spots[i]
		spear.warning = MainWeapons.spear_warning(i, stats.weapon_duration)
		spear.radius = stats.weapon_radius
		spear.damage = stats.bullet_damage
		spear.source = DamageSource.MAIN_GUN
		spear.shards = stats.spear_shards
		spear.shard_seed = seed_value + i
		_spears.append(spear)


## Chain Lightning: strikes the enemy closest to the aim, then jumps on to the
## nearest ones it hasn't hit (and splits with Split Bolt). On the main chain,
## jumps with nobody left to jump to strike the last enemy again, weaker
## (MainWeapons.GROUNDED_SHARE), so a lone boss isn't safe. Returns the paths
## to draw; a miss is a short zap into the air. Only the host deals the damage.
func _main_lightning(shooter: Player, origin: Vector2, aim: float, enemies: EnemyManager,
		is_host: bool) -> Array[PackedVector2Array]:
	var stats := shooter.stats
	var first := _lightning_target(shooter.state.position, aim, stats.weapon_reach, enemies)
	if first == null:
		return [PackedVector2Array([origin, origin + Vector2.from_angle(aim) * stats.weapon_reach * 0.6])]
	var hit: Dictionary[int, bool] = {first.pool_index: true}
	var first_at := first.position
	if is_host:
		enemies.damage(first, stats.bullet_damage, shooter.peer_id, DamageSource.MAIN_GUN)
	var paths: Array[PackedVector2Array] = []
	for chain: int in 1 + stats.chain_forks:
		var path := PackedVector2Array([origin, first_at]) if chain == 0 else PackedVector2Array([first_at])
		var at := first_at
		var last := first
		var grounded := false
		for jump: int in range(1, stats.projectile_count + 1):
			var target: Enemy = null if grounded else enemies.find_nearest_except(at, stats.weapon_radius, hit)
			if target == null:
				grounded = true
				if is_host and chain == 0 and last.active:
					enemies.damage(last, MainWeapons.grounded_damage(stats.bullet_damage), shooter.peer_id,
						DamageSource.MAIN_GUN)
				continue
			last = target
			hit[target.pool_index] = true
			at = target.position
			path.append(at)
			if is_host:
				enemies.damage(target, MainWeapons.chain_damage(stats.bullet_damage, stats.chain_damage_growth, jump),
					shooter.peer_id, DamageSource.MAIN_GUN)
		if path.size() >= 2:
			paths.append(path)
	return paths


func _lightning_target(from: Vector2, aim: float, reach: float, enemies: EnemyManager) -> Enemy:
	var best: Enemy = null
	var best_score := INF
	for enemy: Enemy in enemies.enemies_in_radius(from, reach):
		var score := MainWeapons.lightning_score(from, aim, enemy.position, reach + enemy.type.radius)
		if score >= 0.0 and score < best_score:
			best = enemy
			best_score = score
	return best


# --- Host: weapons -----------------------------------------------------------

func _tick_weapon(player: Player, weapon_id: int, level: int, delta: float, clock: float, enemies: EnemyManager) -> void:
	var weapon := AutoWeapons.get_weapon(weapon_id)
	var retry_key := "%d:%d" % [player.peer_id, weapon_id]
	# Relics and the Ember Shrine make every auto weapon faster and stronger.
	var interval := weapon.interval_at(level) * player.stats.auto_cooldown_scale
	var damage := power(player, weapon.damage_at(level))
	match weapon.kind:
		AutoWeapon.Kind.ORBIT:
			for skull: Vector2 in AutoWeapons.orbit_positions(player.state.position, level, clock):
				var enemy := enemies.find_hit(skull, weapon.radius_at(level))
				if enemy == null:
					continue
				var key := "%d:%d" % [player.peer_id, enemy.pool_index]
				if _orbit_ready_at.get(key, -1.0) > clock:
					continue
				_orbit_ready_at[key] = clock + interval
				enemies.damage(enemy, damage, player.peer_id, DamageSource.of_weapon(weapon_id))
		AutoWeapon.Kind.SEEKER:
			if _cooldown_done(player, weapon_id, delta, interval):
				var target := enemies.find_nearest(player.state.position, weapon.reach)
				if target != null:
					seeker_fired.emit(player, (target.position - player.state.position).angle(), level)
				else:
					# Nothing in range: try again soon instead of waiting a full interval.
					_timers[retry_key] = 0.2
		AutoWeapon.Kind.AURA:
			if _cooldown_done(player, weapon_id, delta, interval):
				enemies.damage_in_radius(player.state.position, weapon.radius_at(level), damage, player.peer_id,
					DamageSource.of_weapon(weapon_id))
		AutoWeapon.Kind.CHAIN:
			if _cooldown_done(player, weapon_id, delta, interval):
				var path := _chain_strike(player, weapon, level, enemies)
				if path.size() < 2:
					_timers[retry_key] = 0.2
				else:
					var seed_value := _rng.randi() & 0xffff
					_add_bolt(path, seed_value)
					for peer_id: int in _ready_peers:
						_receive_bolt.rpc_id(peer_id, path, seed_value)
		AutoWeapon.Kind.BOOMERANG:
			if _cooldown_done(player, weapon_id, delta, interval):
				if enemies.find_nearest(player.state.position, weapon.reach * 1.5) == null:
					_timers[retry_key] = 0.2
				else:
					_throw_scythes(player.peer_id, player.state.aim, level)
					for peer_id: int in _ready_peers:
						_receive_scythes.rpc_id(peer_id, player.peer_id, player.state.aim, level)
		AutoWeapon.Kind.TRAIL:
			if _cooldown_done(player, weapon_id, delta, interval):
				_burn(player.peer_id, damage, enemies)
		AutoWeapon.Kind.ERUPTION:
			if _cooldown_done(player, weapon_id, delta, interval):
				var spots := _spear_spots(player.state.position, weapon.reach, weapon.count_at(level), enemies)
				if spots.is_empty():
					_timers[retry_key] = 0.2
				else:
					_add_spears(player.peer_id, spots, level)
					for peer_id: int in _ready_peers:
						_receive_spears.rpc_id(peer_id, player.peer_id, spots, level)
		AutoWeapon.Kind.BLAST, AutoWeapon.Kind.HEX, AutoWeapon.Kind.EFFIGY:
			if _cooldown_done(player, weapon_id, delta, interval):
				var at := _ability_spot(player, weapon, level, enemies)
				if at.is_finite():
					ability_cast.emit(player, weapon_id, level, at)
				else:
					_timers[retry_key] = 0.2


## An auto weapon's damage for this player: relics and Arcane Focus (auto_power),
## Sharpened Edge and friends (damage_share), and the stage (stage_power).
func power(player: Player, amount: int) -> int:
	return roundi(amount * player.stats.auto_power * (1.0 + player.stats.damage_share) * stage_power)


## Host: where Grave Blast / Hex Snare / Bone Effigy should go off now, or
## Vector2.INF to wait (nothing worth it nearby).
func _ability_spot(player: Player, weapon: AutoWeapon, level: int, enemies: EnemyManager) -> Vector2:
	var at := player.state.position
	if weapon.kind == AutoWeapon.Kind.BLAST:
		var wake := weapon.radius_at(level) * AutoWeapons.BLAST_WAKE_FACTOR
		return at if enemies.find_nearest(at, wake) != null else Vector2.INF
	var positions := PackedVector2Array()
	for enemy: Enemy in enemies.enemies_in_radius(at, weapon.reach):
		if not enemy.type.is_boss or weapon.kind == AutoWeapon.Kind.HEX:
			positions.append(enemy.position)
	var crowd := AutoWeapons.crowd_center(at, positions, weapon.reach)
	if not crowd.is_finite():
		return Vector2.INF
	if weapon.kind == AutoWeapon.Kind.EFFIGY:
		crowd = at + (crowd - at).limit_length(AutoWeapons.EFFIGY_DISTANCE)
	var inner := bounds.grow(-8.0)
	return crowd.clamp(inner.position, inner.end)


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
	var altars := ALTARS_BY_PLAYERS[clampi(players.size(), 1, ALTARS_BY_PLAYERS.size()) - 1]
	for i: int in mini(altars, alive.size()):
		_spawn_altar(alive.pop_at(_rng.randi() % alive.size()).state.position, ready_peers)


## Host: an altar with a random weapon somewhere near `around`.
func _spawn_altar(around: Vector2, ready_peers: Array[int]) -> void:
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
	var weapon_id := AutoWeapons.PICKUPS[_rng.randi() % AutoWeapons.PICKUPS.size()]
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
	for weapon_id: int in AutoWeapons.PICKUPS:
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
func _receive_main_scythes(owner_id: int, aim: float) -> void:
	var thrower: Player = find_player.call(owner_id)
	if thrower != null:
		_throw_main_scythes(thrower, aim)


@rpc("authority", "call_remote", "reliable")
func _receive_spear_row(owner_id: int, origin: Vector2, aim: float, seed_value: int) -> void:
	var raiser: Player = find_player.call(owner_id)
	if raiser != null:
		_raise_spear_row(raiser, origin, aim, seed_value)


@rpc("authority", "call_remote", "reliable")
func _receive_spears(owner_id: int, spots: PackedVector2Array, level: int) -> void:
	_add_spears(owner_id, spots, level)


@rpc("authority", "call_remote", "reliable")
func _receive_weapon_gained(peer_id: int, weapon_id: int) -> void:
	if AutoWeapons.is_valid_id(weapon_id):
		weapon_gained.emit(peer_id, weapon_id)
