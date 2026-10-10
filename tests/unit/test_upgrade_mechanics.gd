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

func test_old_ability_upgrades_are_retired() -> void:
	for title: String in ["Afterimage", "Hallowed Blast", "Deep Hex", "Ossuary"]:
		var id := _id_of(title)
		assert_true(Upgrades.get_upgrade(id).retired, title)
		for index: int in Characters.ALL.size():
			assert_false(_offered_ever(_hero(index), id), "%s offered to %s" % [title, _hero(index).display_name])


func test_auto_weapon_boosts_wait_for_an_auto_weapon() -> void:
	var focus := Upgrades.get_upgrade(_id_of("Arcane Focus"))
	assert_true(Upgrades.is_offered(focus, 0, true, _hero(0), true))
	assert_false(Upgrades.is_offered(focus, 0, true, _hero(0), false))


func test_hp_cutting_upgrade_not_offered_when_too_low() -> void:
	var glass_cannon := _id_of("Glass Cannon")
	var stats := _hero(0)
	assert_true(_offered_ever(stats, glass_cannon))
	stats.max_hp = 40
	assert_false(_offered_ever(stats, glass_cannon))


func test_hero_text_names_the_hero() -> void:
	assert_eq(Upgrades.hero_text(Upgrades.get_upgrade(_id_of("Ricochet"))), "Kael only", "a bolt upgrade")
	assert_eq(Upgrades.hero_text(Upgrades.get_upgrade(_id_of("Twin Scythes"))), "Mortimer only")
	assert_eq(Upgrades.hero_text(Upgrades.get_upgrade(_id_of("Sharpened Edge"))), "")


# --- Applying ---

func test_trade_off_applies_both_effects_and_previews_both() -> void:
	var stats := CharacterStats.new()
	var health := PlayerHealth.new()
	health.reset(stats.max_hp)
	var id := _id_of("Glass Cannon")
	assert_eq(Upgrades.preview_text(id, stats, health), "Damage 10 -> 20\nMax HP 100 -> 80")
	Upgrades.apply(id, stats, health)
	assert_eq(stats.bullet_damage, 20)
	assert_eq(stats.max_hp, 80)
	assert_eq(health.hp, 80)


func test_auto_weapon_upgrades_and_recovery() -> void:
	var stats := CharacterStats.new()
	var health := PlayerHealth.new()
	Upgrades.apply(_id_of("Shadow Step"), stats, health)
	assert_almost_eq(stats.auto_cooldown_scale, 0.88, 0.0001)
	Upgrades.apply(_id_of("Arcane Focus"), stats, health)
	assert_almost_eq(stats.auto_power, 1.15, 0.0001)
	Upgrades.apply(_id_of("Ghoul Blood"), stats, health)
	assert_almost_eq(stats.recovery, 0.4, 0.0001)


func test_relic_effects_still_apply() -> void:
	var stats := CharacterStats.new()
	var health := PlayerHealth.new()
	health.reset(stats.max_hp)
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
