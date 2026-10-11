extends GutTest
## The owner's seventh list (after a 4-player run, v0.24.0): the boss's own
## horde, faster rituals together, knives, the "you" marker, changing a pick,
## the left trigger, big card icons, the run summary's difficulty, stages and
## width, the difficulty page and the Join dialog.

const ARENA_SCENE: PackedScene = preload("res://src/arena/arena.tscn")
const PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")
const HUD_SCENE: PackedScene = preload("res://src/ui/hud.tscn")
const DELTA: float = 1.0 / 60.0


# --- Boss fights -----------------------------------------------------------------

func test_the_boss_sweeps_the_old_horde_and_brings_its_own() -> void:
	Net.start_solo()
	var arena: Arena = ARENA_SCENE.instantiate()
	add_child_autofree(arena)
	await wait_process_frames(1)
	var old: Array[Enemy] = []
	for i: int in 20:
		old.append(arena._enemies.spawn(EnemyTypes.Id.SHAMBLER, Vector2(300 + i * 10, 300), 10))
	var before := arena._enemies.active_count()
	assert_gte(before, 20)
	arena._spawn_boss()
	# (Pool slots get reused, so count rather than check the old enemies.)
	assert_not_null(arena._enemies.find_boss())
	assert_eq(arena._enemies.active_count(), 1 + Arena.BOSS_ESCORT, "only the boss and its escort (solo)")


func test_fewer_enemies_during_a_boss_fight() -> void:
	assert_eq(Arena.boss_fight_max_alive(1), Arena.BOSS_FIGHT_MAX_ALIVE + Arena.BOSS_FIGHT_MAX_ALIVE_PER_PLAYER)
	assert_lt(Arena.boss_fight_max_alive(4), SpawnDirector.MAX_ALIVE, "well under the normal cap with 4 players")
	assert_lt(Arena.BOSS_FIGHT_SPAWN_RATE, 0.4, "down from v0.23's 40%")
	var director := SpawnDirector.new(1)
	assert_eq(director.tick(10.0, 200.0, 4, 50, 1.0, 50).size(), 0, "nothing spawns at the cap")
	assert_gt(director.tick(10.0, 200.0, 4, 10, 1.0, 50).size(), 0)
	assert_lte(director.tick(10.0, 200.0, 4, 45, 1.0, 50).size(), 5, "only up to the cap")


func test_sweeping_keeps_bosses_and_event_enemies() -> void:
	var enemies := EnemyManager.new()
	add_child_autofree(enemies)
	var boss := enemies.spawn(EnemyTypes.Id.BONE_WARDEN, Vector2(100, 100), 500)
	var champion := enemies.spawn(EnemyTypes.Id.GHOUL_CHAMPION, Vector2(200, 100), 500)
	for i: int in 5:
		enemies.spawn(EnemyTypes.Id.SHAMBLER, Vector2(300, 100 + i * 20), 10)
	var removed := enemies.clear_regulars(func(enemy: Enemy) -> bool: return enemy == champion)
	assert_eq(removed, 5)
	assert_true(boss.active)
	assert_true(champion.active)
	assert_eq(enemies.active_count(), 2)


# --- Rituals -------------------------------------------------------------------------

func test_rituals_fill_faster_with_more_players_inside() -> void:
	assert_eq(MapEvents.ritual_fill_speed(1), 1.0)
	assert_eq(MapEvents.ritual_fill_speed(2), 1.5)
	assert_eq(MapEvents.ritual_fill_speed(4), 2.5)
	assert_eq(MapEvents.ritual_fill_speed(0), 1.0)
	var enemies := EnemyManager.new()
	add_child_autofree(enemies)
	var events := MapEvents.new()
	add_child_autofree(events)
	var players: Array[Player] = []
	for i: int in 2:
		var player: Player = PLAYER_SCENE.instantiate()
		player.setup(i + 1, i, Vector2(800, 500), Rect2(0, 0, 1600, 1000))
		add_child_autofree(player)
		players.append(player)
	var ritual := events._add(MapEvents.Kind.RITUAL, Vector2(800, 500))
	var no_peers: Array[int] = []
	var seconds := MapEvents.RITUAL_SECONDS / 1.5 - 0.5
	for i: int in roundi(seconds / DELTA):
		events.host_tick(DELTA, 30.0, players, enemies, false, no_peers)
	assert_almost_eq(ritual.progress, seconds / MapEvents.RITUAL_SECONDS * 1.5, 0.02, "two players fill it 1.5x as fast")


