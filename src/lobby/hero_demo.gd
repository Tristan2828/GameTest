class_name HeroDemo
extends Control
## A small looping "video" of one hero for the lobby's Watch popup: the hero's
## main weapon fires by itself at a few Shamblers (with the real AutoAim rules),
## then the hero steps out of the way of a fan of enemy bullets: you only move,
## your weapons do the rest.
##
## It's a tiny scripted scene of its own, drawn at the game's real 1x scale with
## the hero's real numbers (fire rate, damage, reach) and the same sprites as the
## arena. Purely local and visual: nothing here touches the network or the real
## game simulation. Steps at a fixed 60/s so `seek()` can jump to any moment
## (used for screenshots and tests).

enum Part { WEAPON, DODGE }

const STEP: float = 1.0 / 60.0
const LOOP_SECONDS: float = 8.0
## The weapon part, then the dodge part, then a short fade before it loops.
const DODGE_START: float = 4.2
## When the hero starts stepping aside (the bullets arrive DODGE_ARRIVE later).
const DODGE_AT: float = 4.5
const DODGE_ARRIVE: float = 0.55
const DODGE_SECONDS: float = 0.5
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
const LIGHTNING_COLOR: Color = Color(0.55, 0.75, 1.0)
const SPEAR_COLOR: Color = Color(0.9, 0.86, 0.72)
const FLOOR_COLOR: Color = Color(0.11, 0.1, 0.13)
const TILE_COLOR: Color = Color(0.14, 0.13, 0.17)
const DEMO_ENEMY_SPEED: float = 50.0
## The bullet fan starts this far from the hero.
const DODGE_BULLET_DISTANCE: float = 80.0

## Which hero (Characters.ALL index) is shown. Setting it restarts the loop.
var character_id: int = 0:
	set(value):
		character_id = value
		_stats = Characters.get_character(value)
		restart()
## The player's color (P pixels of the hero).
var color: Color = Color(0.36, 0.78, 0.95)

## Shamblers killed since the loop started (for tests).
var kills: int = 0

var _stats: CharacterStats = Characters.get_character(0)
var _time: float = 0.0
var _left_over: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _hero: Vector2 = Vector2.ZERO
## The way the hero faces (their last movement; the scythe flies this way).
var _facing: float = 0.0
var _aim: float = 0.0
var _cooldown: float = 0.0
var _walk: float = 0.0
var _moving: bool = false
var _dodge_direction: float = 1.0
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
var _floaters: Array[Dictionary] = []


func _ready() -> void:
	clip_contents = true
	var shambler := EnemyTypes.get_type(EnemyTypes.Id.SHAMBLER)
	_enemy_hp = shambler.max_hp
	# A little faster than a real Shambler, so the loop never runs out of targets.
	_enemy_speed = maxf(shambler.move_speed, DEMO_ENEMY_SPEED)
	restart()


## Which part of the loop is playing (the popup highlights its caption).
func part() -> Part:
	return Part.DODGE if _time >= DODGE_START else Part.WEAPON


## Back to the start of the loop.
func restart() -> void:
	_time = 0.0
	_left_over = 0.0
	kills = 0
	_rng.seed = 7 + character_id
	_hero = Vector2(70.0, _arena_size().y / 2.0)
	_facing = 0.0
	_aim = 0.0
	_cooldown = 0.3
	_enemies.clear()
	_bolts.clear()
	_scythes.clear()
	_strikes.clear()
	_spears.clear()
	_enemy_bullets.clear()
	_floaters.clear()
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
	_attack()
	_tick_effects()


func _move_hero() -> void:
	var previous := _hero
	var area := _arena_size()
	if _time >= DODGE_AT and _time < DODGE_AT + DODGE_SECONDS:
		# Step aside, out of the bullets' path.
		_hero.y = clampf(_hero.y + _dodge_direction * _stats.move_speed * STEP, 14.0, area.y - 14.0)
	elif _time < DODGE_START:
		# A slow sway up and down, so the hero looks alive while fighting.
		var target_y := area.y / 2.0 + sin(_time * 1.3) * 22.0
		_hero.y = move_toward(_hero.y, target_y, _stats.move_speed * 0.4 * STEP)
	_hero.x = move_toward(_hero.x, 70.0, _stats.move_speed * 0.5 * STEP)
	_moving = _hero.distance_to(previous) > 0.05
	if _moving:
		_walk += STEP * Player.WALK_STEPS_PER_SECOND
		# Facing follows sideways movement only roughly: the enemies are to the right.
		var moved := _hero - previous
		if absf(moved.x) > 0.01:
			_facing = 0.0 if moved.x > 0.0 else PI


