class_name HeroDemo
extends Control
## A small looping "video" of one hero for the lobby's Watch popup: the hero
## fights a few Shamblers with their main weapon, then uses their ability.
##
## It's a tiny scripted scene of its own, drawn at the game's real 1x scale with
## the hero's real numbers (fire rate, damage, reach, ability radius) and the
## same sprites as the arena. Purely local and visual: nothing here touches the
## network or the real game simulation. Steps at a fixed 60/s so `seek()` can
## jump to any moment (used for screenshots and tests).

enum Part { WEAPON, ABILITY }

const STEP: float = 1.0 / 60.0
const LOOP_SECONDS: float = 8.0
## The weapon part, then the ability part, then a short fade before it loops.
const ABILITY_START: float = 4.2
const ABILITY_USE: float = 4.7
const FADE_SECONDS: float = 0.4
const ENEMY_COUNT: int = 5
const ENEMY_RADIUS: float = 6.0
## Shamblers stop this close to the hero (the demo hero never gets hurt).
const ENEMY_STOP: float = 16.0
const HIT_FLASH: float = 0.08
const DEATH_SECONDS: float = 0.3
const BOLT_GLOW: Color = Color(1.0, 0.75, 0.3, 0.45)
const BOLT_CORE: Color = Color(1.0, 0.97, 0.8)
const ENEMY_BULLET_GLOW: Color = Color(1.0, 0.3, 0.8, 0.45)
const BLAST_COLOR: Color = Color(0.85, 0.75, 1.0)
const LIGHTNING_COLOR: Color = Color(0.55, 0.75, 1.0)
const SPEAR_COLOR: Color = Color(0.9, 0.86, 0.72)
const HEX_COLOR: Color = Color(0.72, 0.42, 1.0)
const FLOOR_COLOR: Color = Color(0.11, 0.1, 0.13)
const TILE_COLOR: Color = Color(0.14, 0.13, 0.17)
const DEMO_ENEMY_SPEED: float = 50.0
## Dash / Grave Blast: enemy bullets start this far away and reach the hero as the ability fires.
const DODGE_BULLET_DISTANCE: float = 70.0
## The effigy bursts sooner than in a real game so the loop stays short.
const EFFIGY_DEMO_SECONDS: float = 2.4

## Which hero (Characters.ALL index) is shown. Setting it restarts the loop.
var character_id: int = 0:
	set(value):
		character_id = value
		_stats = Characters.get_character(value)
		restart()
## The player's color (P pixels of the hero and effigy).
var color: Color = Color(0.36, 0.78, 0.95)

## Shamblers killed since the loop started (for tests).
var kills: int = 0

var _stats: CharacterStats = Characters.get_character(0)
var _time: float = 0.0
var _left_over: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _hero: Vector2 = Vector2.ZERO
var _aim: float = 0.0
var _cooldown: float = 0.0
var _walk: float = 0.0
var _moving: bool = false
var _used_ability: bool = false
var _dash_left: float = 0.0
var _dash_velocity: Vector2 = Vector2.ZERO
var _invulnerable_left: float = 0.0
var _enemy_hp: int = 30
var _enemy_speed: float = 38.0
var _next_enemy_id: int = 0

## Each is a Dictionary of a few fields, small and short-lived.
var _enemies: Array[Dictionary] = []
var _bolts: Array[Dictionary] = []
var _scythes: Array[Dictionary] = []
var _strikes: Array[Dictionary] = []
var _spears: Array[Dictionary] = []
var _enemy_bullets: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _trail: Array[Dictionary] = []
var _floaters: Array[Dictionary] = []
var _hex: Dictionary = {}
var _effigy: Dictionary = {}


func _ready() -> void:
	clip_contents = true
	var shambler := EnemyTypes.get_type(EnemyTypes.Id.SHAMBLER)
	_enemy_hp = shambler.max_hp
	# A little faster than a real Shambler, so the loop never runs out of targets.
	_enemy_speed = maxf(shambler.move_speed, DEMO_ENEMY_SPEED)
	restart()


## Which part of the loop is playing (the popup highlights its caption).
func part() -> Part:
	return Part.ABILITY if _time >= ABILITY_START else Part.WEAPON


