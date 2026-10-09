extends GutTest
## End-of-run extras: per-weapon damage (DamageSource), stars for the best
## player in each stat, and icons for every upgrade and relic.


func test_enemy_damage_is_counted_per_source() -> void:
	var enemies := EnemyManager.new()
	add_child_autofree(enemies)
	var enemy := enemies.spawn(EnemyTypes.Id.SHAMBLER, Vector2(50, 50), 100)
	var aura := DamageSource.of_weapon(AutoWeapons.Id.HOLY_AURA)
	enemies.damage(enemy, 30, 7)
	enemies.damage(enemy, 20, 7, aura)
	enemies.damage(enemy, 500, 7, aura)  # Only the 50 HP left count.
	assert_eq(enemies.damage_by_source[7][DamageSource.MAIN_GUN], 30)
	assert_eq(enemies.damage_by_source[7][aura], 70)
	assert_eq(enemies.kills_by_source[7][aura], 1, "the killing blow gets the kill")
	assert_false(enemies.kills_by_source[7].has(DamageSource.MAIN_GUN))


func test_projectiles_carry_their_source_to_the_hit() -> void:
	var enemies := EnemyManager.new()
	add_child_autofree(enemies)
	var shots := ProjectileManager.new()
	add_child_autofree(shots)
	var enemy := enemies.spawn(EnemyTypes.Id.SHAMBLER, Vector2(50, 50), 100)
	enemies.rebuild_grid()
	var seeker := DamageSource.of_weapon(AutoWeapons.Id.SEEKING_BOLTS)
	shots.spawn(enemy.position, Vector2.ZERO, 12, 1.0, 3, 0, 0.0, seeker)
	shots.resolve_hits(enemies, true)
	assert_eq(enemies.damage_by_source[3][seeker], 12)


func test_breakdown_survives_the_network_encoding_sorted_by_damage() -> void:
	var stats := RunStats.new()
	stats.add(5, RunStats.Stat.KILLS, 1)
	stats.set_source(5, DamageSource.MAIN_GUN, 1000, 40, 120)
	stats.set_source(5, DamageSource.of_weapon(0), 3000, 90, 60)
	stats.set_source(5, DamageSource.ABILITY, 0, 0, 120)
	var copy := RunStats.decode(stats.encode())
	var rows := copy.sources_for(5)
	assert_eq(rows.size(), 3)
	assert_eq(rows[0], [DamageSource.of_weapon(0), 3000, 90, 60], "most damage first")
	assert_eq(rows[1][0], DamageSource.MAIN_GUN)
	assert_almost_eq(RunStats.dps(3000, 60), 50.0, 0.001)
	assert_almost_eq(RunStats.dps(10, 0), 10.0, 0.001, "no divide by zero")


func test_star_goes_to_highest_or_lowest_and_not_on_ties() -> void:
	var stats := RunStats.new()
	stats.add(1, RunStats.Stat.KILLS, 50)
	stats.add(2, RunStats.Stat.KILLS, 80)
	stats.add(1, RunStats.Stat.HEARTS_LOST, 2)
	stats.add(2, RunStats.Stat.HEARTS_LOST, 5)
	assert_eq(stats.best(RunStats.Stat.KILLS), 2)
	assert_eq(stats.best(RunStats.Stat.HEARTS_LOST), 1, "fewer hearts lost is better")
	assert_eq(stats.best(RunStats.Stat.DOWNS), -1, "a tie (both 0): no star")
	var solo := RunStats.new()
	solo.add(1, RunStats.Stat.KILLS, 10)
	assert_eq(solo.best(RunStats.Stat.KILLS), -1, "no stars in solo")


func test_every_upgrade_relic_and_source_has_an_icon() -> void:
	for upgrade: Upgrade in Upgrades.ALL:
		assert_true(PixelArt.has_sprite(upgrade.icon), "%s icon '%s'" % [upgrade.title, upgrade.icon])
	for relic: Relic in Relics.ALL:
		assert_true(PixelArt.has_sprite(relic.icon), "%s icon '%s'" % [relic.title, relic.icon])
	for source: int in DamageSource.FIRST_WEAPON + AutoWeapons.ALL.size():
		assert_true(PixelArt.has_sprite(DamageSource.icon(source)), "source %d" % source)
	assert_true(PixelArt.has_sprite("star"))


func test_compact_numbers() -> void:
	assert_eq(RunSummaryPanel.compact(950), "950")
	assert_eq(RunSummaryPanel.compact(12345), "12.3k")
	assert_eq(RunSummaryPanel.compact(2500000), "2.5M")
