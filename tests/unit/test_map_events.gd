extends GutTest
## Map events (champion lairs, rituals, Grave Robbers, chests) and the fleeing
## enemy movement they use. Host logic with real players and a real enemy pool.

const DELTA: float = 1.0 / 60.0
const PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")

var _enemies: EnemyManager
var _events: MapEvents
var _player: Player


func before_each() -> void:
	_enemies = EnemyManager.new()
	_enemies.bounds = Rect2(0, 0, 1600, 1000)
	add_child_autofree(_enemies)
	_events = MapEvents.new()
	add_child_autofree(_events)
	_events.champion_type = EnemyTypes.Id.GHOUL_CHAMPION
	_events.spawn_enemy = func(type_id: int, at: Vector2) -> Enemy: return _enemies.spawn(type_id, at)
	_player = PLAYER_SCENE.instantiate()
	_player.setup(1, 0, Vector2(800, 500), Rect2(0, 0, 1600, 1000))
	add_child_autofree(_player)


func _players() -> Array[Player]:
	var players: Array[Player] = [_player]
	return players


func _run(seconds: float, elapsed: float = 0.0) -> void:
	var no_peers: Array[int] = []
	for i: int in roundi(seconds / DELTA):
		_events.host_tick(DELTA, elapsed + i * DELTA, _players(), _enemies, false, no_peers)


func _first(kind: int) -> MapEvents.MapEvent:
	for event: MapEvents.MapEvent in _events.events():
		if event.kind == kind:
			return event
	return null


func _move_player(to: Vector2) -> void:
	_player.state.position = to
	_player.position = to


func test_a_stage_starts_with_a_lair_and_a_ritual_away_from_the_middle() -> void:
	for attempt: int in 20:
		_events.host_start_stage()
		assert_eq(_events.count(), 2)
		var lair := _first(MapEvents.Kind.CHAMPION)
		var ritual := _first(MapEvents.Kind.RITUAL)
		assert_not_null(lair)
		assert_not_null(ritual)
		var middle := _events.bounds.get_center()
		assert_gt(lair.position.distance_to(middle), 250.0, "lair away from the start")
		assert_gt(lair.position.distance_to(ritual.position), 150.0, "events spread out")
		assert_true(_events.bounds.grow(-MapEvents.EDGE_INSET + 1.0).has_point(lair.position), "inside the walls")


func test_champion_sleeps_until_someone_comes_close_then_leaves_a_chest() -> void:
	_events.host_start_stage()
	var lair := _first(MapEvents.Kind.CHAMPION)
	_move_player(lair.position + Vector2(MapEvents.WAKE_RADIUS + 40.0, 0))
	_run(0.5)
	assert_eq(_enemies.active_count(), 0, "still asleep")
	_move_player(lair.position + Vector2(MapEvents.WAKE_RADIUS - 10.0, 0))
	_run(DELTA)
	assert_eq(lair.state, MapEvents.State.ACTIVE)
	var champion := lair.enemy
	assert_not_null(champion)
	assert_eq(champion.type_id, EnemyTypes.Id.GHOUL_CHAMPION)
	assert_true(champion.type.is_elite)
	watch_signals(_events)
	_enemies.damage(champion, champion.hp, 1)
	assert_eq(_events.host_enemy_killed(champion), MapEvents.Kind.CHAMPION)
	assert_signal_emitted(_events, "champion_slain")
	var chest := _first(MapEvents.Kind.CHEST)
	assert_not_null(chest, "the champion leaves a chest")
	_move_player(chest.position)
	_run(DELTA)
	assert_signal_emitted_with_parameters(_events, "chest_opened", [1, chest.position])
	assert_null(_first(MapEvents.Kind.CHEST), "opened chests disappear")


func test_ritual_fills_while_someone_stands_in_it_and_drains_without() -> void:
	_events.host_start_stage()
	var ritual := _first(MapEvents.Kind.RITUAL)
	watch_signals(_events)
	_move_player(ritual.position)
	_run(MapEvents.RITUAL_SECONDS / 2.0)
	assert_almost_eq(ritual.progress, 0.5, 0.02)
	assert_signal_emitted(_events, "wave_requested", "a held ritual calls enemies")
	_move_player(ritual.position + Vector2(200, 0))
	_run(3.0)
	assert_lt(ritual.progress, 0.5, "drains with nobody inside")
	assert_gt(ritual.progress, 0.3, "but slowly")
	_move_player(ritual.position)
	_run(MapEvents.RITUAL_SECONDS)
	assert_signal_emitted(_events, "ritual_completed")
	var inside: Array = get_signal_parameters(_events, "ritual_completed")[1]
	assert_eq(inside, [1], "the player inside gets the heal")
	assert_null(_first(MapEvents.Kind.RITUAL), "a finished ritual is gone")


