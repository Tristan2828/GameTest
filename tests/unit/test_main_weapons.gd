extends GutTest
## Heroes' own main weapons (v0.19.0): Reaper's Scythe (Gravekeeper), Chain
## Lightning (Hexblade Witch) and Bone Spears (Necromancer), their weapon-only
## upgrades and relics, and the smaller auto-weapon pickup pool.

const DELTA: float = 1.0 / 60.0
const PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")

var _enemies: EnemyManager
var _weapons: WeaponSystem
var _shards: int = 0


func before_each() -> void:
	_enemies = EnemyManager.new()
	add_child_autofree(_enemies)
	_weapons = WeaponSystem.new()
	add_child_autofree(_weapons)
	_shards = 0
	_weapons.shards_requested.connect(func(_owner: int, _at: Vector2, angles: PackedFloat32Array, _damage: int) -> void:
		_shards += angles.size())


func _hero_player(character: int) -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	player.setup(1, 0, Vector2(500, 500), Rect2(0, 0, 1600, 1000), character)
	add_child_autofree(player)
	player.state.aim = 0.0
	return player


func _ghoul(at: Vector2) -> Enemy:
	return _enemies.spawn(EnemyTypes.Id.GHOUL, at, 10000)


func _fire(player: Player) -> void:
	_enemies.rebuild_grid()
	_weapons.fire_main(player, player.muzzle_position(), 1234, _enemies, true)


func _run(player: Player, seconds: float) -> void:
	var players: Array[Player] = [player]
	for i: int in roundi(seconds / DELTA):
		_enemies.rebuild_grid()
		_weapons.tick_effects(DELTA, players, _enemies, true)


func _upgrade_id(title: String) -> int:
	for id: int in Upgrades.ALL.size():
		if Upgrades.ALL[id].title == title:
			return id
	fail_test("no upgrade called %s" % title)
	return -1


# --- Pure math ---

func test_scythes_fan_out_around_the_aim() -> void:
	assert_eq(MainWeapons.scythe_angles(1, 0.5), PackedFloat32Array([0.5]))
	var three := MainWeapons.scythe_angles(3, 0.0)
	assert_almost_eq(three[1], 0.0, 0.0001, "middle one straight ahead")
	assert_almost_eq(three[2] - three[0], deg_to_rad(MainWeapons.SCYTHE_SPREAD_DEGREES * 2.0), 0.0001)


func test_main_scythe_also_throws_behind_you() -> void:
	var angles := MainWeapons.scythe_throw_angles(2, 0.0)
	assert_eq(angles.size(), 4)
	assert_almost_eq(angles[2] - angles[0], PI, 0.0001)


func test_spear_row_runs_outward_along_the_aim() -> void:
	var row := MainWeapons.spear_row(Vector2(100, 100), 0.0, 4)
	assert_eq(row.size(), 4)
	assert_eq(row[0], Vector2(100 + MainWeapons.SPEAR_START, 100))
	assert_eq(row[3].x - row[2].x, MainWeapons.SPEAR_SPACING)
	assert_gt(MainWeapons.spear_warning(3, 0.3), MainWeapons.spear_warning(0, 0.3), "far spears rise later")


func test_shards_are_the_same_on_every_peer() -> void:
	assert_eq(MainWeapons.shard_angles(42, 3), MainWeapons.shard_angles(42, 3))
	assert_ne(MainWeapons.shard_angles(42, 3), MainWeapons.shard_angles(43, 3))


func test_lightning_prefers_the_enemy_it_picked() -> void:
	var from := Vector2.ZERO
	assert_lt(MainWeapons.lightning_score(from, 0.0, Vector2(100, 0), 150.0), 0.0 + 101.0)
	assert_eq(MainWeapons.lightning_score(from, 0.0, Vector2(200, 0), 150.0), -1.0, "out of reach")
	assert_eq(MainWeapons.lightning_score(from, 0.0, Vector2(-60, 0), 150.0), -1.0, "behind you")
	assert_gte(MainWeapons.lightning_score(from, 0.0, Vector2(-10, 0), 150.0), 0.0, "point blank: any side")
	var ahead := MainWeapons.lightning_score(from, 0.0, Vector2(80, 0), 150.0)
	var aside := MainWeapons.lightning_score(from, 0.0, Vector2(60, 30), 150.0)
	assert_lt(ahead, aside, "straight ahead beats slightly closer but off to the side")