## Back to the start of the loop.
func restart() -> void:
	_time = 0.0
	_left_over = 0.0
	kills = 0
	_rng.seed = 7 + character_id
	_hero = Vector2(70.0, _arena_size().y / 2.0)
	_aim = 0.0
	_cooldown = 0.3
	_used_ability = false
	_dash_left = 0.0
	_invulnerable_left = 0.0
	_enemies.clear()
	_bolts.clear()
	_scythes.clear()
	_strikes.clear()
	_spears.clear()
	_enemy_bullets.clear()
	_rings.clear()
	_trail.clear()
	_floaters.clear()
	_hex = {}
	_effigy = {}
	for i: int in ENEMY_COUNT:
		_spawn_enemy(true)
	queue_redraw()


## Jump to `seconds` into the loop (runs every step up to it; wraps around).
func seek(seconds: float) -> void:
	restart()
	var target := fmod(seconds, LOOP_SECONDS)
	while _time < target:
		_step()
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_left_over += minf(delta, 0.1)
	while _left_over >= STEP:
		_left_over -= STEP
		_step()
	queue_redraw()


func _arena_size() -> Vector2:
	return size if size.x > 0.0 else custom_minimum_size


# --- Simulation ------------------------------------------------------------------

func _step() -> void:
	_time += STEP
	if _time >= LOOP_SECONDS:
		restart()
		return
	_move_hero()
	_move_enemies()
	if _time < ABILITY_START or _stats.ability == CharacterStats.Ability.HEX_SNARE and _time > ABILITY_USE + 0.4:
		_attack()
	if not _used_ability and _time >= ABILITY_USE:
		_used_ability = true
		_use_ability()
	_tick_effects()


func _move_hero() -> void:
	var previous := _hero
	_invulnerable_left = maxf(_invulnerable_left - STEP, 0.0)
	if _dash_left > 0.0:
		_dash_left -= STEP
		_hero += _dash_velocity * STEP
		if int(_time / STEP) % 2 == 0:
			_trail.append({"at": _hero, "age": 0.0})
	else:
		# A slow sway up and down, so the hero looks alive while fighting.
		var target_y := _arena_size().y / 2.0 + sin(_time * 1.3) * 22.0
		_hero.y = move_toward(_hero.y, target_y, _stats.move_speed * 0.4 * STEP)
		# The Gravekeeper steps into the crowd before his blast.
		var home := 70.0
		if _stats.ability == CharacterStats.Ability.GRAVE_BLAST and _time >= ABILITY_START and _time < ABILITY_USE:
			home = 105.0
		_hero.x = move_toward(_hero.x, home, _stats.move_speed * 0.5 * STEP)
	_moving = _hero.distance_to(previous) > 0.05
	if _moving:
		_walk += STEP * Player.WALK_STEPS_PER_SECOND
	var target := _nearest_enemy(_hero)
	if not target.is_empty():
		_aim = (target["at"] - _hero).angle()


func _move_enemies() -> void:
	var alive := 0
	for enemy: Dictionary in _enemies:
		if enemy["dead"] >= 0.0:
			enemy["dead"] += STEP
			continue
		alive += 1
		enemy["flash"] = maxf(enemy["flash"] - STEP, 0.0)
		enemy["hexed"] = maxf(enemy["hexed"] - STEP, 0.0)
		if enemy["hexed"] > 0.0:
			continue
		var goal: Vector2 = _hero
		var stop := ENEMY_STOP
		if not _effigy.is_empty() and _effigy["at"].distance_to(enemy["at"]) <= _stats.effigy_lure_radius:
			goal = _effigy["at"]
			stop = 8.0
		var offset: Vector2 = goal - enemy["at"]
		if offset.length() > stop:
			enemy["at"] += offset.normalized() * _enemy_speed * STEP
		enemy["walk"] += STEP * 4.0
		enemy["flip"] = offset.x < 0.0
	_enemies = _enemies.filter(func(enemy: Dictionary) -> bool: return enemy["dead"] < DEATH_SECONDS)
	# Keep the fight going until the ability shows off.
	if _time < ABILITY_USE + 1.5:
		for i: int in ENEMY_COUNT - alive:
			_spawn_enemy(false)


