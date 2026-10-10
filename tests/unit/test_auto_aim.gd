extends GutTest
## Main weapons pick their own targets (AutoAim, v0.22.0): nobody aims by hand.

const FROM: Vector2 = Vector2(100, 100)


func _hero(id: int) -> CharacterStats:
	return Characters.get_character(id)


func test_bolt_gun_shoots_the_nearest_enemy() -> void:
	var enemies := PackedVector2Array([Vector2(300, 100), Vector2(100, 160), Vector2(100, 40)])
	var aim := AutoAim.pick(_hero(Characters.Id.WANDERER), FROM, 0.0, enemies, 0.5)
	assert_almost_eq(aim, (Vector2(100, 40) - FROM).angle(), 0.0001)


func test_nothing_in_reach_means_no_attack() -> void:
	var far := PackedVector2Array([FROM + Vector2(2000, 0)])
	for id: int in Characters.ALL.size():
		assert_true(is_nan(AutoAim.pick(_hero(id), FROM, 0.0, far, 0.5)), str(id))
		assert_true(is_nan(AutoAim.pick(_hero(id), FROM, 0.0, PackedVector2Array(), 0.5)), str(id))


func test_scythe_flies_the_way_you_face() -> void:
	var stats := _hero(Characters.Id.GRAVEKEEPER)
	var enemies := PackedVector2Array([FROM + Vector2(0, 60)])
	assert_almost_eq(AutoAim.pick(stats, FROM, PI, enemies, 0.5), PI, 0.0001, "faces left, enemy below")
	var far := PackedVector2Array([FROM + Vector2(0, stats.weapon_reach * AutoAim.SCYTHE_WAKE_FACTOR + 5.0)])
	assert_true(is_nan(AutoAim.pick(stats, FROM, PI, far, 0.5)), "doesn't throw at nothing")


func test_lightning_and_spears_pick_a_random_enemy_in_reach() -> void:
	for id: int in [Characters.Id.HEXBLADE_WITCH, Characters.Id.NECROMANCER]:
		var stats := _hero(id)
		var near_a := FROM + Vector2(40, 0)
		var near_b := FROM + Vector2(0, 40)
		var enemies := PackedVector2Array([near_a, FROM + Vector2(1000, 0), near_b])
		var picks: Dictionary[float, bool] = {}
		for roll: float in [0.0, 0.3, 0.6, 0.99]:
			var aim := AutoAim.pick(stats, FROM, 0.0, enemies, roll)
			assert_false(is_nan(aim), str(id))
			picks[snappedf(aim, 0.001)] = true
		assert_eq(picks.size(), 2, "both near enemies get picked, never the far one (%d)" % id)
		assert_true(picks.has(snappedf((near_a - FROM).angle(), 0.001)))
		assert_true(picks.has(snappedf((near_b - FROM).angle(), 0.001)))


func test_reach_matches_each_weapon() -> void:
	var wanderer := _hero(Characters.Id.WANDERER)
	assert_almost_eq(AutoAim.reach_of(wanderer), wanderer.bullet_speed * wanderer.bullet_lifetime, 0.001)
	var necro := _hero(Characters.Id.NECROMANCER)
	var row_end := MainWeapons.SPEAR_START + MainWeapons.SPEAR_SPACING * (necro.projectile_count - 1)
	assert_gt(AutoAim.reach_of(necro), row_end, "spears look a bit past the end of their row")


func test_crowd_center_finds_the_biggest_group() -> void:
	var crowd := PackedVector2Array([Vector2(200, 100), Vector2(205, 104), Vector2(198, 96), Vector2(203, 99)])
	var points := crowd.duplicate()
	points.append(Vector2(100, 200))
	var center := AutoWeapons.crowd_center(FROM, points, 200.0)
	assert_almost_eq(center.x, 201.5, 1.0)
	assert_almost_eq(center.y, 99.75, 1.0)
	assert_eq(AutoWeapons.crowd_center(FROM, points, 20.0), Vector2.INF, "nobody in reach")
