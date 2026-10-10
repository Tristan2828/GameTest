class_name CustomGameScreen
extends RunConfigScreen
## Lobby page: full run or a custom single-stage game, the map, wave length,
## boss on/off, starting boosts, Ember boosts on/off and the soundtrack.


func _ready() -> void:
	set_title("Custom Game")


func _build_rows() -> void:
	var modes: Array[String] = ["Full run (%d stages)" % Stages.ALL.size(), "Single stage"]
	_cycle("Game", "A single stage is won by clearing it", modes,
		func() -> int: return 1 if config.single_stage else 0,
		func(index: int) -> void: config.single_stage = index == 1)
	var maps: Array[String] = []
	for stage: StageDef in Stages.ALL:
		maps.append(stage.title)
	_cycle("Map", "Single stage only", maps,
		func() -> int: return config.stage - 1,
		func(index: int) -> void: config.set_value("stage", index + 1))
	_slider("wave_seconds", "Wave length", "Horde time before the boss", RunConfigScreen.minutes)
	_toggle("boss_enabled", "Boss", "Off: survive the timer to win")
	_slider("bonus_levels", "Starting level-ups", "Upgrades everyone picks at the start", func(value: int) -> String: return str(value))
	_toggle("start_with_weapons", "All weapons", "Start with every auto weapon")
	_toggle("ember_boosts", "Ember boosts", "Off: nobody's Ember Shrine boosts count")
	_cycle("Soundtrack", "Music during the run (for everyone)", Tracks.SOUNDTRACKS,
		func() -> int: return config.soundtrack,
		func(index: int) -> void: config.set_value("soundtrack", index))
