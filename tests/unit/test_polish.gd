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
			&"bomb", &"boss", &"dash", &"enemy_shot", &"victory", &"defeat", &"countdown", &"countdown_go",
			&"ability_ready"]:
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


func test_minimap_accepts_state_and_warns_near_walls() -> void:
	var minimap := Minimap.new()
	minimap.size = Vector2(100, 62)
	add_child_autofree(minimap)
	var markers: Array[Array] = [[Vector2(20, 500), Color.BLUE, true]]
	minimap.show_state(Rect2(0, 320, 640, 360), markers, PackedVector2Array([Vector2(800, 500)]),
		PackedVector2Array(), Vector2.INF, Vector2(20, 500))
	assert_eq(minimap.players.size(), 1)
	assert_lt(minimap.local_position.x, Minimap.EDGE_WARNING_DISTANCE, "left wall warning would show")


func test_teammate_arrow_only_for_offscreen_players() -> void:
	var view := Rect2(0, 0, 640, 360)
	assert_eq(TeammateArrows.edge_point(view, Vector2(300, 200)), Vector2.INF, "on screen: no arrow")
	var right := TeammateArrows.edge_point(view, Vector2(2000, 180))
	assert_almost_eq(right.x, 640.0 - TeammateArrows.EDGE_MARGIN, 0.01, "pinned to the right edge")
	assert_almost_eq(right.y, 180.0, 0.01)
	var up_left := TeammateArrows.edge_point(view, Vector2(-1000, -1000))
	assert_true(Rect2(Vector2.ZERO, view.size).has_point(up_left), "stays on screen")
	assert_lt(up_left.x, 320.0)
	assert_lt(up_left.y, 180.0)


func test_level_pips_count_owned_next_and_empty() -> void:
	var pips := LevelPips.new()
	add_child_autofree(pips)
	pips.owned = 2
	pips.maximum = 5
	assert_eq(pips.pip_count(), 5)
	pips.maximum = 0
	assert_eq(pips.pip_count(), 3, "no limit: owned plus the new one")
	pips.owned = 30
	assert_eq(pips.pip_count(), LevelPips.MAX_DRAWN)


func test_weapon_icons_exist_and_size_the_row() -> void:
	for weapon: AutoWeapon in AutoWeapons.ALL:
		assert_true(PixelArt.has_sprite(weapon.icon), weapon.title)
	var icons := WeaponIcons.new()
	add_child_autofree(icons)
	var levels: Dictionary[int, int] = {0: 1, 2: 3}
	icons.set_weapons(levels)
	assert_gt(icons.custom_minimum_size.x, 18.0, "two icons wide")


func test_lobby_portrait_redraws_with_new_color_and_pickers() -> void:
	var portrait := CharacterPortrait.new()
	add_child_autofree(portrait)
	portrait.color = Player.SLOT_COLORS[1]
	assert_eq(portrait.color, Player.SLOT_COLORS[1])
	var pickers: Array[Color] = [Player.SLOT_COLORS[0], Player.SLOT_COLORS[1]]
	portrait.pickers = pickers
	assert_eq(portrait.pickers.size(), 2)