func _move_enemies() -> void:
	var alive := 0
	for enemy: Dictionary in _enemies:
		if enemy["dead"] >= 0.0:
			enemy["dead"] += STEP
			continue
		alive += 1
		enemy["flash"] = maxf(enemy["flash"] - STEP, 0.0)
		var offset: Vector2 = _hero - enemy["at"]
		if offset.length() > ENEMY_STOP:
			enemy["at"] += offset.normalized() * _enemy_speed * STEP
		enemy["walk"] += STEP * 4.0
		enemy["flip"] = offset.x < 0.0
	_enemies = _enemies.filter(func(enemy: Dictionary) -> bool: return enemy["dead"] < DEATH_SECONDS)
	# Keep the fight going until near the end of the loop.
	if _time < LOOP_SECONDS - 2.0:
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
		"dead": -1.0, "walk": _rng.randf() * 2.0, "flip": true})


## The weapon fires by itself, exactly like in a run (AutoAim picks the target).
func _attack() -> void:
	_cooldown -= STEP
	if _cooldown > 0.0:
		return
	var visible := Rect2(Vector2.ZERO, _arena_size()).grow(-4.0)
	var targets := PackedVector2Array()
	for enemy: Dictionary in _enemies:
		if enemy["dead"] < 0.0 and visible.has_point(enemy["at"]):
			targets.append(enemy["at"])
	var aim := AutoAim.pick(_stats, _hero, _facing, targets, _rng.randf())
	if is_nan(aim):
		return
	_aim = aim
	_cooldown = _stats.fire_interval
	match _stats.main_weapon:
		CharacterStats.MainWeapon.SCYTHE:
			for angle: float in MainWeapons.scythe_throw_angles(_stats.projectile_count, _aim):
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
	if first.is_empty():
		return
	var points := PackedVector2Array([_hero])
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


func _tick_effects() -> void:
	# The dodge part: a fan of enemy bullets aimed where the hero stands.
	if _time >= DODGE_START and _time < DODGE_START + STEP * 1.5:
		_dodge_direction = -1.0 if _hero.y > _arena_size().y / 2.0 else 1.0
		var arrive := DODGE_AT + DODGE_ARRIVE - _time
		for i: int in 5:
			var from := _hero + Vector2.from_angle((i - 2) * 0.3) * DODGE_BULLET_DISTANCE
			_enemy_bullets.append({"at": from, "velocity": (_hero - from) / arrive})
		_floaters.append({"text": "dodge!", "at": _hero + Vector2(0, -14), "age": 0.0})
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
	for floater: Dictionary in _floaters:
		floater["age"] += STEP
	_floaters = _floaters.filter(func(floater: Dictionary) -> bool: return floater["age"] < 1.2)


func _damage(enemy: Dictionary, amount: int) -> void:
	if enemy["dead"] >= 0.0:
		return
	enemy["hp"] -= amount
	enemy["flash"] = HIT_FLASH
	if enemy["hp"] <= 0:
		enemy["dead"] = 0.0
		kills += 1


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
	var sprite := PixelArt.walk_frame(_stats.sprite, _moving, _walk)
	PixelArt.draw(self, sprite, _hero.round(), color, false, cos(_facing) < 0.0)
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


## Under everyone: spear warnings.
func _draw_ground() -> void:
	for spear: Dictionary in _spears:
		if spear["struck"]:
			continue
		var t: float = spear["age"] / maxf(spear["warning"], 0.01)
		draw_arc(spear["at"], _stats.weapon_radius * (1.6 - 0.6 * t), 0.0, TAU, 20, Color(SPEAR_COLOR, 0.3 + 0.5 * t), 1.0)


func _draw_enemy(enemy: Dictionary) -> void:
	var at: Vector2 = enemy["at"].round()
	var sprite := PixelArt.walk_frame("shambler", true, enemy["walk"])
	if enemy["dead"] >= 0.0:
		# Squash and fade, like EffectsLayer's death animation.
		var t: float = enemy["dead"] / DEATH_SECONDS
		var tex := PixelArt.texture("shambler")
		var tex_size := Vector2(tex.get_size()) * Vector2(1.0 + 0.4 * t, 1.0 - 0.6 * t)
		PixelArt.draw_rect_flipped(self, tex, Rect2((at + Vector2(-tex_size.x / 2.0, tex.get_size().y / 2.0 - tex_size.y)).round(),
			tex_size), enemy["flip"], Color(1, 1, 1, 1.0 - t))
		return
	PixelArt.draw(self, sprite, at, Color.WHITE, enemy["flash"] > 0.0, enemy["flip"])


## Above everyone: bolts, scythes, lightning and erupting spears.
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