func test_chain_damage_grows_with_conductor() -> void:
	assert_eq(MainWeapons.chain_damage(10, 0.0, 3), 10)
	assert_eq(MainWeapons.chain_damage(10, 0.2, 1), 12)


# --- Weapons in play ---

func test_scythe_cuts_on_the_way_out_and_back() -> void:
	var keeper := _hero_player(Characters.Id.GRAVEKEEPER)
	var target := _ghoul(Vector2(560, 500))
	_fire(keeper)
	assert_eq(_weapons.effect_counts()["scythes"], 2, "one ahead, one behind")
	_run(keeper, keeper.stats.weapon_duration + 0.05)
	assert_eq(target.max_hp - target.hp, keeper.stats.bullet_damage * 2, "two cuts")
	assert_eq(_weapons.effect_counts()["scythes"], 0, "caught again")


func test_twin_scythes_throws_two() -> void:
	var keeper := _hero_player(Characters.Id.GRAVEKEEPER)
	keeper.apply_upgrade(_upgrade_id("Twin Scythes"))
	_fire(keeper)
	assert_eq(_weapons.effect_counts()["scythes"], 4, "two ahead, two behind")


func test_lightning_strikes_the_aimed_enemy_and_jumps() -> void:
	var witch := _hero_player(Characters.Id.HEXBLADE_WITCH)
	var aimed := _ghoul(Vector2(600, 500))
	var behind := _ghoul(Vector2(440, 500))
	var next := _ghoul(Vector2(640, 520))
	_fire(witch)
	assert_lt(aimed.hp, aimed.max_hp, "struck")
	assert_lt(next.hp, next.max_hp, "jumped on")
	assert_eq(behind.hp, behind.max_hp, "not the one behind you")
	assert_eq(_weapons.effect_counts()["bolts"], 1)


func test_lightning_with_nothing_ahead_zaps_the_air() -> void:
	var witch := _hero_player(Characters.Id.HEXBLADE_WITCH)
	_fire(witch)
	assert_eq(_weapons.effect_counts()["bolts"], 1, "a miss still shows")


func test_split_bolt_adds_a_second_chain() -> void:
	var witch := _hero_player(Characters.Id.HEXBLADE_WITCH)
	witch.apply_upgrade(_upgrade_id("Split Bolt"))
	_ghoul(Vector2(600, 500))
	var left := _ghoul(Vector2(600, 450))
	var right := _ghoul(Vector2(600, 550))
	_fire(witch)
	assert_eq(_weapons.effect_counts()["bolts"], 2)
	assert_lt(left.hp, left.max_hp)
	assert_lt(right.hp, right.max_hp)


func test_lightning_on_a_client_only_shows() -> void:
	var witch := _hero_player(Characters.Id.HEXBLADE_WITCH)
	var aimed := _ghoul(Vector2(600, 500))
	_enemies.rebuild_grid()
	_weapons.fire_main(witch, witch.muzzle_position(), 1, _enemies, false)
	assert_eq(aimed.hp, aimed.max_hp, "only the host deals damage")
	assert_eq(_weapons.effect_counts()["bolts"], 1)


func test_spear_row_strikes_after_the_warning() -> void:
	var necro := _hero_player(Characters.Id.NECROMANCER)
	var row := MainWeapons.spear_row(necro.muzzle_position(), 0.0, necro.stats.projectile_count)
	var target := _ghoul(row[1])
	_fire(necro)
	assert_eq(_weapons.effect_counts()["spears"], necro.stats.projectile_count)
	assert_eq(target.hp, target.max_hp, "warning first")
	_run(necro, necro.stats.weapon_duration + MainWeapons.SPEAR_STAGGER * necro.stats.projectile_count + 0.05)
	assert_gte(target.max_hp - target.hp, necro.stats.bullet_damage, "then the spears")
	assert_eq(_shards, 0, "no shards without Splinters")


