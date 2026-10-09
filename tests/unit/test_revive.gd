extends GutTest
## Co-op revives: the pure rules, and a real arena with a second player.

const ARENA_SCENE: PackedScene = preload("res://src/arena/arena.tscn")
const DELTA: float = 1.0 / 60.0

var _arena: Arena


# --- Revive (pure rules) ---

func test_circle_fills_with_helpers_and_drains_without() -> void:
	var progress := Revive.step(0.0, 1.0, 1.0)
	assert_almost_eq(progress, 1.0 / Revive.SECONDS, 0.001)
	assert_almost_eq(Revive.step(0.0, 2.0, 1.0), 2.0 / Revive.SECONDS, 0.001, "two helpers: twice as fast")
	assert_almost_eq(Revive.step(progress, 0.0, 1.0), maxf(progress - Revive.DRAIN_PER_SECOND, 0.0), 0.001)
	assert_eq(Revive.step(0.9, 1.0, 10.0), 1.0, "never above full")
	assert_eq(Revive.step(0.05, 0.0, 10.0), 0.0, "never below empty")


func test_revived_hearts_are_half_rounded_up() -> void:
	assert_eq(Revive.hearts_after(3), 2)
	assert_eq(Revive.hearts_after(2), 1)
	assert_eq(Revive.hearts_after(5), 3)
	assert_eq(Revive.hearts_after(1), 1)


func test_in_range_uses_the_circle_radius() -> void:
	assert_true(Revive.in_range(Vector2.ZERO, Vector2(Revive.RADIUS - 1.0, 0.0)))
	assert_false(Revive.in_range(Vector2.ZERO, Vector2(Revive.RADIUS + 1.0, 0.0)))


func test_mourners_bell_doubles_revive_speed_and_is_co_op_only() -> void:
	var bell_id := -1
	for id: int in Relics.ALL.size():
		if Relics.ALL[id].title == "Mourner's Bell":
			bell_id = id
	assert_gt(bell_id, -1)
	var stats := CharacterStats.new()
	Relics.apply(bell_id, stats, PlayerHealth.new())
	assert_almost_eq(stats.revive_speed, 2.0, 0.001)
	var none: Array[int] = []
	for seed_value: int in 30:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		assert_does_not_have(Relics.roll_offers(rng, none, false), bell_id, "never offered solo")


# --- In a real arena (solo host + a second player) ---

func _start_arena() -> void:
	Net.start_solo()
	_arena = ARENA_SCENE.instantiate()
	add_child_autofree(_arena)
	await wait_process_frames(2)
	_arena._add_player(2)
	await wait_process_frames(1)


func _tick_revives(seconds: float) -> void:
	for i: int in roundi(seconds * 60.0):
		_arena._tick_revives(DELTA)


func test_teammate_in_the_circle_revives_with_half_hearts() -> void:
	await _start_arena()
	var helper := _arena._player_by_id(1)
	var downed := _arena._player_by_id(2)
	downed.health.take_hit(99, 0.0)
	downed.state.position = helper.state.position + Vector2(10, 0)
	_tick_revives(Revive.SECONDS * 0.5)
	assert_true(downed.is_downed(), "not yet")
	assert_almost_eq(downed.revive_progress, 0.5, 0.02)
	_tick_revives(Revive.SECONDS * 0.5 + 0.1)
	assert_false(downed.is_downed())
	assert_eq(downed.health.hearts, Revive.hearts_after(downed.health.max_hearts))
	assert_true(downed.health.is_invulnerable(), "a moment of safety")
	assert_eq(_arena._run_stats.get_stat(1, RunStats.Stat.REVIVES), 1)


func test_nobody_in_the_circle_means_no_revive() -> void:
	await _start_arena()
	var helper := _arena._player_by_id(1)
	var downed := _arena._player_by_id(2)
	downed.health.take_hit(99, 0.0)
	downed.state.position = helper.state.position + Vector2(Revive.RADIUS + 40.0, 0)
	_tick_revives(Revive.SECONDS * 2.0)
	assert_true(downed.is_downed())
	assert_eq(downed.revive_progress, 0.0)


func test_one_player_down_is_not_run_over() -> void:
	await _start_arena()
	_arena._player_by_id(2).health.take_hit(99, 0.0)
	_arena._update_phase()
	assert_eq(_arena._phase, Arena.Phase.PLAYING)
	_arena._player_by_id(1).health.take_hit(99, 0.0)
	_arena._update_phase()
	assert_eq(_arena._phase, Arena.Phase.RUN_OVER, "everyone down ends the run")


func test_downed_local_player_spectates_a_living_teammate() -> void:
	await _start_arena()
	var local := _arena._player_by_id(1)
	local.health.take_hit(99, 0.0)
	_arena._update_spectate(Revive.SPECTATE_DELAY + 0.1)
	assert_eq(local.spectate_target, _arena._player_by_id(2))
	_arena._spectate_index += 1
	_arena._update_spectate(DELTA)
	assert_eq(local.spectate_target, local, "the cycle ends on your own body")
	local.revive()
	_arena._update_spectate(DELTA)
	assert_null(local.spectate_target, "back to normal once revived")
