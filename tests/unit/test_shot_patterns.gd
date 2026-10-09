extends GutTest


func test_same_seed_gives_identical_bullets() -> void:
	var seed_value := ShotPatterns.make_seed(12345, 77)
	var a := ShotPatterns.angles(ShotPatterns.Id.BASIC, 1.0, seed_value)
	var b := ShotPatterns.angles(ShotPatterns.Id.BASIC, 1.0, seed_value)
	assert_eq(a, b)


func test_different_seeds_vary_the_spread() -> void:
	var a := ShotPatterns.angles(ShotPatterns.Id.BASIC, 1.0, ShotPatterns.make_seed(1, 1))
	var b := ShotPatterns.angles(ShotPatterns.Id.BASIC, 1.0, ShotPatterns.make_seed(1, 2))
	assert_ne(a[0], b[0])


func test_basic_spread_stays_near_aim() -> void:
	var limit := deg_to_rad(ShotPatterns.BASIC_SPREAD_DEGREES) + 0.0001
	for seq: int in 200:
		var angles := ShotPatterns.angles(ShotPatterns.Id.BASIC, 2.0, ShotPatterns.make_seed(1, seq))
		assert_eq(angles.size(), 1)
		assert_almost_eq(angles[0], 2.0, limit)


func test_seed_differs_per_player() -> void:
	assert_ne(ShotPatterns.make_seed(1, 10), ShotPatterns.make_seed(2, 10))
