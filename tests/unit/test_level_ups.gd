extends GutTest


func _rng(seed_value: int = 1) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


# --- Upgrades.roll ---

func test_roll_gives_three_different_upgrades() -> void:
	var no_upgrades: Array[int] = []
	for seed_value: int in 50:
		var choices := Upgrades.roll(_rng(seed_value), no_upgrades, true)
		assert_eq(choices.size(), Upgrades.CHOICES_PER_LEVEL)
		assert_ne(choices[0], choices[1])
		assert_ne(choices[1], choices[2])
		assert_ne(choices[0], choices[2])


func test_heal_only_offered_when_hurt() -> void:
	var heal_id := -1
	for id: int in Upgrades.ALL.size():
		if Upgrades.ALL[id].stat == Upgrade.Stat.HEAL:
			heal_id = id
	var no_upgrades: Array[int] = []
	for seed_value: int in 100:
		assert_does_not_have(Upgrades.roll(_rng(seed_value), no_upgrades, false), heal_id)


func test_maxed_upgrades_are_not_offered() -> void:
	var owned: Array[int] = []
	var maxed_id := 4  # Extra Bolt, max 3
	for i: int in Upgrades.get_upgrade(maxed_id).max_stacks:
		owned.append(maxed_id)
	for seed_value: int in 100:
		assert_does_not_have(Upgrades.roll(_rng(seed_value), owned, true), maxed_id)


# --- Upgrades.apply ---

func test_apply_changes_only_the_target_stat() -> void:
	var stats := CharacterStats.new()
	var health := PlayerHealth.new()
	health.reset(stats.max_hearts)
	var base_speed := stats.move_speed
	Upgrades.apply(0, stats, health)  # Sharpened Bolts
	assert_eq(stats.bullet_damage, 13)
	assert_eq(stats.move_speed, base_speed)


func test_heart_container_raises_max_and_heals() -> void:
	var stats := CharacterStats.new()
	var health := PlayerHealth.new()
	health.reset(stats.max_hearts)
	health.take_hit(1, 0.0)
	Upgrades.apply(3, stats, health)  # Heart Container
	assert_eq(stats.max_hearts, 4)
	assert_eq(health.max_hearts, 4)
	assert_eq(health.hearts, 3)


func test_same_upgrades_give_identical_stats_on_every_peer() -> void:
	var host_stats := CharacterStats.new()
	var client_stats := CharacterStats.new()
	var health := PlayerHealth.new()
	for id: int in [1, 2, 7, 1, 2, 6]:
		Upgrades.apply(id, host_stats, health)
		Upgrades.apply(id, client_stats, health)
	assert_eq(host_stats.move_speed, client_stats.move_speed)
	assert_eq(host_stats.fire_interval, client_stats.fire_interval)
	assert_eq(host_stats.dash_cooldown, client_stats.dash_cooldown)


# --- LevelUpSession ---

func _session_for(peers: Array[int]) -> LevelUpSession:
	var offered: Dictionary[int, Array] = {}
	for peer_id: int in peers:
		offered[peer_id] = [0, 1, 2]
	var session := LevelUpSession.new()
	session.start(offered)
	return session


func test_waits_forever_until_someone_picks() -> void:
	var session := _session_for([1, 2])
	session.tick(1000.0)
	assert_false(session.is_finished())
	assert_lt(session.countdown_left, 0.0)


func test_first_pick_starts_countdown() -> void:
	var session := _session_for([1, 2])
	assert_true(session.pick(1, 2))
	assert_eq(session.countdown_left, LevelUpSession.COUNTDOWN_SECONDS)
	session.tick(10.0)
	assert_false(session.is_finished())
	session.tick(25.0)
	assert_true(session.is_finished())


func test_finishes_early_when_everyone_picked() -> void:
	var session := _session_for([1, 2])
	session.pick(1, 0)
	session.pick(2, 1)
	assert_true(session.is_finished())
	assert_eq(session.final_picks(_rng()), {1: 0, 2: 1})


func test_rejects_invalid_and_double_picks() -> void:
	var session := _session_for([1, 2])
	assert_false(session.pick(1, 99), "not one of the offered choices")
	assert_false(session.pick(5, 0), "not a participant")
	assert_true(session.pick(1, 0))
	assert_false(session.pick(1, 1), "already picked")


func test_unpicked_players_get_a_random_offered_choice() -> void:
	var session := _session_for([1, 2])
	session.pick(1, 0)
	session.tick(LevelUpSession.COUNTDOWN_SECONDS)
	var picks := session.final_picks(_rng())
	assert_eq(picks[1], 0)
	assert_has([0, 1, 2], picks[2])


func test_leaving_player_is_not_waited_for() -> void:
	var session := _session_for([1, 2])
	session.pick(1, 0)
	session.remove(2)
	assert_true(session.is_finished())


# --- Extra Bolt / Pierce ---

func test_extra_bolts_fan_around_aim() -> void:
	var angles := ShotPatterns.angles(ShotPatterns.Id.BASIC, 0.0, 123, 3)
	assert_eq(angles.size(), 3)
	var spread := deg_to_rad(ShotPatterns.FAN_SPACING_DEGREES)
	var jitter := deg_to_rad(ShotPatterns.BASIC_SPREAD_DEGREES) + 0.0001
	assert_almost_eq(angles[0], -spread, jitter)
	assert_almost_eq(angles[1], 0.0, jitter)
	assert_almost_eq(angles[2], spread, jitter)


func test_piercing_bullet_passes_through_one_enemy() -> void:
	var enemies := EnemyManager.new()
	add_child_autofree(enemies)
	var projectiles := ProjectileManager.new()
	add_child_autofree(projectiles)
	var first := enemies.spawn(EnemyTypes.Id.GHOUL, Vector2(100, 100))
	var second := enemies.spawn(EnemyTypes.Id.GHOUL, Vector2(140, 100))
	enemies.rebuild_grid()
	projectiles.spawn(Vector2(100, 100), Vector2(600, 0), 10, 5.0, 1, 1)
	for i: int in 10:
		projectiles.resolve_hits(enemies, true)
		projectiles.step(1.0 / 60.0)
	assert_eq(first.hp, first.type.max_hp - 10, "hit once, not every tick while overlapping")
	assert_eq(second.hp, second.type.max_hp - 10)
	assert_eq(projectiles.count(), 0, "pierce used up on the second enemy")