# --- Spirit Daggers -----------------------------------------------------------------

func test_daggers_fly_as_knives() -> void:
	var daggers := AutoWeapons.get_weapon(AutoWeapons.Id.SPIRIT_DAGGERS)
	assert_eq(daggers.sprite, "dagger")
	assert_true(PixelArt.has_sprite("dagger"))
	assert_true(PixelArt.has_sprite("dagger_diag"))
	Net.start_solo()
	var arena: Arena = ARENA_SCENE.instantiate()
	add_child_autofree(arena)
	await wait_process_frames(1)
	assert_eq(arena._projectiles.sprite_sources.get(DamageSource.of_weapon(AutoWeapons.Id.SPIRIT_DAGGERS), ""), "dagger")
	assert_false(arena._projectiles.sprite_sources.has(DamageSource.MAIN_GUN), "bolts stay glowing dots")


# --- "You are here" ------------------------------------------------------------------

func test_your_hero_is_marked_only_during_the_countdown() -> void:
	Net.start_solo()
	var arena: Arena = ARENA_SCENE.instantiate()
	add_child_autofree(arena)
	await wait_process_frames(1)
	var me := arena._player_by_id(1)
	arena._phase = Arena.Phase.COUNTDOWN
	arena._update_hud()
	assert_true(me.show_here_marker)
	arena._phase = Arena.Phase.PLAYING
	arena._update_hud()
	assert_false(me.show_here_marker, "gone as soon as play resumes")


# --- Level-up cards ------------------------------------------------------------------

func test_the_left_trigger_picks_cards() -> void:
	var found := false
	for event: InputEvent in InputMap.action_get_events(&"pick_card"):
		var motion := event as InputEventJoypadMotion
		found = found or (motion != null and motion.axis == JOY_AXIS_TRIGGER_LEFT)
	assert_true(found)
	var hud: Hud = HUD_SCENE.instantiate()
	add_child_autofree(hud)
	var panel := hud.level_up_panel
	watch_signals(panel)
	var choices: Array[int] = [0, 4, 6]
	panel.open(3, choices)
	await wait_process_frames(1)
	Input.action_press(&"pick_card")
	await wait_process_frames(1)
	Input.action_release(&"pick_card")
	assert_signal_emitted_with_parameters(panel, "picked", [0])


func test_another_card_can_be_picked_while_waiting() -> void:
	var hud: Hud = HUD_SCENE.instantiate()
	add_child_autofree(hud)
	var panel := hud.level_up_panel
	var choices: Array[int] = [0, 4, 6]
	panel.open(3, choices)
	panel.mark_picked(0)
	watch_signals(panel)
	panel._on_card_pressed(0)
	assert_signal_not_emitted(panel, "picked", "the same card again does nothing")
	panel._on_card_pressed(2)
	assert_signal_emitted_with_parameters(panel, "picked", [6])
	assert_false((panel._cards.get_child(2) as Button).disabled, "the other cards stay pickable")


func test_cards_grow_to_fit_their_text() -> void:
	var hud: Hud = HUD_SCENE.instantiate()
	add_child_autofree(hud)
	var panel := hud.level_up_panel
	# Weapons with long descriptions and previews.
	var choices: Array[int] = [Cards.weapon(AutoWeapons.Id.REAPERS_SCYTHE), Cards.weapon(AutoWeapons.Id.BONE_SPEARS),
		Cards.weapon(AutoWeapons.Id.HEX_SNARE)]
	panel.open(3, choices)
	await wait_process_frames(4)
	var heights: Array[float] = []
	for i: int in 3:
		var card := panel._cards.get_child(i) as Button
		var lines := card.get_node("Lines") as Control
		assert_lte(lines.get_combined_minimum_size().y + LevelUpPanel.CARD_PADDING, card.size.y + 0.5, "text fits card %d" % i)
		assert_lte(lines.get_combined_minimum_size().x, card.size.x, "no wider than card %d" % i)
		heights.append(card.size.y)
	assert_eq(heights[0], heights[1], "all cards match")
	assert_eq(heights[1], heights[2])


