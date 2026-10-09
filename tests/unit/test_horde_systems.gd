extends GutTest


# --- SpatialGrid ---

func test_grid_finds_nearby_ids_only() -> void:
	var grid := SpatialGrid.new(32.0)
	grid.insert(1, Vector2(10, 10))
	grid.insert(2, Vector2(40, 10))
	grid.insert(3, Vector2(500, 500))
	var found: Array[int] = []
	grid.query(Vector2(20, 10), 25.0, found)
	assert_has(found, 1)
	assert_has(found, 2)
	assert_does_not_have(found, 3)


func test_grid_handles_negative_coordinates() -> void:
	var grid := SpatialGrid.new(32.0)
	grid.insert(7, Vector2(-5, -5))
	var found: Array[int] = []
	grid.query(Vector2(2, 2), 10.0, found)
	assert_has(found, 7)


# --- SpawnDirector ---

func test_spawn_rate_ramps_over_time() -> void:
	assert_gt(SpawnDirector.spawns_per_second(240.0, 1), SpawnDirector.spawns_per_second(0.0, 1))


func test_more_players_means_more_spawns() -> void:
	var solo := SpawnDirector.spawns_per_second(60.0, 1)
	assert_almost_eq(SpawnDirector.spawns_per_second(60.0, 2), solo * 1.6, 0.0001)
	assert_almost_eq(SpawnDirector.spawns_per_second(60.0, 4), solo * 2.8, 0.0001)


func test_director_spawns_expected_amount() -> void:
	var director := SpawnDirector.new(1)
	var total := 0
	for i: int in 600:
		total += director.tick(1.0 / 60.0, 0.0, 1, 0).size()
	assert_between(total, 9, 11, "10 seconds at 1 spawn/s")


func test_director_respects_alive_cap() -> void:
	var director := SpawnDirector.new(1)
	assert_eq(director.tick(10.0, 0.0, 1, SpawnDirector.MAX_ALIVE).size(), 0)


func test_only_shamblers_early_then_mix() -> void:
	var director := SpawnDirector.new(5)
	for i: int in 200:
		assert_eq(director.pick_type(10.0), EnemyTypes.Id.SHAMBLER)
	var seen: Dictionary[int, bool] = {}
	for i: int in 500:
		seen[director.pick_type(200.0)] = true
	assert_eq(seen.size(), 4, "every type appears later in the stage")


func test_pack_comes_once_per_interval() -> void:
	var director := SpawnDirector.new(3)
	assert_false(director.pack_due(1.0, 0))
	assert_true(director.pack_due(SpawnDirector.PACK_INTERVAL_MAX, 0))
	assert_false(director.pack_due(SpawnDirector.PACK_INTERVAL_MAX + 1.0, 0))


# --- PlayerHealth ---

func test_hit_removes_heart_and_grants_invulnerability() -> void:
	var health := PlayerHealth.new()
	health.reset(3)
	assert_true(health.take_hit(1, 1.0))
	assert_eq(health.hearts, 2)
	assert_false(health.take_hit(1, 1.0), "invulnerable right after a hit")
	health.tick(1.1)
	assert_true(health.take_hit(1, 1.0))
	assert_eq(health.hearts, 1)


func test_zero_hearts_is_downed_and_ignores_heals() -> void:
	var health := PlayerHealth.new()
	health.reset(1)
	health.take_hit(5, 1.0)
	assert_true(health.is_downed())
	assert_eq(health.hearts, 0)
	health.heal(1)
	assert_true(health.is_downed())


func test_heal_caps_at_max() -> void:
	var health := PlayerHealth.new()
	health.reset(3)
	health.take_hit(1, 0.0)
	health.heal(5)
	assert_eq(health.hearts, 3)
