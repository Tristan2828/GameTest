extends GutTest

const DELTA: float = 1.0 / 60.0

var _gems: GemManager


func before_each() -> void:
	_gems = GemManager.new()
	add_child_autofree(_gems)


# --- TeamProgress ---

func test_xp_curve_grows_each_level() -> void:
	assert_eq(TeamProgress.xp_to_next(1), 5)
	assert_eq(TeamProgress.xp_to_next(2), 10)
	assert_gt(TeamProgress.xp_to_next(10), TeamProgress.xp_to_next(9))


func test_adding_xp_levels_up_and_keeps_leftover() -> void:
	var team := TeamProgress.new()
	assert_eq(team.add_xp(4), 0)
	assert_eq(team.add_xp(3), 1)
	assert_eq(team.level, 2)
	assert_eq(team.xp, 2)


func test_big_xp_gain_can_give_several_levels() -> void:
	var team := TeamProgress.new()
	assert_eq(team.add_xp(5 + 10 + 15), 3)
	assert_eq(team.level, 4)
	assert_eq(team.xp, 0)


# --- GemManager ---

func _players(at: Vector2, radius: float = 40.0) -> Array[Dictionary]:
	var positions: Dictionary[int, Vector2] = {7: at}
	var radii: Dictionary[int, float] = {7: radius}
	return [positions, radii]


func test_gem_out_of_range_stays_put() -> void:
	_gems.spawn_host(Vector2(500, 500), 1)
	var players := _players(Vector2(100, 100))
	watch_signals(_gems)
	for i: int in 60:
		_gems.tick(DELTA, players[0], players[1], true)
	assert_eq(_gems.count(), 1)
	assert_signal_not_emitted(_gems, "collected")


func test_gem_in_range_flies_to_player_and_is_collected() -> void:
	_gems.spawn_host(Vector2(130, 100), 5)
	var players := _players(Vector2(100, 100))
	watch_signals(_gems)
	for i: int in 60:
		_gems.tick(DELTA, players[0], players[1], true)
	assert_eq(_gems.count(), 0)
	assert_signal_emitted_with_parameters(_gems, "collected", [5, 7])


func test_clients_pull_but_never_collect_on_their_own() -> void:
	_gems.spawn_host(Vector2(130, 100), 1)
	var players := _players(Vector2(100, 100))
	for i: int in 60:
		_gems.tick(DELTA, players[0], players[1], false)
	assert_eq(_gems.count(), 1, "only the host's pickup event removes gems on clients")
	assert_almost_eq(_gems.nearest_gem(Vector2.ZERO).distance_to(Vector2(100, 100)), 0.0, 0.5)


func test_downed_or_missing_target_releases_the_pull() -> void:
	_gems.spawn_host(Vector2(130, 100), 1)
	var players := _players(Vector2(100, 100))
	_gems.tick(DELTA, players[0], players[1], true)
	var nobody: Dictionary[int, Vector2] = {}
	var no_radii: Dictionary[int, float] = {}
	var stopped_at := _gems.nearest_gem(Vector2.ZERO)
	_gems.tick(DELTA, nobody, no_radii, true)
	assert_eq(_gems.nearest_gem(Vector2.ZERO), stopped_at)


func test_pool_full_reports_failure() -> void:
	for i: int in GemManager.CAPACITY:
		assert_true(_gems.spawn_host(Vector2(i, 0), 1))
	assert_false(_gems.spawn_host(Vector2.ZERO, 1))


func test_client_mirrors_spawn_and_collect_events() -> void:
	var client := GemManager.new()
	add_child_autofree(client)
	client._receive_spawns(PackedInt32Array([3, 9]), PackedVector2Array([Vector2(1, 1), Vector2(2, 2)]), PackedInt32Array([1, 5]))
	assert_eq(client.count(), 2)
	client._receive_collected(1, PackedInt32Array([3]))
	assert_eq(client.count(), 1)
	assert_eq(client.nearest_gem(Vector2.ZERO), Vector2(2, 2))


func test_clear_removes_everything() -> void:
	_gems.spawn_host(Vector2(1, 1), 1)
	_gems.spawn_host(Vector2(2, 2), 1)
	_gems.clear()
	assert_eq(_gems.count(), 0)
	assert_true(_gems.spawn_host(Vector2(3, 3), 1), "released slots are reusable")