func _spawn_enemy(anywhere: bool) -> void:
	var area := _arena_size()
	# The first ones stand ahead of the hero; later ones walk in over the top
	# and bottom edges near them, like a horde closing in.
	var at := Vector2(_rng.randf_range(115.0, area.x * 0.6), _rng.randf_range(16.0, area.y - 16.0))
	if not anywhere:
		at = Vector2(_rng.randf_range(110.0, area.x * 0.7), -8.0 if _rng.randf() < 0.5 else area.y + 8.0)
	_next_enemy_id += 1
	_enemies.append({"id": _next_enemy_id, "at": at, "hp": _enemy_hp, "flash": 0.0,
		"dead": -1.0, "walk": _rng.randf() * 2.0, "flip": true, "hexed": 0.0})


func _attack() -> void:
	_cooldown -= STEP
	if _cooldown > 0.0 or _dash_left > 0.0:
		return
	var target := _nearest_enemy(_hero)
	if target.is_empty():
		return
	_cooldown = _stats.fire_interval
	match _stats.main_weapon:
		CharacterStats.MainWeapon.SCYTHE:
			for angle: float in MainWeapons.scythe_angles(_stats.projectile_count, _aim):
				_scythes.append({"angle": angle, "age": 0.0, "out": {}, "back": {}})
		CharacterStats.MainWeapon.LIGHTNING:
			_strike_lightning()
		CharacterStats.MainWeapon.SPEARS:
			var spots := MainWeapons.spear_row(_hero, _aim, _stats.projectile_count)
			for i: int in spots.size():
				_spears.append({"at": spots[i], "age": 0.0, "warning": MainWeapons.spear_warning(i, _stats.weapon_duration),
					"struck": false})
		_:
			for angle: float in ShotPatterns.angles(_stats.shot_pattern, _aim, 0, _stats.projectile_count):
				var direction := Vector2.from_angle(angle)
				_bolts.append({"at": _hero + direction * 9.0, "velocity": direction * _stats.bullet_speed, "age": 0.0})


func _strike_lightning() -> void:
	var first: Dictionary = {}
	var best := INF
	for enemy: Dictionary in _enemies:
		if enemy["dead"] >= 0.0:
			continue
		var score := MainWeapons.lightning_score(_hero, _aim, enemy["at"], _stats.weapon_reach)
		if score >= 0.0 and score < best:
			best = score
			first = enemy
	var points := PackedVector2Array([_hero])
	if first.is_empty():
		points.append(_hero + Vector2.from_angle(_aim) * _stats.weapon_reach * 0.6)
		_strikes.append({"points": points, "age": 0.0, "seed": _rng.randi()})
		return
	var hit: Array[int] = []
	var current := first
	for jump: int in _stats.projectile_count + 1:
		hit.append(current["id"])
		points.append(current["at"])
		_damage(current, MainWeapons.chain_damage(_stats.bullet_damage, _stats.chain_damage_growth, jump))
		var next: Dictionary = {}
		var closest := _stats.weapon_radius
		for enemy: Dictionary in _enemies:
			if enemy["dead"] >= 0.0 or hit.has(enemy["id"]):
				continue
			var distance: float = enemy["at"].distance_to(current["at"])
			if distance <= closest:
				closest = distance
				next = enemy
		if next.is_empty():
			break
		current = next
	_strikes.append({"points": points, "age": 0.0, "seed": _rng.randi()})


func _use_ability() -> void:
	var power := _stats.ability_power
	match _stats.ability:
		CharacterStats.Ability.DASH:
			_dash_left = _stats.dash_duration * 2.2  # Longer than a real dash so it reads.
			# Sideways, out of the bullets' path.
			_dash_velocity = Vector2.from_angle(_aim - PI / 2.0) * _stats.dash_speed * 0.5
			_invulnerable_left = _dash_left
			_floaters.append({"text": "can't be hit!", "at": _hero + Vector2(0, -14), "age": 0.0})
		CharacterStats.Ability.GRAVE_BLAST:
			_rings.append({"at": _hero, "radius": _stats.blast_damage_radius, "age": 0.0, "color": BLAST_COLOR})
			for enemy: Dictionary in _enemies:
				if enemy["at"].distance_to(_hero) <= _stats.blast_damage_radius:
					_damage(enemy, roundi(_stats.blast_damage * power))
			_enemy_bullets = _enemy_bullets.filter(func(bullet: Dictionary) -> bool:
				return bullet["at"].distance_to(_hero) > _stats.blast_clear_radius)
			_floaters.append({"text": "+%d heart" % _stats.blast_heal, "at": _hero + Vector2(0, -14), "age": 0.0})
		CharacterStats.Ability.HEX_SNARE:
			var at := _hero + Vector2.from_angle(_aim) * _stats.hex_range
			_hex = {"at": at, "age": 0.0}
			for enemy: Dictionary in _enemies:
				if enemy["at"].distance_to(at) <= _stats.hex_radius:
					enemy["hexed"] = _stats.hex_duration
		CharacterStats.Ability.BONE_EFFIGY:
			_effigy = {"at": _hero + Vector2.from_angle(_aim) * _stats.effigy_range, "age": 0.0}


