extends Node
## Background music (reach it anywhere as `Music`): `Music.play(&"crypt")`.
##
## A finished music file `assets/audio/music/<track>.ogg` is used when there is
## one (docs/AUDIO_BRIEF.md); other tracks are text scores (Tracks) rendered by
## MusicComposer on background threads at startup, so the game never stalls. A
## track asked for before it's ready starts as soon as it is. Switching tracks
## crossfades.

const BUS: StringName = &"Music"
const FADE_SECONDS: float = 1.2
const SILENT_DB: float = -40.0
## Where finished music files live: <track>.ogg, each a seamless loop.
const MUSIC_DIR: String = "res://assets/audio/music/"
## Music files are mastered to -16 LUFS (the audio brief), about 4 dB louder than
## the scores render; this keeps them at the same level as before next to the
## sound effects. Revisit once the sound effects are files too.
const FILE_VOLUME_DB: float = -4.0
## Render order: the menu first (it's needed first), then the stages.
const RENDER_ORDER: Array[StringName] = [&"menu", &"crypt", &"boss", &"marsh", &"cathedral",
	&"metal_crypt", &"metal_boss", &"metal_marsh", &"metal_cathedral"]

var _streams: Dictionary[StringName, AudioStream] = {}
var _from_file: Dictionary[StringName, bool] = {}
var _tasks: Array[int] = []
var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _wanted: StringName = &""
var _playing: StringName = &""
var _mutex: Mutex = Mutex.new()


func _ready() -> void:
	for i: int in 2:
		var player := AudioStreamPlayer.new()
		player.bus = BUS
		player.volume_db = SILENT_DB
		add_child(player)
		_players.append(player)
	for track: StringName in RENDER_ORDER:
		var stream := _load_file(track)
		if stream != null:
			_streams[track] = stream
			_from_file[track] = true
	# Headless runs (tests, servers) have no speakers: skip the rendering.
	if DisplayServer.get_name() == "headless":
		return
	for track: StringName in RENDER_ORDER:
		if not _from_file.has(track):
			_tasks.append(WorkerThreadPool.add_task(_render.bind(track), false, "Render music %s" % track))


func _exit_tree() -> void:
	for task: int in _tasks:
		WorkerThreadPool.wait_for_task_completion(task)


## Switch to a track (no-op if it's already playing or wanted).
func play(track: StringName) -> void:
	if track == _wanted:
		return
	_wanted = track
	_start_if_ready()


## The track actually playing right now (empty until one is ready).
func now_playing() -> StringName:
	return _playing


## True when the track plays from a file instead of a rendered score.
func is_from_file(track: StringName) -> bool:
	return _from_file.has(track)


func is_ready(track: StringName) -> bool:
	_mutex.lock()
	var ready := _streams.has(track)
	_mutex.unlock()
	return ready


## The track's music file, set to loop, or null if it has none.
func _load_file(track: StringName) -> AudioStream:
	var path := MUSIC_DIR + String(track) + ".ogg"
	if not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStreamOggVorbis
	if stream != null:
		stream.loop = true
	return stream


## Background thread: render one track, then hand it to the main thread.
func _render(track: StringName) -> void:
	var stream := Synth.to_stream(MusicComposer.render(Tracks.ALL[track]), true)
	_mutex.lock()
	_streams[track] = stream
	_mutex.unlock()
	_start_if_ready.call_deferred()


func _start_if_ready() -> void:
	if _wanted == _playing or not is_ready(_wanted):
		return
	_mutex.lock()
	var stream: AudioStream = _streams[_wanted]
	var volume := FILE_VOLUME_DB if _from_file.has(_wanted) else 0.0
	_mutex.unlock()
	var old := _players[_active]
	_active = 1 - _active
	var new := _players[_active]
	new.stream = stream
	new.volume_db = SILENT_DB
	new.play()
	var fade := create_tween().set_parallel()
	fade.tween_property(new, "volume_db", volume, FADE_SECONDS)
	fade.tween_property(old, "volume_db", SILENT_DB, FADE_SECONDS)
	fade.chain().tween_callback(old.stop)
	_playing = _wanted
