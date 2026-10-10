extends GutTest

var _projectiles: ProjectileManager
var _enemies: EnemyManager


func before_each() -> void:
	_projectiles = ProjectileManager.new()
	_projectiles.bounds = Rect2(0, 0, 960, 540)
	add_child_autofree(_projectiles)
	_enemies = EnemyManager.new()
	add_child_autofree(_enemies)


func test_bullet_position_follows_velocity() -> void:
	_projectiles.spawn(Vector2(100, 100), Vector2(60, 0), 10, 5.0, 1)
	for i: int in 30:
		_projectiles.step(1.0 / 60.0)
	assert_almost_eq(_projectiles.position_of(0).x, 130.0, 0.01)


func test_bullet_expires_after_lifetime() -> void:
	_projectiles.spawn(Vector2(100, 100), Vector2.ZERO, 10, 0.5, 1)
	_projectiles.step(0.4)
	assert_eq(_projectiles.count(), 1)
	_projectiles.step(0.2)
	assert_eq(_projectiles.count(), 0)


func test_bullet_leaving_bounds_is_removed() -> void:
	_projectiles.spawn(Vector2(950, 100), Vector2(600, 0), 10, 5.0, 1)
	_projectiles.step(0.1)
	assert_eq(_projectiles.count(), 0)


func test_pool_has_fixed_capacity() -> void:
	for i: int in ProjectileManager.CAPACITY:
		_projectiles.spawn(Vector2(100, 100), Vector2.ZERO, 1, 5.0, 1)
	assert_false(_projectiles.spawn(Vector2(100, 100), Vector2.ZERO, 1, 5.0, 1))


func test_removing_a_bullet_keeps_the_others() -> void:
	_projectiles.spawn(Vector2(100, 100), Vector2.ZERO, 10, 0.1, 1)
	_projectiles.spawn(Vector2(200, 200), Vector2.ZERO, 10, 5.0, 1)
	_projectiles.step(0.2)
	assert_eq(_projectiles.count(), 1)
	assert_eq(_projectiles.position_of(0), Vector2(200, 200))


func _spawn_shambler(at: Vector2) -> Enemy:
	var enemy := _enemies.spawn(EnemyTypes.Id.SHAMBLER, at)
	_enemies.rebuild_grid()
	return enemy


func test_host_hit_damages_enemy_and_credits_shooter() -> void:
	var enemy := _spawn_shambler(Vector2(300, 300))
	_projectiles.spawn(Vector2(300, 300), Vector2.ZERO, 7, 5.0, 42)
	_projectiles.resolve_hits(_enemies, true)
	assert_eq(_projectiles.count(), 0)
	assert_eq(enemy.hp, enemy.type.max_hp - 7)
	assert_eq(_enemies.damage_by_peer[42], 7)


func test_enemy_on_top_of_the_shooter_still_gets_hit() -> void:
	# The bolt appears at the muzzle (9 px out) and flies away from the enemy
	# standing on the shooter; the first tick checks back to the shooter's center.
	var enemy := _spawn_shambler(Vector2(300, 300))
	_projectiles.spawn_backtrack = Player.MUZZLE_DISTANCE
	_projectiles.spawn(Vector2(309, 300), Vector2(420, 0), 7, 5.0, 42)
	_projectiles.step(1.0 / 60.0)
	_projectiles.resolve_hits(_enemies, true)
	assert_eq(enemy.hp, enemy.type.max_hp - 7)


func test_fast_bolt_does_not_skip_over_an_enemy() -> void:
	var enemy := _spawn_shambler(Vector2(330, 300))
	_projectiles.spawn(Vector2(300, 300), Vector2(3000, 0), 7, 5.0, 42)
	_projectiles.step(1.0 / 60.0)  # 300 -> 350 in one tick, past the enemy at 330.
	_projectiles.resolve_hits(_enemies, true)
	assert_eq(enemy.hp, enemy.type.max_hp - 7)


func test_client_hit_removes_bullet_without_damage() -> void:
	var enemy := _spawn_shambler(Vector2(300, 300))
	_projectiles.spawn(Vector2(300, 300), Vector2.ZERO, 7, 5.0, 42)
	_projectiles.resolve_hits(_enemies, false)
	assert_eq(_projectiles.count(), 0)
	assert_eq(enemy.hp, enemy.type.max_hp)


func test_killing_returns_enemy_to_pool_and_signals() -> void:
	var enemy := _spawn_shambler(Vector2(300, 300))
	watch_signals(_enemies)
	_enemies.damage(enemy, enemy.type.max_hp + 50, 3)
	assert_false(enemy.active)
	assert_eq(_enemies.active_count(), 0)
	assert_eq(_enemies.damage_by_peer[3], enemy.type.max_hp, "overkill is not counted")
	assert_signal_emitted_with_parameters(_enemies, "enemy_killed", [enemy, 3, DamageSource.MAIN_GUN])


func test_pool_reuses_enemies_and_has_a_limit() -> void:
	for i: int in EnemyManager.POOL_SIZE:
		assert_not_null(_enemies.spawn(EnemyTypes.Id.BAT, Vector2(100, 100)))
	assert_null(_enemies.spawn(EnemyTypes.Id.BAT, Vector2(100, 100)))


func test_enemies_walk_toward_nearest_target() -> void:
	var enemy := _spawn_shambler(Vector2(300, 300))
	var targets: Array[Vector2] = [Vector2(600, 300), Vector2(320, 400)]
	_enemies.tick_host(0.5, targets)
	assert_gt(enemy.position.y, 300.0, "moves toward the closer target (below)")


func test_overlapping_enemies_push_apart() -> void:
	var a := _spawn_shambler(Vector2(300, 300))
	var b := _spawn_shambler(Vector2(302, 300))
	var no_targets: Array[Vector2] = []
	for i: int in 30:
		_enemies.tick_host(1.0 / 60.0, no_targets)
	assert_gt(a.position.distance_to(b.position), 2.0)


func test_snapshot_round_trip_activates_enemies_on_client() -> void:
	var enemy := _spawn_shambler(Vector2(123, 456))
	var client := EnemyManager.new()
	add_child_autofree(client)
	var data := PackedByteArray()
	data.resize(EnemyManager.SNAPSHOT_STRIDE)
	data.encode_u16(0, enemy.pool_index)
	data.encode_u8(2, EnemyTypes.Id.GHOUL)
	data.encode_u8(3, 0)
	data.encode_s16(4, 123)
	data.encode_s16(6, 456)
	data.encode_u8(8, 128)
	client._receive_snapshot(1, data)
	assert_eq(client.active_count(), 1)
	var mirrored: Enemy = client.get_child(enemy.pool_index)
	assert_true(mirrored.active)
	assert_eq(mirrored.type_id, EnemyTypes.Id.GHOUL)
	assert_eq(mirrored.target_position, Vector2(123, 456))
	assert_almost_eq(mirrored.hp_ratio, 0.5, 0.01)
	client._receive_snapshot(0, PackedByteArray())
	assert_false(mirrored.active, "missing from the next snapshot = gone")
