extends GutTest


func test_effects_burst_lives_and_fades_out() -> void:
	var effects := EffectsLayer.new()
	add_child_autofree(effects)
	effects.burst(Vector2(10, 10), Color.WHITE, 12, 50.0, 0.3)
	assert_eq(effects.count(), 12)
	effects._process(0.5)
	assert_eq(effects.count(), 0)


func test_effects_pool_is_capped() -> void:
	var effects := EffectsLayer.new()
	add_child_autofree(effects)
	effects.burst(Vector2.ZERO, Color.WHITE, EffectsLayer.CAPACITY + 50, 10.0, 1.0)
	assert_eq(effects.count(), EffectsLayer.CAPACITY)


func test_enemy_death_is_announced_for_effects() -> void:
	var enemies := EnemyManager.new()
	add_child_autofree(enemies)
	var enemy := enemies.spawn(EnemyTypes.Id.BAT, Vector2(40, 40))
	watch_signals(enemies)
	enemies.damage(enemy, 999, 1)
	assert_signal_emitted(enemies, "enemy_vanished")


func test_pause_and_restart_bindings_do_not_clash() -> void:
	var start_on_pause := false
	for event: InputEvent in InputMap.action_get_events(&"pause"):
		var joy := event as InputEventJoypadButton
		if joy != null and joy.button_index == JOY_BUTTON_START:
			start_on_pause = true
	assert_true(start_on_pause, "gamepad Start opens the menu")
	for event: InputEvent in InputMap.action_get_events(&"restart"):
		var joy := event as InputEventJoypadButton
		assert_true(joy == null or joy.button_index != JOY_BUTTON_START)


func test_blocked_input_stands_still_and_holds_fire() -> void:
	var player: Player = preload("res://src/player/player.tscn").instantiate()
	player.setup(1, 0, Vector2(100, 100), Rect2(0, 0, 500, 500))
	add_child_autofree(player)
	var reader := LocalInput.new()
	add_child_autofree(reader)
	LocalInput.blocked = true
	var input := reader.sample(player, 1.0 / 60.0)
	LocalInput.blocked = false
	assert_eq(input.move, Vector2.ZERO)
	assert_false(input.fire)


func test_settings_round_trip() -> void:
	var before_shake := Settings.screen_shake
	Settings.screen_shake = not before_shake
	Settings.save()
	Settings.screen_shake = before_shake
	Settings.load_settings()
	assert_eq(Settings.screen_shake, not before_shake)
	Settings.screen_shake = before_shake
	Settings.save()


func test_every_sound_is_synthesized() -> void:
	for sound: StringName in [&"shoot", &"hit", &"death", &"hurt", &"gem", &"coin", &"level_up", &"pickup",
			&"bomb", &"boss", &"dash", &"enemy_shot", &"victory", &"defeat"]:
		assert_true(Sfx.has_sound(sound), str(sound))


func test_sfx_bus_exists_for_the_volume_setting() -> void:
	assert_gt(AudioServer.get_bus_index(&"SFX"), 0)


func test_unknown_sound_is_ignored() -> void:
	Sfx.play(&"no_such_sound")
	assert_true(true, "no crash")


func test_settings_panel_changes_apply_immediately() -> void:
	var panel: SettingsPanel = preload("res://src/ui/settings_panel.tscn").instantiate()
	add_child_autofree(panel)
	var before := Settings.sfx_volume
	panel.open()
	(panel.get_node("%SfxSlider") as HSlider).value = 0.25
	assert_eq(Settings.sfx_volume, 0.25)
	assert_almost_eq(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"SFX")), linear_to_db(0.25), 0.01)
	Settings.sfx_volume = before
	Settings.apply()
	Settings.save()
