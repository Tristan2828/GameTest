extends GutTest
## Runs a real arena in solo mode (the test runner's default offline peer acts
## as the host) to check the stage flow end to end.

const ARENA_SCENE: PackedScene = preload("res://src/arena/arena.tscn")

var _arena: Arena


func before_each() -> void:
	Net.start_solo()
	_arena = ARENA_SCENE.instantiate()
	add_child_autofree(_arena)
	await wait_process_frames(2)


func _local_player() -> Player:
	return _arena._player_by_id(1)


func test_solo_arena_spawns_the_local_player() -> void:
	assert_not_null(_local_player())
	assert_eq(_arena._phase, Arena.Phase.PLAYING)


func test_boss_arrives_after_the_waves() -> void:
	_arena._elapsed = _arena._wave_duration
	_arena._update_phase()
	var boss := _arena._enemies.find_boss()
	assert_not_null(boss)
	assert_eq(boss.max_hp, EnemyTypes.get_type(EnemyTypes.Id.BONE_WARDEN).max_hp, "solo: no HP scaling")


func test_killing_the_boss_clears_the_stage() -> void:
	_arena._spawn_boss()
	var boss := _arena._enemies.find_boss()
	_arena._enemies.damage(boss, boss.hp, 1)
	_arena._update_phase()
	assert_eq(_arena._phase, Arena.Phase.STAGE_CLEAR)
	assert_eq(_arena._enemies.active_count(), 0)


func test_boss_attacks_fire_enemy_bullets() -> void:
	_arena._spawn_boss()
	for i: int in 60 * 4:
		_arena._tick_boss(1.0 / 60.0)
	_arena._enemy_bullets.step(0.0)
	assert_gt(_arena._enemy_bullets.count(), 0)


func test_everyone_down_ends_the_run() -> void:
	_local_player().health.take_hit(99, 1.0)
	_arena._update_phase()
	assert_eq(_arena._phase, Arena.Phase.RUN_OVER)


func test_level_up_pauses_until_pick_then_applies_upgrade() -> void:
	_arena._on_gem_collected(TeamProgress.xp_to_next(1), 1)
	await wait_physics_frames(2)
	assert_eq(_arena._phase, Arena.Phase.LEVEL_UP)
	var clock := _arena._elapsed
	await wait_physics_frames(10)
	assert_eq(_arena._elapsed, clock, "the stage clock is frozen during the pause")
	var choice: int = _arena._level_up._my_choices[0]
	_arena._level_up._pick_locally(choice)
	await wait_physics_frames(2)
	assert_eq(_arena._phase, Arena.Phase.PLAYING)
	assert_eq(_local_player().upgrade_ids, [choice])


func _bomb_input(count: int) -> PlayerInput:
	var input := PlayerInput.new()
	input.bomb_count = count
	return input


func test_bomb_press_spends_one_bomb_and_stops_at_zero() -> void:
	var player := _local_player()
	watch_signals(player)
	player._simulate(_bomb_input(1), 1.0 / 60.0)
	player._simulate(_bomb_input(1), 1.0 / 60.0)
	assert_eq(player.bombs_left, player.stats.bombs_per_stage - 1, "holding doesn't re-trigger")
	player._simulate(_bomb_input(2), 1.0 / 60.0)
	player._simulate(_bomb_input(3), 1.0 / 60.0)
	assert_eq(player.bombs_left, 0)
	assert_signal_emit_count(player, "bomb_requested", 2)


func test_bomb_clears_bullets_damages_enemies_and_protects() -> void:
	var player := _local_player()
	var at := player.state.position
	_arena._enemy_bullets.spawn(at + Vector2(100, 0), Vector2.ZERO, 1, 5.0, 0)
	_arena._enemy_bullets.spawn(at + Vector2(400, 0), Vector2.ZERO, 1, 5.0, 0)
	var ghoul := _arena._enemies.spawn(EnemyTypes.Id.GHOUL, at + Vector2(50, 0))
	_arena._enemies.rebuild_grid()
	_arena._on_player_bomb_requested(player)
	assert_eq(_arena._enemy_bullets.count(), 1, "far bullet survives")
	assert_eq(ghoul.hp, ghoul.max_hp - Arena.BOMB_DAMAGE)
	assert_true(player.health.is_invulnerable())
