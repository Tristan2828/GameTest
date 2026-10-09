extends Node
## Player preferences (reach it anywhere as `Settings`). Saved to
## user://settings.cfg so they survive restarts. Changing a value applies it
## right away; call save() to keep it.

const PATH: String = "user://settings.cfg"

var master_volume: float = 0.8
var sfx_volume: float = 0.8
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
	fullscreen = config.get_value("video", "fullscreen", fullscreen)
	screen_shake = config.get_value("video", "screen_shake", screen_shake)


func save() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("video", "screen_shake", screen_shake)
	config.save(PATH)


func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(master_volume))
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