func _tick_effects() -> void:
	# Dash and Grave Blast: a fan of enemy bullets closing in, to dash through or wipe out.
	if _stats.ability == CharacterStats.Ability.DASH or _stats.ability == CharacterStats.Ability.GRAVE_BLAST:
		if _time >= ABILITY_START and _time < ABILITY_START + STEP * 1.5:
			var arrive := ABILITY_USE + 0.1 - _time
			for i: int in 5:
				var from := _hero + Vector2.from_angle(_aim + (i - 2) * 0.35) * DODGE_BULLET_DISTANCE
				_enemy_bullets.append({"at": from, "velocity": (_hero - from) / arrive})
	for bullet: Dictionary in _enemy_bullets:
		bullet["at"] += bullet["velocity"] * STEP
	_enemy_bullets = _enemy_bullets.filter(func(bullet: Dictionary) -> bool:
		return Rect2(Vector2(-10, -10), _arena_size() + Vector2(20, 20)).has_point(bullet["at"]))
	for bolt: Dictionary in _bolts:
		bolt["age"] += STEP
		bolt["at"] += bolt["velocity"] * STEP
		for enemy: Dictionary in _enemies:
			if enemy["dead"] < 0.0 and enemy["at"].distance_to(bolt["at"]) <= ENEMY_RADIUS:
				_damage(enemy, _stats.bullet_damage)
				bolt["age"] = INF
				break
	_bolts = _bolts.filter(func(bolt: Dictionary) -> bool: return bolt["age"] < _stats.bullet_lifetime)
	for scythe: Dictionary in _scythes:
		scythe["age"] += STEP
		var progress: float = scythe["age"] / _stats.weapon_duration
		var at := AutoWeapons.scythe_position(_hero, scythe["angle"], _stats.weapon_reach, progress)
		scythe["at"] = at
		var cuts: Dictionary = scythe["out"] if progress < 0.5 else scythe["back"]
		for enemy: Dictionary in _enemies:
			if enemy["dead"] < 0.0 and not cuts.has(enemy["id"]) \
					and enemy["at"].distance_to(at) <= _stats.weapon_radius + ENEMY_RADIUS:
				cuts[enemy["id"]] = true
				_damage(enemy, _stats.bullet_damage)
	_scythes = _scythes.filter(func(scythe: Dictionary) -> bool: return scythe["age"] < _stats.weapon_duration)
	for strike: Dictionary in _strikes:
		strike["age"] += STEP
	_strikes = _strikes.filter(func(strike: Dictionary) -> bool: return strike["age"] < WeaponSystem.BOLT_SECONDS)
	for spear: Dictionary in _spears:
		spear["age"] += STEP
		if not spear["struck"] and spear["age"] >= spear["warning"]:
			spear["struck"] = true
			for enemy: Dictionary in _enemies:
				if enemy["dead"] < 0.0 and enemy["at"].distance_to(spear["at"]) <= _stats.weapon_radius + ENEMY_RADIUS:
					_damage(enemy, _stats.bullet_damage)
	_spears = _spears.filter(func(spear: Dictionary) -> bool:
		return spear["age"] < spear["warning"] + WeaponSystem.SPEAR_SHOW_SECONDS)
	for list: Array in [_rings, _trail, _floaters]:
		for item: Dictionary in list:
			item["age"] += STEP
	_rings = _rings.filter(func(ring: Dictionary) -> bool: return ring["age"] < BombBlast.DURATION)
	_trail = _trail.filter(func(ghost: Dictionary) -> bool: return ghost["age"] < 0.25)
	_floaters = _floaters.filter(func(floater: Dictionary) -> bool: return floater["age"] < 1.2)
	if not _hex.is_empty():
		_hex["age"] += STEP
		if _hex["age"] >= _stats.hex_duration:
			_hex = {}
	if not _effigy.is_empty():
		_effigy["age"] += STEP
		if _effigy["age"] >= EFFIGY_DEMO_SECONDS:
			var at: Vector2 = _effigy["at"]
			_rings.append({"at": at, "radius": _stats.effigy_burst_radius, "age": 0.0, "color": color.lightened(0.3)})
			for enemy: Dictionary in _enemies:
				if enemy["at"].distance_to(at) <= _stats.effigy_burst_radius:
					_damage(enemy, roundi(_stats.effigy_burst_damage * _stats.ability_power))
			_effigy = {}


