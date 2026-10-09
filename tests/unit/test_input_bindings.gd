extends GutTest
## Every menu must be usable with a gamepad alone.


func _has_joy_button(action: StringName, button: JoyButton) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var joy := event as InputEventJoypadButton
		if joy != null and joy.button_index == button:
			return true
	return false


func test_gamepad_a_confirms_menu_buttons() -> void:
	assert_true(_has_joy_button(&"ui_accept", JOY_BUTTON_A))


func test_gamepad_dpad_moves_between_menu_buttons() -> void:
	assert_true(_has_joy_button(&"ui_left", JOY_BUTTON_DPAD_LEFT))
	assert_true(_has_joy_button(&"ui_right", JOY_BUTTON_DPAD_RIGHT))


func test_pressing_a_on_a_focused_card_picks_it() -> void:
	var hud: Hud = (load("res://src/ui/hud.tscn") as PackedScene).instantiate()
	add_child_autofree(hud)
	var panel := hud.level_up_panel
	watch_signals(panel)
	var choices: Array[int] = [0, 4, 6]
	panel.open(3, choices)
	await wait_process_frames(1)
	var press := InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_A
	press.pressed = true
	get_viewport().push_input(press)
	var release := InputEventJoypadButton.new()
	release.button_index = JOY_BUTTON_A
	release.pressed = false
	get_viewport().push_input(release)
	await wait_process_frames(1)
	assert_signal_emitted_with_parameters(panel, "picked", [0])
