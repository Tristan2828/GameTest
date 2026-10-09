extends Node
## Background music (reach it anywhere as `Music`): `Music.play(&"crypt")`.
##
## Tracks are text scores (Tracks) rendered by MusicComposer on background
## threads at startup, so the game never stalls. A track asked for before it's
## ready starts as soon as it is. Switching tracks crossfades.

const BUS: StringName = &"Music"
const FADE_SECONDS: float = 1.2
const SILENT_DB: float = -40.0
## Render order: the menu first (it's needed first), then the stages.
const RENDER_ORDER: Array[StringName] = [&"menu", &"crypt", &"boss", &"marsh", &"cathedral",
	&"metal_crypt", &"metal_boss", &"metal_marsh", &"metal_cathedral"]

var _streams: Dictionary[StringName, AudioStreamWAV] = {}
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
	# Headless runs (tests, servers) have no speakers: skip the work.
	if DisplayServer.get_name() == "headless":
		return
	for track: StringName in RENDER_ORDER:
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


func is_ready(track: StringName) -> bool:
	_mutex.lock()
	var ready := _streams.has(track)
	_mutex.unlock()
	return ready


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
	var stream: AudioStreamWAV = _streams[_wanted]
	_mutex.unlock()
	var old := _players[_active]
	_active = 1 - _active
	var new := _players[_active]
	new.stream = stream
	new.volume_db = SILENT_DB
	new.play()
	var fade := create_tween().set_parallel()
	fade.tween_property(new, "volume_db", 0.0, FADE_SECONDS)
	fade.tween_property(old, "volume_db", SILENT_DB, FADE_SECONDS)
	fade.chain().tween_callback(old.stop)
	_playing = _wanted
