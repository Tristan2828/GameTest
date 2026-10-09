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


func test_host_hit_damages_enemy_and_credits_shooter() -> void:
	_enemies.spawn_dummies([Vector2(300, 300)])
	_projectiles.spawn(Vector2(300, 300), Vector2.ZERO, 25, 5.0, 42)
	_projectiles.resolve_hits(_enemies, true)
	assert_eq(_projectiles.count(), 0)
	assert_eq(_enemies.find_hit(Vector2(300, 300), 1.0).hp, EnemyManager.DUMMY_HP - 25)
	assert_eq(_enemies.damage_by_peer[42], 25)


func test_client_hit_removes_bullet_without_damage() -> void:
	_enemies.spawn_dummies([Vector2(300, 300)])
	_projectiles.spawn(Vector2(300, 300), Vector2.ZERO, 25, 5.0, 42)
	_projectiles.resolve_hits(_enemies, false)
	assert_eq(_projectiles.count(), 0)
	assert_eq(_enemies.find_hit(Vector2(300, 300), 1.0).hp, EnemyManager.DUMMY_HP)


func test_dummy_dies_and_respawns() -> void:
	_enemies.spawn_dummies([Vector2(300, 300)])
	var dummy := _enemies.find_hit(Vector2(300, 300), 1.0)
	_enemies.damage(dummy, EnemyManager.DUMMY_HP + 50, 1)
	assert_false(dummy.active)
	assert_eq(_enemies.damage_by_peer[1], EnemyManager.DUMMY_HP, "overkill is not counted")
	_enemies.tick_host(EnemyManager.RESPAWN_DELAY + 0.1)
	assert_true(dummy.active)
	assert_eq(dummy.hp, EnemyManager.DUMMY_HP)


func test_dummy_ignores_damage_when_inactive() -> void:
	var dummy := DummyEnemy.new()
	add_child_autofree(dummy)
	assert_false(dummy.apply_damage(10))
	assert_eq(dummy.hp, dummy.max_hp)
