extends Node
## Player preferences (reach it anywhere as `Settings`). Saved to
## user://settings.cfg so they survive restarts. Changing a value applies it
## right away; call save() to keep it.

const PATH: String = "user://settings.cfg"

var master_volume: float = 0.8
var sfx_volume: float = 0.8
var music_volume: float = 0.6
var fullscreen: bool = false
var screen_shake: bool = true


func _ready() -> void:
	load_settings()
	apply()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	master_volume = clampf(config.get_value("audio", "master_volume", master_volume), 0.0, 1.0)
	sfx_volume = clampf(config.get_value("audio", "sfx_volume", sfx_volume), 0.0, 1.0)
	music_volume = clampf(config.get_value("audio", "music_volume", music_volume), 0.0, 1.0)
	fullscreen = config.get_value("video", "fullscreen", fullscreen)
	screen_shake = config.get_value("video", "screen_shake", screen_shake)


func save() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("video", "screen_shake", screen_shake)
	config.save(PATH)


## Index of an audio bus, created (routed to Master) if it doesn't exist yet.
func _bus(bus_name: StringName) -> int:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, &"Master")
	return index


func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(master_volume))
	AudioServer.set_bus_volume_db(_bus(&"SFX"), linear_to_db(sfx_volume))
	AudioServer.set_bus_volume_db(_bus(&"Music"), linear_to_db(music_volume))
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
