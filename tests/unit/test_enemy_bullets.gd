extends GutTest

const DELTA: float = 1.0 / 60.0
const PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")


func _player_at(at: Vector2) -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	player.setup(1, 0, at, Rect2(0, 0, 2000, 2000))
	add_child_autofree(player)
	return player


func _bullets() -> ProjectileManager:
	var bullets := ProjectileManager.new()
	bullets.hit_radius = 2.5
	add_child_autofree(bullets)
	return bullets


# --- Patterns ---

func test_every_enemy_pattern_is_deterministic() -> void:
	for pattern: int in [ShotPatterns.Id.AIMED_FAN_3, ShotPatterns.Id.RING_24, ShotPatterns.Id.SPIRAL,
			ShotPatterns.Id.DOUBLE_SPIRAL, ShotPatterns.Id.AIMED_FAN_7]:
		var a := ShotPatterns.build(pattern as ShotPatterns.Id, 1.0, 999)
		var b := ShotPatterns.build(pattern as ShotPatterns.Id, 1.0, 999)
		assert_eq(a, b, "pattern %d" % pattern)
		assert_gt(a.size(), 0)


func test_ring_covers_full_circle() -> void:
	var angles := ShotPatterns.angles(ShotPatterns.Id.RING_24, 0.0, 5)
	assert_eq(angles.size(), 24)
	assert_almost_eq(wrapf(angles[1] - angles[0], 0.0, TAU), TAU / 24.0, 0.0001)


func test_spiral_bullets_are_staggered_in_time() -> void:
	var bullets := ShotPatterns.build(ShotPatterns.Id.SPIRAL, 0.0, 5)
	var last_delay := bullets[bullets.size() - 1]
	assert_almost_eq(last_delay, (ShotPatterns.SPIRAL_BULLETS - 1) * ShotPatterns.SPIRAL_INTERVAL, 0.0001)
	assert_eq(ShotPatterns.build(ShotPatterns.Id.DOUBLE_SPIRAL, 0.0, 5).size(), bullets.size() * 2)


func test_aimed_fan_is_centered_on_aim() -> void:
	var angles := ShotPatterns.angles(ShotPatterns.Id.AIMED_FAN_3, 0.7, 1)
	assert_almost_eq(angles[1], 0.7, 0.0001)


# --- Delayed bullets ---

func test_delayed_bullet_waits_then_flies() -> void:
	var bullets := _bullets()
	bullets.spawn(Vector2(100, 100), Vector2(60, 0), 1, 5.0, 0, 0, -0.5)
	bullets.step(0.25)
	assert_eq(bullets.count(), 1)
	bullets.step(0.5)
	assert_almost_eq(bullets.position_of(0).x, 115.0, 0.01, "flew for 0.25s after appearing")


func test_fast_forwarded_bullet_starts_along_its_path() -> void:
	var bullets := _bullets()
	bullets.spawn(Vector2(100, 100), Vector2(100, 0), 1, 5.0, 0, 0, 0.2)
	assert_almost_eq(bullets.position_of(0).x, 120.0, 0.01)


func test_delayed_bullet_cannot_hit_before_it_appears() -> void:
	var bullets := _bullets()
	var player := _player_at(Vector2(100, 100))
	bullets.spawn(Vector2(100, 100), Vector2.ZERO, 1, 5.0, 0, 0, -1.0)
	var players: Array[Player] = [player]
	bullets.resolve_player_hits(players, true)
	assert_eq(player.health.hearts, player.health.max_hearts)


# --- Hitting players ---

func test_host_bullet_hit_costs_a_heart_and_is_consumed() -> void:
	var bullets := _bullets()
	var player := _player_at(Vector2(100, 100))
	bullets.spawn(Vector2(101, 100), Vector2.ZERO, 1, 5.0, 0)
	var players: Array[Player] = [player]
	bullets.resolve_player_hits(players, true)
	assert_eq(player.health.hearts, player.health.max_hearts - 1)
	assert_eq(bullets.count(), 0)


func test_tiny_hitbox_lets_bullets_graze_past() -> void:
	var bullets := _bullets()
	var player := _player_at(Vector2(100, 100))
	# Overlaps the drawn body (radius 6) but not the 2px hitbox.
	bullets.spawn(Vector2(105, 100), Vector2.ZERO, 1, 5.0, 0)
	var players: Array[Player] = [player]
	bullets.resolve_player_hits(players, true)
	assert_eq(player.health.hearts, player.health.max_hearts)
	assert_eq(bullets.count(), 1)


func test_bullets_pass_through_invulnerable_players() -> void:
	var bullets := _bullets()
	var player := _player_at(Vector2(100, 100))
	player.health.invulnerable_left = 1.0
	bullets.spawn(Vector2(100, 100), Vector2.ZERO, 1, 5.0, 0)
	var players: Array[Player] = [player]
	bullets.resolve_player_hits(players, true)
	assert_eq(player.health.hearts, player.health.max_hearts)
	assert_eq(bullets.count(), 1, "not consumed")


func test_client_bullet_vanishes_without_damage() -> void:
	var bullets := _bullets()
	var player := _player_at(Vector2(100, 100))
	bullets.spawn(Vector2(100, 100), Vector2.ZERO, 1, 5.0, 0)
	var players: Array[Player] = [player]
	bullets.resolve_player_hits(players, false)
	assert_eq(bullets.count(), 0)
	assert_eq(player.health.hearts, player.health.max_hearts)


func test_clear_near_only_removes_nearby_bullets() -> void:
	var bullets := _bullets()
	bullets.spawn(Vector2(100, 100), Vector2.ZERO, 1, 5.0, 0)
	bullets.spawn(Vector2(500, 500), Vector2.ZERO, 1, 5.0, 0)
	assert_eq(bullets.clear_near(Vector2(110, 100), 50.0), 1)
	assert_eq(bullets.count(), 1)


# --- Ranged enemies ---

func test_cultist_fires_at_targets_in_range_only() -> void:
	var enemies := EnemyManager.new()
	add_child_autofree(enemies)
	var cultist := enemies.spawn(EnemyTypes.Id.CULTIST, Vector2(100, 100))
	cultist.fire_cooldown = 0.0
	watch_signals(enemies)
	var far: Array[Vector2] = [Vector2(1000, 100)]
	enemies.tick_host(DELTA, far)
	assert_signal_not_emitted(enemies, "pattern_fired")
	var near: Array[Vector2] = [Vector2(250, 100)]
	enemies.tick_host(DELTA, near)
	assert_signal_emitted(enemies, "pattern_fired")


func test_cultist_backs_away_when_too_close() -> void:
	var enemies := EnemyManager.new()
	add_child_autofree(enemies)
	var cultist := enemies.spawn(EnemyTypes.Id.CULTIST, Vector2(100, 100))
	var target: Array[Vector2] = [Vector2(150, 100)]
	enemies.tick_host(0.5, target)
	assert_lt(cultist.position.x, 100.0)
