extends GutTest
## The v0.16 upgrades: hero-only and trade-off rolls, multi-effect upgrades,
## damage bonuses (crit, bosses, wounded), Ricochet and Hunting Bolts.

var _projectiles: ProjectileManager
var _enemies: EnemyManager


func before_each() -> void:
	_projectiles = ProjectileManager.new()
	_projectiles.bounds = Rect2(0, 0, 960, 540)
	add_child_autofree(_projectiles)
	_enemies = EnemyManager.new()
	add_child_autofree(_enemies)


func _id_of(title: String) -> int:
	for id: int in Upgrades.ALL.size():
		if Upgrades.ALL[id].title == title:
			return id
	fail_test("no upgrade called %s" % title)
	return -1


func _hero(index: int) -> CharacterStats:
	return (Characters.ALL[index] as CharacterStats).duplicate() as CharacterStats


func _offered_ever(stats: CharacterStats, id: int) -> bool:
	var owned: Array[int] = []
	for seed_value: int in 300:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		if Upgrades.roll(rng, owned, true, stats).has(id):
			return true
	return false


# --- Rolling ---

func test_every_hero_has_exactly_one_hero_upgrade() -> void:
	for character: CharacterStats in Characters.ALL:
		var count := 0
		for upgrade: Upgrade in Upgrades.ALL:
			if upgrade.for_ability == character.ability:
				count += 1
		assert_eq(count, 1, character.display_name)


func test_hero_upgrades_only_go_to_their_hero() -> void:
	var afterimage := _id_of("Afterimage")
	var wanderer := _hero(0)
	assert_eq(wanderer.ability, CharacterStats.Ability.DASH)
	assert_true(_offered_ever(wanderer, afterimage))
	for index: int in range(1, Characters.ALL.size()):
		assert_false(_offered_ever(_hero(index), afterimage), _hero(index).display_name)
	assert_false(_offered_ever(null, afterimage), "no stats: no hero upgrades")


func test_heart_cutting_upgrade_not_offered_at_one_max_heart() -> void:
	var glass_cannon := _id_of("Glass Cannon")
	var stats := _hero(0)
	assert_true(_offered_ever(stats, glass_cannon))
	stats.max_hearts = 1
	assert_false(_offered_ever(stats, glass_cannon))


func test_hero_text_names_the_hero() -> void:
	assert_eq(Upgrades.hero_text(Upgrades.get_upgrade(_id_of("Deep Hex"))), "Hexblade Witch only")
	assert_eq(Upgrades.hero_text(Upgrades.get_upgrade(_id_of("Ricochet"))), "")


# --- Applying ---

func test_trade_off_applies_both_effects_and_previews_both() -> void:
	var stats := CharacterStats.new()
	var health := PlayerHealth.new()
	health.reset(stats.max_hearts)
	var id := _id_of("Glass Cannon")
	assert_eq(Upgrades.preview_text(id, stats, health), "Damage 10 -> 20\nMax hearts 3 -> 2")
	Upgrades.apply(id, stats, health)
	assert_eq(stats.bullet_damage, 20)
	assert_eq(stats.max_hearts, 2)
	assert_eq(health.hearts, 2)


func test_hero_upgrades_change_their_ability() -> void:
	var health := PlayerHealth.new()
	var keeper := _hero(1)
	var damage := keeper.blast_damage
	var heal := keeper.blast_heal
	Upgrades.apply(_id_of("Hallowed Blast"), keeper, health)
	assert_gt(keeper.blast_damage, damage)
	assert_eq(keeper.blast_heal, heal + 1)
	var witch := _hero(2)
	var seconds := witch.hex_duration
	Upgrades.apply(_id_of("Deep Hex"), witch, health)
	assert_almost_eq(witch.hex_duration, seconds + 1.0, 0.001)
	var wanderer := _hero(0)
	Upgrades.apply(_id_of("Afterimage"), wanderer, health)
	assert_gt(wanderer.dash_grace, 0.0)


func test_relic_effects_still_apply() -> void:
	var stats := CharacterStats.new()
	var health := PlayerHealth.new()
	health.reset(stats.max_hearts)
	for id: int in Relics.ALL.size():
		Relics.apply(id, stats, health)
	assert_gt(stats.bullet_damage, 10, "Cursed Skull still adds damage")


