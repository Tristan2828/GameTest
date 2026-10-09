extends GutTest


func test_voice_has_the_requested_length_and_stays_in_range() -> void:
	var samples := Synth.voice(Synth.Wave.SQUARE, 440.0, 220.0, 0.1, 0.5, 0.002, 2.0, 0.5)
	assert_eq(samples.size(), int(0.1 * Synth.MIX_RATE))
	for value: float in samples:
		assert_true(absf(value) <= 0.5001)


func test_echo_extends_the_sound() -> void:
	var dry := Synth.voice(Synth.Wave.SINE, 440.0, 440.0, 0.1, 0.5)
	var wet := Synth.echo(dry, 0.05, 0.5, 2)
	assert_gt(wet.size(), dry.size())


func test_looping_stream_is_marked_to_loop() -> void:
	var stream := Synth.to_stream(PackedFloat32Array([0.0, 0.5, -0.5]), true)
	assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_eq(stream.loop_end, 3)


func test_every_score_is_well_formed() -> void:
	for track: StringName in Tracks.ALL:
		var score: Dictionary = Tracks.ALL[track]
		var bars: int = score["chords"].size()
		assert_eq(score["lead"].size(), bars, "%s: one melody line per bar" % track)
		for line: String in score["lead"]:
			assert_eq(line.length(), MusicComposer.STEPS_PER_BAR, "%s melody line" % track)
		for key: String in ["bass", "arp", "kick", "snare", "hat"]:
			var pattern: String = score[key]
			assert_true(pattern.is_empty() or pattern.length() == MusicComposer.STEPS_PER_BAR, "%s %s" % [track, key])
		assert_true(Synth.Wave.has(score["lead_wave"]) and Synth.Wave.has(score["arp_wave"]), "%s waves" % track)


func test_rendered_music_has_exact_loop_length_and_safe_level() -> void:
	var score: Dictionary = Tracks.BOSS
	var samples := MusicComposer.render(score)
	var step_samples := int(60.0 / float(score["bpm"]) / 4.0 * Synth.MIX_RATE)
	assert_eq(samples.size(), score["chords"].size() * MusicComposer.STEPS_PER_BAR * step_samples)
	var peak := 0.0
	for value: float in samples:
		peak = maxf(peak, absf(value))
	assert_almost_eq(peak, MusicComposer.TARGET_PEAK, 0.001)


func test_music_is_deterministic() -> void:
	assert_eq(MusicComposer.render(Tracks.BOSS), MusicComposer.render(Tracks.BOSS))


func test_chords_follow_the_scale() -> void:
	# A minor, chord on degree 0: A C E.
	assert_eq(MusicComposer.chord_notes(45, Tracks.MINOR, 0), [57, 60, 64])
	assert_eq(MusicComposer.scale_note(Tracks.MINOR, 7), 12, "step 7 = an octave up")


func test_every_stage_names_a_real_track() -> void:
	for stage: StageDef in Stages.ALL:
		assert_true(Tracks.ALL.has(stage.music), stage.title)


func test_music_volume_has_its_own_bus() -> void:
	assert_gt(AudioServer.get_bus_index(&"Music"), 0)
	Music.play(&"menu")
	assert_true(true, "asking for music in a headless run is harmless")