func test_every_card_has_a_big_icon() -> void:
	var icons: Array[String] = []
	for id: int in AutoWeapons.PICKUPS + AutoWeapons.EVOLUTIONS:
		icons.append(AutoWeapons.get_weapon(id).icon)
	for upgrade: Upgrade in Upgrades.ALL:
		if upgrade.passive:
			icons.append(upgrade.icon)
	icons.append(Upgrades.get_upgrade(Cards.HEAL_FILLER).icon)
	icons.append(Upgrades.get_upgrade(Cards.COIN_FILLER).icon)
	for stats: CharacterStats in Characters.ALL:
		icons.append(stats.main_weapon_icon)
		icons.append(stats.evolved_weapon_icon)
	for icon: String in icons:
		var big := PixelArt.big_icon(icon)
		assert_eq(big, icon + "_lg", "%s has a big version" % icon)
		assert_eq(PixelArt.size_of(big), Vector2i(16, 16), "%s is 16x16" % big)
	assert_eq(PixelArt.big_icon("crown"), "crown", "falls back to the small icon")


# --- Run summary ----------------------------------------------------------------------

func test_run_config_describes_its_difficulty() -> void:
	var config := RunConfig.new()
	assert_eq(config.difficulty_details(), "", "Normal: nothing differs")
	assert_string_contains(config.difficulty_details(true), "Enemy HP 100%")
	assert_string_contains(config.difficulty_details(true), "Bonus HP 0")
	config.set_value("enemy_health", 1.5)
	config.set_value("hp_bonus", -20)
	assert_eq(config.difficulty_name(), "Custom")
	assert_eq(config.difficulty_details(), "Enemy HP 150%, Bonus HP -20")
	assert_string_contains(config.summary(), "Custom (Enemy HP 150%, Bonus HP -20)")
	assert_eq(config.custom_details(), "", "a full run with default options")
	config.single_stage = true
	config.bonus_levels = 3
	assert_eq(config.custom_details(), "Single stage: %s, +3 levels" % Stages.get_stage(1).title)


func test_stage_rows_survive_the_network() -> void:
	var stats := RunStats.new()
	stats.add(1, RunStats.Stat.POWER_UPS, 2)
	stats.add_stage_row({RunStats.StageField.MAP: 1, RunStats.StageField.SECONDS: 300, RunStats.StageField.BOSS_SECONDS: 60,
		RunStats.StageField.KILLS: 900, RunStats.StageField.CLEARED: 1})
	stats.add_stage_row({RunStats.StageField.MAP: 2, RunStats.StageField.SECONDS: 120, RunStats.StageField.BOSS_SECONDS: -1})
	var copy := RunStats.decode(stats.encode())
	assert_eq(copy.stage_rows.size(), 2)
	assert_eq(copy.stage_rows[0][RunStats.StageField.KILLS], 900)
	assert_eq(copy.stage_rows[1][RunStats.StageField.BOSS_SECONDS], -1)
	assert_eq(copy.get_stat(1, RunStats.Stat.POWER_UPS), 2)


func test_a_lost_stage_is_recorded_for_the_summary() -> void:
	Net.start_solo()
	var arena: Arena = ARENA_SCENE.instantiate()
	add_child_autofree(arena)
	await wait_process_frames(1)
	arena._elapsed = 42.0
	arena._player_by_id(1).take_bullet(9999)
	arena._update_phase()
	var rows := arena._final_stats.stage_rows
	assert_eq(rows.size(), 1)
	assert_eq(rows[0][RunStats.StageField.SECONDS], 42)
	assert_eq(rows[0][RunStats.StageField.CLEARED], 0)
	assert_eq(rows[0][RunStats.StageField.BOSS_SECONDS], -1, "the boss never came")