func test_splinters_spray_shards() -> void:
	var necro := _hero_player(Characters.Id.NECROMANCER)
	necro.apply_upgrade(_upgrade_id("Splinters"))
	_fire(necro)
	_run(necro, 1.0)
	assert_eq(_shards, necro.stats.projectile_count * 3)


# --- Upgrades, relics, pickups ---

func test_weapon_upgrades_only_go_to_their_hero() -> void:
	for title: String in ["Twin Scythes", "Forked Lightning", "Longer Row", "Extra Bolt", "Ricochet"]:
		var upgrade := Upgrades.get_upgrade(_upgrade_id(title))
		var takers := 0
		for stats: CharacterStats in Characters.ALL:
			if Upgrades.is_offered(upgrade, 0, true, stats):
				takers += 1
				assert_eq(stats.main_weapon, upgrade.for_weapon, title)
		assert_eq(takers, 1, title)
		assert_false(Upgrades.is_offered(upgrade, 0, true, null), "no stats: no weapon upgrades")


func test_every_hero_has_weapon_upgrades() -> void:
	for stats: CharacterStats in Characters.ALL:
		var count := 0
		for upgrade: Upgrade in Upgrades.ALL:
			if upgrade.for_weapon == stats.main_weapon:
				count += 1
				assert_true(PixelArt.has_sprite(upgrade.icon), upgrade.title)
		assert_gte(count, 4, stats.display_name)


func test_weapon_upgrade_cards_name_the_right_thing() -> void:
	var keeper := _hero_player(Characters.Id.GRAVEKEEPER)
	assert_eq(Upgrades.preview_text(_upgrade_id("Twin Scythes"), keeper.stats, keeper.health), "Scythes 1 -> 2")
	var witch := _hero_player(Characters.Id.HEXBLADE_WITCH)
	assert_eq(Upgrades.preview_text(_upgrade_id("Long Arc"), witch.stats, witch.health).split("\n").size(), 2,
		"reach and jump range")
	witch.apply_upgrade(_upgrade_id("Long Arc"))
	assert_almost_eq(witch.stats.weapon_reach, Characters.get_character(Characters.Id.HEXBLADE_WITCH).weapon_reach * 1.25, 0.01)


func test_bolt_relics_only_offered_to_bolt_heroes() -> void:
	var keeper := Characters.get_character(Characters.Id.GRAVEKEEPER)
	var wanderer := Characters.get_character(Characters.Id.WANDERER)
	var none: Array[int] = []
	var seen_for_wanderer := false
	for seed_value: int in 200:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		for id: int in Relics.roll_offers(rng, none, true, keeper):
			assert_lt(Relics.get_relic(id).for_weapon, 0, "Gravekeeper never sees bolt relics")
		rng.seed = seed_value
		for id: int in Relics.roll_offers(rng, none, true, wanderer):
			seen_for_wanderer = seen_for_wanderer or Relics.get_relic(id).for_weapon == CharacterStats.MainWeapon.BOLTS
	assert_true(seen_for_wanderer)


func test_main_weapons_are_not_pickups() -> void:
	for id: int in [AutoWeapons.Id.REAPERS_SCYTHE, AutoWeapons.Id.CHAIN_LIGHTNING, AutoWeapons.Id.BONE_SPEARS]:
		assert_does_not_have(AutoWeapons.PICKUPS, id)
	var player := _hero_player(Characters.Id.WANDERER)
	for i: int in 100:
		assert_has(AutoWeapons.PICKUPS, _weapons.random_upgradable_weapon(player))


func test_run_summary_names_the_main_weapon() -> void:
	var keeper := Characters.get_character(Characters.Id.GRAVEKEEPER)
	assert_eq(DamageSource.title(DamageSource.MAIN_GUN, keeper), "Reaper's Scythe")
	assert_eq(DamageSource.icon(DamageSource.MAIN_GUN, keeper), "icon_reapers_scythe")
