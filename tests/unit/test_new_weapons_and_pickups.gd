extends GutTest
## The v0.16 auto weapons (Chain Lightning, Reaper's Scythe, Hellfire Trail,
## Bone Spears) and power-up pickups (Heart, Soul Magnet, Holy Bomb, Frost Hourglass).

const DELTA: float = 1.0 / 60.0
const PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")

var _enemies: EnemyManager
var _weapons: WeaponSystem
var _player: Player
var _clock: float = 0.0


func before_each() -> void:
	_enemies = EnemyManager.new()
	add_child_autofree(_enemies)
	_weapons = WeaponSystem.new()
	add_child_autofree(_weapons)
	_player = PLAYER_SCENE.instantiate()
	_player.setup(1, 0, Vector2(500, 500), Rect2(0, 0, 1600, 1000))
	add_child_autofree(_player)
	_clock = 0.0


func _players() -> Array[Player]:
	var players: Array[Player] = [_player]
	return players


func _run(seconds: float) -> void:
	var no_peers: Array[int] = []
	for i: int in roundi(seconds / DELTA):
		_enemies.rebuild_grid()
		_weapons.tick_host(DELTA, _clock, _players(), _enemies, no_peers)
		_weapons.tick_effects(DELTA, _players(), _enemies, true)
		_clock += DELTA


func _ghoul(at: Vector2) -> Enemy:
	return _enemies.spawn(EnemyTypes.Id.GHOUL, at, 10000)


# --- Weapons ---

func test_new_weapons_are_registered_with_icons() -> void:
	assert_eq(AutoWeapons.ALL.size(), 7)
	for weapon: AutoWeapon in AutoWeapons.ALL:
		assert_true(PixelArt.has_sprite(weapon.icon), weapon.title)
		assert_gt(weapon.damage_at(3), weapon.damage_at(1), weapon.title)


func test_chain_lightning_jumps_between_enemies() -> void:
	var near := _ghoul(Vector2(560, 500))
	var next := _ghoul(Vector2(620, 500))
	var far := _ghoul(Vector2(1200, 900))
	_player.gain_weapon(AutoWeapons.Id.CHAIN_LIGHTNING)
	_run(AutoWeapons.get_weapon(AutoWeapons.Id.CHAIN_LIGHTNING).interval + 0.05)
	assert_lt(near.hp, near.max_hp, "first hit")
	assert_lt(next.hp, next.max_hp, "jumped on")
	assert_eq(far.hp, far.max_hp, "too far to jump to")
	assert_eq(_weapons.effect_counts()["bolts"], 1, "a bolt to draw")


func test_scythe_flies_out_and_comes_back() -> void:
	var start := Vector2(500, 500)
	assert_eq(AutoWeapons.scythe_position(start, 0.0, 100.0, 0.0), start)
	assert_almost_eq(AutoWeapons.scythe_position(start, 0.0, 100.0, 0.5).x, 600.0, 0.01, "furthest halfway")
	assert_almost_eq(AutoWeapons.scythe_position(start, 0.0, 100.0, 1.0).x, 500.0, 0.01, "back at the thrower")
	assert_eq(AutoWeapons.scythe_angles(2, 0.0).size(), 2)


func test_scythe_cuts_an_enemy_on_the_way_out_and_back() -> void:
	var weapon := AutoWeapons.get_weapon(AutoWeapons.Id.REAPERS_SCYTHE)
	var target := _ghoul(Vector2(560, 500))
	_player.state.aim = 0.0
	_player.gain_weapon(AutoWeapons.Id.REAPERS_SCYTHE)
	_run(weapon.interval + weapon.duration - 0.05)
	assert_eq(target.max_hp - target.hp, weapon.damage_at(1) * 2, "two cuts: out and back")


func test_hellfire_leaves_flames_that_burn() -> void:
	var weapon := AutoWeapons.get_weapon(AutoWeapons.Id.HELLFIRE_TRAIL)
	_player.gain_weapon(AutoWeapons.Id.HELLFIRE_TRAIL)
	for step: int in 6:
		_player.state.position = Vector2(500 + step * 12, 500)
		_run(DELTA)
	assert_gt(_weapons.effect_counts()["flames"], 4, "a flame every few steps")
	_player.state.position = Vector2(400, 400)
	var burning := _ghoul(Vector2(530, 500))
	_run(weapon.interval + 0.05)
	assert_eq(burning.max_hp - burning.hp, weapon.damage_at(1), "one burn per tick, even inside several flames")
	_run(weapon.duration + 0.1)
	assert_eq(_weapons.effect_counts()["flames"], 0, "flames burn out")


