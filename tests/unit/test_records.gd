extends GutTest
## Records (best runs per hero, saved on this PC) and their score.

const TEST_PATH: String = "user://test_records.cfg"


func before_each() -> void:
	RunRecords.path = TEST_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func after_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	RunRecords.path = RunRecords.PATH


func _entry(character: int, score: int) -> RunRecords.Entry:
	var entry := RunRecords.Entry.new()
	entry.character = character
	entry.score = score
	entry.map_title = "The Crypt"
	return entry


func test_score_rewards_kills_damage_bosses_and_victory() -> void:
	assert_eq(RunRecords.score_for(100, 5000, 1, false, 1.0), 1000 + 500 + 3000)
	assert_eq(RunRecords.score_for(100, 5000, 3, true, 1.0), 1000 + 500 + 9000 + 5000)
	assert_eq(RunRecords.score_for(100, 0, 0, false, 1.5), 1500, "harder difficulty scores more")


func test_harder_settings_raise_the_multiplier() -> void:
	var normal := RunConfig.new()
	assert_almost_eq(normal.score_multiplier(), 1.0, 0.001)
	var hard := RunConfig.new()
	hard.apply_preset("Hard")
	var easy := RunConfig.new()
	easy.apply_preset("Easy")
	assert_gt(hard.score_multiplier(), 1.0)
	assert_lt(easy.score_multiplier(), 1.0)


func test_runs_are_ranked_per_hero_and_saved() -> void:
	assert_eq(RunRecords.add(_entry(0, 500)), 0, "first run is the best")
	assert_eq(RunRecords.add(_entry(0, 900)), 0, "a higher score is the new best")
	assert_eq(RunRecords.add(_entry(0, 700)), 1)
	assert_eq(RunRecords.add(_entry(1, 100)), 0, "other heroes have their own list")
	var all := RunRecords.load_all()
	assert_eq(all.size(), 4)
	assert_eq(all[0].score, 900)
	assert_eq(RunRecords.for_character(all, 1).size(), 1)


func test_only_the_best_few_per_hero_are_kept() -> void:
	for i: int in RunRecords.KEEP_PER_CHARACTER:
		RunRecords.add(_entry(2, 1000 + i))
	assert_eq(RunRecords.add(_entry(2, 1)), -1, "too low to make the list")
	assert_eq(RunRecords.for_character(RunRecords.load_all(), 2).size(), RunRecords.KEEP_PER_CHARACTER)


func test_entry_round_trips_through_the_file_format() -> void:
	var entry := _entry(3, 4321)
	entry.victory = true
	entry.stage = 3
	entry.kills = 812
	entry.seconds = 901.5
	entry.difficulty = "Hard"
	var copy := RunRecords.Entry.from_dict(entry.to_dict())
	assert_eq(copy.to_dict(), entry.to_dict())
	assert_eq(copy.result_text(), "Victory")


func test_records_screen_lists_saved_runs() -> void:
	RunRecords.add(_entry(0, 1234))
	var screen := RecordsScreen.new()
	add_child_autofree(screen)
	screen.open()
	await wait_process_frames(1)
	assert_eq(screen.list.get_child_count(), 2, "a heading and one run")