func test_popups_appear_on_schedule_and_unstarted_rituals_fade() -> void:
	_events.clear()
	_run(DELTA, MapEvents.POPUP_TIMES[0])
	assert_not_null(_first(MapEvents.Kind.RUNNER), "a Grave Robber at the first pop-up time")
	_run(DELTA, MapEvents.POPUP_TIMES[1])
	var ritual := _first(MapEvents.Kind.RITUAL)
	assert_not_null(ritual, "then a ritual")
	_move_player(Vector2(10, 10))
	ritual.position = Vector2(1500, 900)
	_run(MapEvents.POPUP_RITUAL_SECONDS + 0.5, MapEvents.POPUP_TIMES[1])
	assert_null(_first(MapEvents.Kind.RITUAL), "nobody started it: it faded")


func test_no_popups_once_the_boss_is_here() -> void:
	_events.clear()
	var no_peers: Array[int] = []
	_events.host_tick(DELTA, MapEvents.POPUP_TIMES[0], _players(), _enemies, true, no_peers)
	assert_eq(_events.count(), 0)


func test_grave_robber_drops_coins_and_escapes_in_time() -> void:
	_events.clear()
	watch_signals(_events)
	_run(DELTA, MapEvents.POPUP_TIMES[0])
	var runner := _first(MapEvents.Kind.RUNNER)
	var thief := runner.enemy
	assert_eq(thief.type_id, EnemyTypes.Id.GRAVE_ROBBER)
	_run(MapEvents.RUNNER_SECONDS + 0.1, MapEvents.POPUP_TIMES[0])
	assert_signal_emitted(_events, "coin_dropped")
	assert_signal_emitted(_events, "runner_escaped")
	assert_false(thief.active, "it got away")
	assert_eq(_events.count(), 0)


func test_catching_the_grave_robber() -> void:
	_events.clear()
	watch_signals(_events)
	_run(DELTA, MapEvents.POPUP_TIMES[0])
	var thief := _first(MapEvents.Kind.RUNNER).enemy
	_enemies.damage(thief, thief.hp, 1)
	assert_eq(_events.host_enemy_killed(thief), MapEvents.Kind.RUNNER)
	assert_signal_emitted(_events, "runner_caught")
	assert_eq(_events.count(), 0)


func test_unrelated_kills_are_ignored() -> void:
	_events.host_start_stage()
	var shambler := _enemies.spawn(EnemyTypes.Id.SHAMBLER, Vector2(100, 100))
	assert_eq(_events.host_enemy_killed(shambler), -1)
	assert_eq(_events.count(), 2)


func test_the_grave_robber_runs_away_and_slides_off_walls() -> void:
	var thief := _enemies.spawn(EnemyTypes.Id.GRAVE_ROBBER, Vector2(800, 500))
	var targets: Array[Vector2] = [Vector2(760, 500)]
	for i: int in 30:
		_enemies.tick_host(DELTA, targets)
	assert_gt(thief.position.x, 800.0, "away from the player")
	var cornered := _enemies._flee_direction(Vector2(30, 30), Vector2(30, 30) - Vector2(60, 60))
	assert_gt(cornered.x + cornered.y, 0.0, "in a corner it turns back toward the middle")


func test_thieves_do_no_contact_damage_and_champions_wear_crowns() -> void:
	assert_eq(EnemyTypes.get_type(EnemyTypes.Id.GRAVE_ROBBER).contact_damage, 0)
	for stage: StageDef in Stages.ALL:
		assert_true(EnemyTypes.get_type(stage.champion_type).is_elite, stage.title)
		assert_false(EnemyTypes.get_type(stage.champion_type).is_boss, "champions don't end the stage")


func test_markers_follow_events_for_arrows() -> void:
	_events.host_start_stage()
	var markers := _events.markers()
	assert_eq(markers.size(), 2)
	for marker: Array in markers:
		assert_true(PixelArt.has_sprite(marker[2]), "event icon exists")


func test_event_arrows_point_off_screen() -> void:
	var view := Rect2(0, 0, 640, 360)
	assert_eq(TeammateArrows.edge_point(view, Vector2(300, 200)), Vector2.INF, "on screen: no arrow")
	var tip := TeammateArrows.edge_point(view, Vector2(1500, 180))
	assert_almost_eq(tip.x, 640.0 - TeammateArrows.EDGE_MARGIN, 0.5, "off to the right: arrow at the right edge")
