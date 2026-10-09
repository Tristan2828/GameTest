extends GutTest
## The custom game's Soundtrack option and the metal tracks.


func test_every_stage_and_boss_track_has_a_metal_version() -> void:
	for stage: StageDef in Stages.ALL:
		assert_true(Tracks.ALL.has(StringName("metal_" + stage.music)), "metal %s" % stage.music)
	assert_true(Tracks.ALL.has(&"metal_boss"))


func test_soundtrack_picks_the_right_track() -> void:
	assert_eq(Tracks.for_soundtrack(&"crypt", 0), &"crypt", "classic")
	assert_eq(Tracks.for_soundtrack(&"crypt", 1), &"metal_crypt", "metal")
	assert_eq(Tracks.for_soundtrack(&"boss", 1), &"metal_boss")
	assert_eq(Tracks.for_soundtrack(&"crypt", 2), &"crypt", "metal boss fights only")
	assert_eq(Tracks.for_soundtrack(&"boss", 2), &"metal_boss")
	assert_eq(Tracks.for_soundtrack(&"menu", 1), &"menu", "no metal menu: stays classic")
	assert_ne(Tracks.for_soundtrack(&"crypt", 3, 1), Tracks.for_soundtrack(&"crypt", 3, 2), "shuffle alternates")


func test_metal_track_renders_a_loop_without_clipping() -> void:
	var buffer := MusicComposer.render(Tracks.METAL_BOSS)
	var bars: int = Tracks.METAL_BOSS["chords"].size()
	var step_samples := int(60.0 / float(Tracks.METAL_BOSS["bpm"]) / 4.0 * Synth.MIX_RATE)
	assert_eq(buffer.size(), bars * MusicComposer.STEPS_PER_BAR * step_samples)
	var peak := 0.0
	for value: float in buffer:
		peak = maxf(peak, absf(value))
	assert_almost_eq(peak, MusicComposer.TARGET_PEAK, 0.01)


func test_metal_scores_are_well_formed() -> void:
	for track: StringName in [&"metal_crypt", &"metal_marsh", &"metal_cathedral", &"metal_boss"]:
		var score: Dictionary = Tracks.ALL[track]
		assert_eq(score["lead"].size(), score["chords"].size(), "%s lead bars" % track)
		var riffs: Array = score["guitar"] if score["guitar"] is Array else [score["guitar"]]
		for riff: String in riffs:
			assert_eq(riff.length(), MusicComposer.STEPS_PER_BAR, "%s riff '%s'" % [track, riff])
		for line: String in score["lead"]:
			assert_eq(line.length(), MusicComposer.STEPS_PER_BAR, "%s lead '%s'" % [track, line])


func test_soundtrack_setting_is_clamped_and_sent() -> void:
	var config := RunConfig.new()
	config.set_value("soundtrack", 99)
	assert_eq(config.soundtrack, Tracks.SOUNDTRACKS.size() - 1)
	assert_eq(RunConfig.from_dict(config.to_dict()).soundtrack, config.soundtrack)