func test_four_player_cards_fit_the_screen() -> void:
	var stats := RunStats.new()
	var players: Array[Player] = []
	for i: int in 4:
		var player: Player = PLAYER_SCENE.instantiate()
		player.setup(i + 1, i, Vector2(100, 100), Rect2(0, 0, 1600, 1000), Characters.Id.GRAVEKEEPER)
		add_child_autofree(player)
		players.append(player)
		stats.add(i + 1, RunStats.Stat.KILLS, 12345)
		stats.add(i + 1, RunStats.Stat.DAMAGE, 1234567)
	stats.add_stage_row({RunStats.StageField.MAP: 1, RunStats.StageField.SECONDS: 300})
	var panel := RunSummaryPanel.new()
	add_child_autofree(panel)
	panel.local_embers = 123  # The line that used to push the 4th card off the screen.
	panel.local_record_rank = 0
	panel.open(stats, players, "The Crypt", 3, "Waiting for the host...", true)
	await wait_process_frames(2)
	for page: int in RunSummaryPanel.PAGES.size():
		panel._show_page(page)
		await wait_process_frames(2)
		assert_lte(panel._frame.get_combined_minimum_size().x, 640.0, "page %s fits 640 px" % RunSummaryPanel.PAGES[page])


# --- Lobby and title menu -------------------------------------------------------------

func test_difficulty_page_lights_the_current_preset() -> void:
	var screen := DifficultyScreen.new()
	add_child_autofree(screen)
	screen.config.apply_preset("Hard")
	screen.open()
	await wait_process_frames(1)
	assert_true(screen._preset_buttons["Hard"].button_pressed)
	assert_false(screen._preset_buttons["Easy"].button_pressed)
	assert_true(screen._preset_buttons["Hard"].has_focus(), "focus starts on the current preset, not Easy")
	assert_false(screen._custom_chip.button_pressed)
	screen.config.set_value("xp_rate", 2.0)
	screen._changed()
	assert_true(screen._custom_chip.button_pressed, "Custom lights up")
	assert_false(screen._preset_buttons["Hard"].button_pressed)


func test_the_join_dialog_recognises_invites() -> void:
	assert_true(JoinDialog._looks_like_invite("203.0.113.5:7777"))
	assert_true(JoinDialog._looks_like_invite(" 203.0.113.5 "))
	assert_true(JoinDialog._looks_like_invite("my-host.example.net:7000"))
	assert_false(JoinDialog._looks_like_invite("hello there"))
	assert_false(JoinDialog._looks_like_invite("7777"))
	assert_false(JoinDialog._looks_like_invite(""))


func test_join_dialog_only_joins_with_an_address() -> void:
	var dialog := JoinDialog.new()
	add_child_autofree(dialog)
	watch_signals(dialog)
	dialog._address_edit.text = "   "
	dialog._try_join()
	assert_signal_not_emitted(dialog, "join_requested")
	dialog._address_edit.text = "203.0.113.5:7001"
	dialog._try_join()
	assert_signal_emitted_with_parameters(dialog, "join_requested", ["203.0.113.5", 7001])


func test_party_cards_show_weapon_and_perk_name_not_its_text() -> void:
	var lobby: Node = (load("res://src/lobby/lobby.tscn") as PackedScene).instantiate()
	Net.start_solo()
	add_child_autofree(lobby)
	await wait_process_frames(2)
	var hero := Characters.get_character((lobby.get("_state") as LobbyState).characters[1])
	var texts: Array[String] = []
	for label: Node in (lobby.get("_party") as Node).find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	assert_has(texts, hero.main_weapon_name)
	assert_has(texts, "Perk: %s" % hero.perk_name)
	for text: String in texts:
		assert_false(text.contains(hero.perk_description), "no perk description on party cards")
