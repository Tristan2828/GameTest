extends SceneTree
## Renders the music scores (Tracks) to WAV files, exactly as the game plays
## them, for the move to real audio files. gamekit's `music render` runs it and
## turns the WAVs into looping OGGs (see assets.yaml, `music:`):
##   Godot --headless --path . -s tools/render_music.gd -- --out=<folder> [--track=<name> ...]
## Without --track it renders every track in Tracks.ALL.


func _init() -> void:
	var out_dir := "."
	var tracks: Array[StringName] = []
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--track="):
			tracks.append(StringName(arg.trim_prefix("--track=")))
	if tracks.is_empty():
		tracks.assign(Tracks.ALL.keys())
	DirAccess.make_dir_recursive_absolute(out_dir)
	for track: StringName in tracks:
		if not Tracks.ALL.has(track):
			push_error("Unknown track %s (known: %s)" % [track, ", ".join(Tracks.ALL.keys())])
			quit(1)
			return
		var path := out_dir.path_join("%s.wav" % track)
		var error := Synth.to_stream(MusicComposer.render(Tracks.ALL[track])).save_to_wav(path)
		if error != OK:
			push_error("Can't write %s (error %d)" % [path, error])
			quit(1)
			return
		print("rendered %s -> %s" % [track, path])
	quit()