func test_bone_spears_strike_after_a_warning() -> void:
	var weapon := AutoWeapons.get_weapon(AutoWeapons.Id.BONE_SPEARS)
	var target := _ghoul(Vector2(600, 500))
	_player.gain_weapon(AutoWeapons.Id.BONE_SPEARS)
	_run(weapon.interval + 0.05)
	assert_eq(_weapons.effect_counts()["spears"], 1, "a warning under the only enemy")
	assert_eq(target.hp, target.max_hp, "not yet")
	_run(weapon.duration)
	assert_eq(target.max_hp - target.hp, weapon.damage_at(1), "then the spear")


func test_lightning_path_is_the_same_every_frame() -> void:
	var points := PackedVector2Array([Vector2.ZERO, Vector2(60, 0), Vector2(60, 60)])
	assert_eq(WeaponSystem.jagged_path(points, 7), WeaponSystem.jagged_path(points, 7))
	assert_eq(WeaponSystem.jagged_path(points, 7).size(), 7)


# --- Power-ups ---

func test_every_kind_can_drop() -> void:
	var seen: Dictionary[int, bool] = {}
	for i: int in 100:
		seen[PowerUps.pick_kind(i / 100.0)] = true
	assert_eq(seen.size(), PowerUps.TITLES.size())
	for sprite: String in PowerUps.SPRITES:
		assert_true(PixelArt.has_sprite(sprite), sprite)


func test_frost_stops_regular_enemies_but_not_bosses() -> void:
	var shambler := _enemies.spawn(EnemyTypes.Id.SHAMBLER, Vector2(300, 300))
	var boss := _enemies.spawn(EnemyTypes.Id.BONE_WARDEN, Vector2(800, 300))
	_enemies.freeze_all(1.0)
	var targets: Array[Vector2] = [Vector2(500, 300)]
	for i: int in 30:
		_enemies.tick_host(DELTA, targets)
	assert_eq(shambler.position, Vector2(300, 300), "frozen in place")
	assert_true(shambler.frozen)
	assert_ne(boss.position, Vector2(800, 300), "bosses keep moving")
	for i: int in 40:
		_enemies.tick_host(DELTA, targets)
	assert_false(shambler.frozen, "thaws out")
	assert_ne(shambler.position, Vector2(300, 300))


func test_frost_holds_bullets_in_the_air() -> void:
	var bullets := ProjectileManager.new()
	add_child_autofree(bullets)
	bullets.spawn(Vector2(100, 100), Vector2(100, 0), 1, 5.0, 0)
	bullets.step(0.5)
	bullets.freeze_all(1.0)
	bullets.spawn(Vector2(100, 200), Vector2(100, 0), 1, 5.0, 0)
	bullets.step(0.5)
	assert_almost_eq(bullets.position_of(0).x, 150.0, 0.01, "frozen bullet stays")
	assert_almost_eq(bullets.position_of(1).x, 150.0, 0.01, "bullets fired after the freeze still fly")
	bullets.step(0.6)
	bullets.step(0.5)
	assert_gt(bullets.position_of(0).x, 150.0, "moves again")


func test_holy_bomb_spares_bosses() -> void:
	var shambler := _enemies.spawn(EnemyTypes.Id.SHAMBLER, Vector2(300, 300))
	var far := _enemies.spawn(EnemyTypes.Id.SHAMBLER, Vector2(900, 900))
	var boss := _enemies.spawn(EnemyTypes.Id.BONE_WARDEN, Vector2(330, 300))
	_enemies.smite(Vector2(300, 300), PowerUps.BOMB_RADIUS, PowerUps.BOMB_DAMAGE, 1, DamageSource.HOLY_BOMB)
	assert_false(shambler.active, "smitten")
	assert_true(far.active, "out of reach")
	assert_eq(boss.hp, boss.max_hp)
	assert_eq(int(_enemies.damage_by_source[1][DamageSource.HOLY_BOMB]), EnemyTypes.get_type(EnemyTypes.Id.SHAMBLER).max_hp)
	assert_eq(DamageSource.title(DamageSource.HOLY_BOMB, _player.stats), "Holy Bomb")


func test_soul_magnet_pulls_every_gem() -> void:
	var gems := GemManager.new()
	add_child_autofree(gems)
	gems.spawn_host(Vector2(1500, 900), 3)
	gems.spawn_host(Vector2(20, 20), 3)
	gems.attract_all(1)
	var positions: Dictionary[int, Vector2] = {1: Vector2(500, 500)}
	var radii: Dictionary[int, float] = {1: 10.0}
	watch_signals(gems)
	for i: int in 300:
		gems.tick(DELTA, positions, radii, true)
	assert_eq(gems.count(), 0, "both flew all the way to the player")
	assert_signal_emit_count(gems, "collected", 2)