# --- Damage bonuses ---

func test_hit_bonus_math() -> void:
	var stats := CharacterStats.new()
	assert_eq(HitBonus.scaled(10, stats, true, 0.1, false), 10, "no upgrades: plain damage")
	stats.boss_damage_bonus = 0.5
	stats.wounded_damage_bonus = 0.3
	assert_eq(HitBonus.scaled(10, stats, true, 1.0, false), 15)
	assert_eq(HitBonus.scaled(10, stats, false, 0.4, false), 13)
	assert_eq(HitBonus.scaled(10, stats, false, 0.6, false), 10, "not wounded yet")
	assert_eq(HitBonus.scaled(10, stats, false, 1.0, true), 20, "crits double")
	stats.crit_chance = 0.25
	assert_true(HitBonus.is_crit(stats, DamageSource.MAIN_GUN, 0.2))
	assert_false(HitBonus.is_crit(stats, DamageSource.MAIN_GUN, 0.3))
	assert_false(HitBonus.is_crit(stats, DamageSource.ABILITY, 0.0), "only bolts crit")


func test_enemy_manager_applies_attacker_bonuses_and_flags_crits() -> void:
	var stats := CharacterStats.new()
	stats.crit_chance = 1.0
	_enemies.stats_of_peer = func(peer_id: int) -> CharacterStats:
		return stats if peer_id == 7 else null
	var enemy := _enemies.spawn(EnemyTypes.Id.SHAMBLER, Vector2(300, 300))
	watch_signals(_enemies)
	_enemies.damage(enemy, 5, 7)
	assert_eq(enemy.hp, enemy.max_hp - 10)
	assert_signal_emitted(_enemies, "enemy_crit")
	assert_true(enemy.crit_since_snapshot)
	_enemies.damage(enemy, 5, 8)
	assert_eq(enemy.hp, enemy.max_hp - 15, "another peer without stats: plain damage")


# --- Ricochet and homing ---

func test_ricochet_bounces_to_the_next_enemy() -> void:
	var first := _enemies.spawn(EnemyTypes.Id.SHAMBLER, Vector2(300, 300))
	var second := _enemies.spawn(EnemyTypes.Id.SHAMBLER, Vector2(300, 360))
	_enemies.rebuild_grid()
	_projectiles.spawn(Vector2(290, 300), Vector2(200, 0), 5, 2.0, 1, 0, 0.0, DamageSource.MAIN_GUN, 1)
	for i: int in 60:
		_projectiles.step(1.0 / 60.0)
		_projectiles.resolve_hits(_enemies, true)
	assert_eq(first.hp, first.max_hp - 5)
	assert_eq(second.hp, second.max_hp - 5, "bounced into the second enemy")
	assert_eq(_projectiles.count(), 0, "no bounces left: used up")


func test_without_ricochet_the_bolt_stops() -> void:
	var first := _enemies.spawn(EnemyTypes.Id.SHAMBLER, Vector2(300, 300))
	var second := _enemies.spawn(EnemyTypes.Id.SHAMBLER, Vector2(300, 360))
	_enemies.rebuild_grid()
	_projectiles.spawn(Vector2(290, 300), Vector2(200, 0), 5, 2.0, 1)
	for i: int in 60:
		_projectiles.step(1.0 / 60.0)
		_projectiles.resolve_hits(_enemies, true)
	assert_eq(first.hp, first.max_hp - 5)
	assert_eq(second.hp, second.max_hp)


func test_homing_bolts_curve_toward_an_enemy() -> void:
	_enemies.spawn(EnemyTypes.Id.SHAMBLER, Vector2(300, 260))
	_enemies.rebuild_grid()
	_projectiles.spawn(Vector2(200, 300), Vector2(150, 0), 5, 2.0, 1, 0, 0.0, DamageSource.MAIN_GUN, 0, 3.0)
	_projectiles.spawn(Vector2(200, 300), Vector2(150, 0), 5, 2.0, 1)
	for i: int in 20:
		_projectiles.steer(_enemies, 1.0 / 60.0)
		_projectiles.step(1.0 / 60.0)
	assert_lt(_projectiles.position_of(0).y, 299.0, "homing bolt turned up toward the enemy")
	assert_almost_eq(_projectiles.position_of(1).y, 300.0, 0.01, "plain bolt flies straight")
