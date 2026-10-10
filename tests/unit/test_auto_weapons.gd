extends GutTest

const DELTA: float = 1.0 / 60.0
const PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")

var _enemies: EnemyManager
var _weapons: WeaponSystem
var _player: Player


func before_each() -> void:
	_enemies = EnemyManager.new()
	add_child_autofree(_enemies)
	_weapons = WeaponSystem.new()
	add_child_autofree(_weapons)
	_player = PLAYER_SCENE.instantiate()
	_player.setup(1, 0, Vector2(500, 500), Rect2(0, 0, 1600, 1000))
	add_child_autofree(_player)


func _players() -> Array[Player]:
	var players: Array[Player] = [_player]
	return players


func _run(seconds: float) -> void:
	var no_peers: Array[int] = []
	var clock := 0.0
	for i: int in roundi(seconds / DELTA):
		_enemies.rebuild_grid()
		_weapons.tick_host(DELTA, clock, _players(), _enemies, no_peers)
		clock += DELTA


# --- Data ---

func test_weapons_get_stronger_with_level() -> void:
	for weapon: AutoWeapon in AutoWeapons.ALL:
		if weapon.kind != AutoWeapon.Kind.HEX:  # Hex Snare binds instead of hurting.
			assert_gt(weapon.damage_at(3), weapon.damage_at(1), weapon.title)
		assert_true(weapon.interval_at(3) <= weapon.interval_at(1), weapon.title)


func test_orbit_positions_are_deterministic_and_spaced() -> void:
	var a := AutoWeapons.orbit_positions(Vector2(100, 100), 2, 1.5)
	var b := AutoWeapons.orbit_positions(Vector2(100, 100), 2, 1.5)
	assert_eq(a, b)
	assert_eq(a.size(), 3, "level 2 = 3 skulls")
	var reach := AutoWeapons.get_weapon(AutoWeapons.Id.ORBITING_SKULLS).reach
	assert_almost_eq(a[0].distance_to(Vector2(100, 100)), reach, 0.01)


func test_gaining_a_weapon_twice_levels_it_up_to_the_cap() -> void:
	for i: int in 5:
		_player.gain_weapon(AutoWeapons.Id.HOLY_AURA)
	assert_eq(_player.weapon_levels[AutoWeapons.Id.HOLY_AURA], AutoWeapons.MAX_LEVEL)


# --- Behaviour (host) ---

func test_aura_damages_nearby_enemies_only() -> void:
	_player.gain_weapon(AutoWeapons.Id.HOLY_AURA)
	var near := _enemies.spawn(EnemyTypes.Id.GHOUL, Vector2(520, 500))
	var far := _enemies.spawn(EnemyTypes.Id.GHOUL, Vector2(800, 500))
	_run(1.0)
	assert_lt(near.hp, near.max_hp)
	assert_eq(far.hp, far.max_hp)


func test_seeker_fires_at_enemies_in_range() -> void:
	_player.gain_weapon(AutoWeapons.Id.SEEKING_BOLTS)
	watch_signals(_weapons)
	_run(2.0)
	assert_signal_not_emitted(_weapons, "seeker_fired", "nothing to shoot at")
	_enemies.spawn(EnemyTypes.Id.GHOUL, Vector2(600, 500))
	_run(2.0)
	assert_signal_emitted(_weapons, "seeker_fired")
	var aim: float = get_signal_parameters(_weapons, "seeker_fired")[1]
	assert_almost_eq(aim, 0.0, 0.01, "aims straight at the enemy to the right")


func test_orbiting_skulls_bite_with_a_cooldown() -> void:
	_player.gain_weapon(AutoWeapons.Id.ORBITING_SKULLS)
	var ghoul := _enemies.spawn(EnemyTypes.Id.GHOUL, Vector2(530, 500))
	_run(0.5)
	var damage := AutoWeapons.get_weapon(AutoWeapons.Id.ORBITING_SKULLS).damage_at(1)
	var hits := (ghoul.max_hp - ghoul.hp) / damage
	assert_gt(hits, 0)
	assert_lt(hits, 4, "cooldown stops a hit every tick")


func test_ghosts_weapons_stay_quiet() -> void:
	_player.gain_weapon(AutoWeapons.Id.HOLY_AURA)
	_player.health.take_bullet(9999, 0.0)
	var near := _enemies.spawn(EnemyTypes.Id.GHOUL, Vector2(520, 500))
	_run(1.0)
	assert_eq(near.hp, near.max_hp)


# --- Altars ---

func test_altar_appears_on_schedule_and_is_grabbed_by_touch() -> void:
	var no_peers: Array[int] = []
	_weapons.tick_host(DELTA, WeaponSystem.ALTAR_TIMES[0] - 1.0, _players(), _enemies, no_peers)
	assert_eq(_weapons.altar_count(), 0)
	_weapons.tick_host(DELTA, WeaponSystem.ALTAR_TIMES[0], _players(), _enemies, no_peers)
	assert_eq(_weapons.altar_count(), 1)
	watch_signals(_weapons)
	_player.state.position = _weapons.nearest_altar(_player.state.position)
	_weapons.tick_host(DELTA, WeaponSystem.ALTAR_TIMES[0] + 1.0, _players(), _enemies, no_peers)
	assert_eq(_weapons.altar_count(), 0)
	assert_signal_emitted(_weapons, "weapon_gained")


func test_maxed_weapon_altar_gives_coins_instead() -> void:
	var no_peers: Array[int] = []
	_weapons._add_altar(7, Vector2(500, 500), AutoWeapons.Id.HOLY_AURA)
	for i: int in AutoWeapons.MAX_LEVEL:
		_player.gain_weapon(AutoWeapons.Id.HOLY_AURA)
	watch_signals(_weapons)
	_weapons.tick_host(DELTA, 0.0, _players(), _enemies, no_peers)
	assert_signal_not_emitted(_weapons, "weapon_gained")
	assert_eq(_player.coins, WeaponSystem.MAXED_WEAPON_COINS)


func test_bigger_teams_get_an_altar_near_more_players() -> void:
	var no_peers: Array[int] = []
	var team: Array[Player] = []
	for i: int in 4:
		var player: Player = PLAYER_SCENE.instantiate()
		player.setup(i + 1, i, Vector2(300 + 300 * i, 500), Rect2(0, 0, 1600, 1000))
		add_child_autofree(player)
		team.append(player)
	_weapons.tick_host(DELTA, WeaponSystem.ALTAR_TIMES[0], team, _enemies, no_peers)
	assert_eq(_weapons.altar_count(), WeaponSystem.ALTARS_BY_PLAYERS[3])
