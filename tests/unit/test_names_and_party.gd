extends GutTest
## Display names (title menu -> everyone), the lobby's party page and hero
## picker, and the run summary's Highlights page.

const LOBBY_SCENE: PackedScene = preload("res://src/lobby/lobby.tscn")

var _saved_name: String = ""


func before_each() -> void:
	_saved_name = Settings.player_name


func after_each() -> void:
	Settings.player_name = _saved_name


func test_names_are_trimmed_capped_and_drawable() -> void:
	assert_eq(PlayerNames.sanitize("  Tristan  "), "Tristan")
	assert_eq(PlayerNames.sanitize("A   B"), "A B", "runs of spaces collapse")
	assert_eq(PlayerNames.sanitize("Zoë★"), "Zo", "characters the pixel font can't draw are dropped")
	assert_eq(PlayerNames.sanitize("abcdefghijklmnopqrstuvwxyz").length(), PlayerNames.MAX_LENGTH)
	assert_eq(PlayerNames.sanitize("   "), "")


func test_players_without_a_name_go_by_their_color() -> void:
	assert_eq(PlayerNames.display("", 1), "Red")
	assert_eq(PlayerNames.display("Mo", 1), "Mo")


func test_solo_uses_the_title_menu_name() -> void:
	Settings.player_name = "  Ash "
	Net.start_solo()
	assert_eq(Net.name_of(1, 0), "Ash")
	assert_eq(Net.name_of(999, 2), "Green", "unknown peers go by their slot color")
	Settings.player_name = ""
	Net.start_solo()
	assert_eq(Net.name_of(1, 0), "Blue")


func test_party_shows_one_card_per_player_and_opens_the_picker() -> void:
	Settings.player_name = "Ash"
	Net.start_solo()
	var lobby: Lobby = LOBBY_SCENE.instantiate()
	add_child_autofree(lobby)
	await wait_process_frames(2)
	assert_eq(lobby._party.get_child_count(), 1, "solo: just you")
	assert_not_null(lobby._my_card)
	var labels: Array = lobby._my_card.find_children("*", "Label", true, false)
	assert_true(labels.any(func(label: Label) -> bool: return label.text == "Ash"), "your name is on your card")
	lobby._my_card.pressed.emit()
	assert_true(lobby._picker.visible, "your card opens the hero picker")
	assert_false(lobby._center.visible)
	lobby._cards[Characters.Id.NECROMANCER].pressed.emit()
	assert_false(lobby._picker.visible, "picking a hero goes back to the party")
	assert_eq(lobby._state.characters[1], Characters.Id.NECROMANCER)
	await wait_process_frames(1)
	var portraits: Array = lobby._party.find_children("*", "CharacterPortrait", true, false)
	assert_eq((portraits[0] as CharacterPortrait).character_id, Characters.Id.NECROMANCER)


func test_party_grows_with_the_lobby() -> void:
	Net.start_solo()
	var lobby: Lobby = LOBBY_SCENE.instantiate()
	add_child_autofree(lobby)
	await wait_process_frames(1)
	lobby._state.add(20, Characters.Id.GRAVEKEEPER)
	lobby._state.add(30, Characters.Id.HEXBLADE_WITCH)
	await wait_process_frames(2)
	assert_eq(lobby._party.get_child_count(), 3, "you and two teammates")


func test_highlights_name_the_mvp_and_deadliest_weapon() -> void:
	var stats := RunStats.new()
	stats.add(1, RunStats.Stat.KILLS, 50)
	stats.add(1, RunStats.Stat.DAMAGE, 4000)
	stats.add(2, RunStats.Stat.KILLS, 10)
	stats.add(2, RunStats.Stat.DAMAGE, 900)
	stats.set_source(2, DamageSource.MAIN_GUN, 900, 10, 60)
	stats.set_source(1, DamageSource.MAIN_GUN, 3000, 40, 60)
	stats.run_seconds = 120.0
	var players: Array[Player] = []
	var lines := RunSummaryPanel.highlights(stats, players, 1.0)
	var titles: Array = lines.map(func(line: Array) -> String: return line[1])
	assert_has(titles, "MVP")
	assert_has(titles, "Deadliest weapon")
	assert_has(titles, "Kill rate")
	var rate: Array = lines.filter(func(line: Array) -> bool: return line[1] == "Kill rate")[0]
	assert_string_contains(rate[2], "30 kills a minute")
	for line: Array in lines:
		assert_true(PixelArt.has_sprite(line[0]), "icon %s exists" % line[0])


func test_solo_highlights_show_your_score_not_an_mvp() -> void:
	var stats := RunStats.new()
	stats.add(1, RunStats.Stat.KILLS, 5)
	var players: Array[Player] = []
	var titles: Array = RunSummaryPanel.highlights(stats, players, 1.0).map(func(line: Array) -> String: return line[1])
	assert_does_not_have(titles, "MVP")
	assert_has(titles, "Score")
