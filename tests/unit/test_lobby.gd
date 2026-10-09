extends GutTest


func _lobby() -> LobbyState:
	var state := LobbyState.new()
	state.add(1, Characters.Id.WANDERER)
	state.add(20, Characters.Id.WANDERER)
	state.add(30, Characters.Id.WANDERER)
	return state


func test_host_can_start_alone() -> void:
	var state := LobbyState.new()
	state.add(1, 0)
	assert_true(state.can_start(1))


func test_start_waits_for_every_client_to_ready() -> void:
	var state := _lobby()
	assert_false(state.can_start(1))
	state.set_ready(20, true)
	assert_eq(state.not_ready(1), [30])
	state.set_ready(30, true)
	assert_true(state.can_start(1))


func test_leaving_player_no_longer_blocks_start() -> void:
	var state := _lobby()
	state.set_ready(20, true)
	state.remove(30)
	assert_true(state.can_start(1))


func test_choices_are_validated() -> void:
	var state := _lobby()
	assert_true(state.choose(20, Characters.Id.HEXBLADE_WITCH))
	assert_eq(state.characters[20], Characters.Id.HEXBLADE_WITCH)
	assert_false(state.choose(20, 99), "no such character")
	assert_false(state.choose(99, 0), "not in the lobby")


func test_join_order_is_kept() -> void:
	var state := _lobby()
	state.add(20, 2)
	assert_eq(state.order, [1, 20, 30], "re-adding doesn't duplicate or reorder")