func _damage(enemy: Dictionary, amount: int) -> void:
	if enemy["dead"] >= 0.0:
		return
	if enemy["hexed"] > 0.0:
		amount = roundi(amount * _stats.hex_damage_multiplier)
	enemy["hp"] -= amount
	enemy["flash"] = HIT_FLASH
	if enemy["hp"] <= 0:
		enemy["dead"] = 0.0
		kills += 1


func _nearest_enemy(from: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var closest := INF
	for enemy: Dictionary in _enemies:
		if enemy["dead"] >= 0.0 or not Rect2(Vector2.ZERO, _arena_size()).grow(-4.0).has_point(enemy["at"]):
			continue
		var distance: float = enemy["at"].distance_to(from)
		if distance < closest:
			closest = distance
			best = enemy
	return best


# --- Drawing ---------------------------------------------------------------------

func _draw() -> void:
	var area := _arena_size()
	draw_rect(Rect2(Vector2.ZERO, area), FLOOR_COLOR)
	for x: int in range(0, int(area.x), 16):
		for y: int in range(0, int(area.y), 16):
			if (x / 16 + y / 16) % 2 == 0:
				draw_rect(Rect2(x + 1, y + 1, 14, 14), TILE_COLOR)
	_draw_ground()
	for enemy: Dictionary in _enemies:
		_draw_enemy(enemy)
	for ghost: Dictionary in _trail:
		PixelArt.draw(self, _stats.sprite, ghost["at"].round(), color, false, cos(_aim) < 0.0, 1.0,
			Color(1, 1, 1, 0.4 * (1.0 - ghost["age"] / 0.25)))
	var sprite := PixelArt.walk_frame(_stats.sprite, _moving, _walk)
	var blink := _invulnerable_left > 0.0 and int(_time * 20.0) % 2 == 0
	PixelArt.draw(self, sprite, _hero.round(), color, false, cos(_aim) < 0.0, 1.0, Color(1, 1, 1, 0.5 if blink else 1.0))
	_draw_overlay()
	var bullet := PixelArt.disc_texture(3.0, ENEMY_BULLET_GLOW, 1.5, Color.WHITE)
	for item: Dictionary in _enemy_bullets:
		draw_texture(bullet, (item["at"] - Vector2(bullet.get_size()) / 2.0).round())
	var font := get_theme_default_font()
	for floater: Dictionary in _floaters:
		var fade: float = 1.0 - floater["age"] / 1.2
		var at: Vector2 = floater["at"] + Vector2(0, -10.0 * floater["age"])
		var width := font.get_string_size(floater["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		draw_string(font, (at - Vector2(width / 2.0, 0)).round() + Vector2(1, 1), floater["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			Color(0, 0, 0, fade))
		draw_string(font, (at - Vector2(width / 2.0, 0)).round(), floater["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			Color(0.95, 0.85, 0.45, fade))
	# Fade to black at the end of the loop and back in at the start.
	var dark := maxf(1.0 - _time / FADE_SECONDS, (_time - (LOOP_SECONDS - FADE_SECONDS)) / FADE_SECONDS)
	if dark > 0.0:
		draw_rect(Rect2(Vector2.ZERO, area), Color(0, 0, 0, clampf(dark, 0.0, 1.0)))


## Under everyone: the hex sigil, the effigy's lure ring and spear warnings.
func _draw_ground() -> void:
	if not _hex.is_empty():
		var fade := clampf((_stats.hex_duration - _hex["age"]) / 0.4, 0.0, 1.0)
		var grow := minf(_hex["age"] / 0.15, 1.0)
		var radius := _stats.hex_radius * (1.0 - pow(1.0 - grow, 3.0))
		draw_circle(_hex["at"], radius, Color(HEX_COLOR, 0.13 * fade))
		draw_arc(_hex["at"], radius, 0.0, TAU, 48, Color(HEX_COLOR, 0.8 * fade), 1.0)
		draw_arc(_hex["at"], radius * 0.72, 0.0, TAU, 40, Color(HEX_COLOR, 0.35 * fade), 1.0)
	if not _effigy.is_empty():
		var pulse: float = 0.5 + 0.5 * sin(_effigy["age"] * 6.0)
		draw_arc(_effigy["at"], _stats.effigy_lure_radius, 0.0, TAU, 56, Color(color, 0.15 + 0.15 * pulse), 1.0)
		var shake := Vector2.ZERO
		if EFFIGY_DEMO_SECONDS - _effigy["age"] < 0.8:
			shake = Vector2(_rng.randf_range(-1.0, 1.0), 0.0).round()
		PixelArt.draw(self, "bone_effigy", _effigy["at"] + Vector2(0, -4) + shake, color)
	for spear: Dictionary in _spears:
		if spear["struck"]:
			continue
		var t: float = spear["age"] / maxf(spear["warning"], 0.01)
		draw_arc(spear["at"], _stats.weapon_radius * (1.6 - 0.6 * t), 0.0, TAU, 20, Color(SPEAR_COLOR, 0.3 + 0.5 * t), 1.0)


func _draw_enemy(enemy: Dictionary) -> void:
	var at: Vector2 = enemy["at"].round()
	var sprite := PixelArt.walk_frame("shambler", enemy["hexed"] <= 0.0, enemy["walk"])
	if enemy["dead"] >= 0.0:
		# Squash and fade, like EffectsLayer's death animation.
		var t: float = enemy["dead"] / DEATH_SECONDS
		var tex := PixelArt.texture("shambler")
		var tex_size := Vector2(tex.get_size()) * Vector2(1.0 + 0.4 * t, 1.0 - 0.6 * t)
		PixelArt.draw_rect_flipped(self, tex, Rect2((at + Vector2(-tex_size.x / 2.0, tex.get_size().y / 2.0 - tex_size.y)).round(),
			tex_size), enemy["flip"], Color(1, 1, 1, 1.0 - t))
		return
	var tint := Color(0.85, 0.6, 1.0) if enemy["hexed"] > 0.0 else Color.WHITE
	PixelArt.draw(self, sprite, at, Color.WHITE, enemy["flash"] > 0.0, enemy["flip"], 1.0, tint)


## Above everyone: bolts, scythes, lightning, erupting spears and blast rings.
func _draw_overlay() -> void:
	var bolt := PixelArt.disc_texture(3.0, BOLT_GLOW, 1.5, BOLT_CORE)
	for item: Dictionary in _bolts:
		draw_texture(bolt, (item["at"] - Vector2(bolt.get_size()) / 2.0).round())
	for scythe: Dictionary in _scythes:
		if not scythe.has("at"):
			continue
		draw_set_transform(scythe["at"].round(), snappedf(scythe["age"] * WeaponSystem.SCYTHE_SPIN, PI / 4.0))
		PixelArt.draw(self, "scythe", Vector2.ZERO)
	draw_set_transform(Vector2.ZERO)
	for strike: Dictionary in _strikes:
		var fade: float = 1.0 - strike["age"] / WeaponSystem.BOLT_SECONDS
		var path := WeaponSystem.jagged_path(strike["points"], strike["seed"])
		draw_polyline(path, Color(LIGHTNING_COLOR, 0.4 * fade), 3.0)
		draw_polyline(path, Color(1, 1, 1, fade), 1.0)
	for spear: Dictionary in _spears:
		if not spear["struck"]:
			continue
		var shown: float = spear["age"] - spear["warning"]
		var rise := clampf(shown / 0.08, 0.0, 1.0)
		var fade := clampf((1.0 - shown / WeaponSystem.SPEAR_SHOW_SECONDS) * 1.5, 0.0, 1.0)
		PixelArt.draw(self, "bone_spear", spear["at"] + Vector2(0, roundf(-6.0 * rise)), Color.WHITE, false, false, 1.0,
			Color(1, 1, 1, fade))
	for ring: Dictionary in _rings:
		var t: float = ring["age"] / BombBlast.DURATION
		var radius: float = ring["radius"] * (1.0 - pow(1.0 - t, 3.0))
		draw_circle(ring["at"], radius, Color(ring["color"], 0.15 * (1.0 - t)))
		draw_arc(ring["at"], radius, 0.0, TAU, 64, Color(ring["color"], 1.0 - t), 2.0)
