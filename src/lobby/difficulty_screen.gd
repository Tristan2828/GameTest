class_name DifficultyScreen
extends RunConfigScreen
## Lobby page: difficulty sliders and Easy / Normal / Hard presets.


func _ready() -> void:
	set_title("Difficulty")


func _build_rows() -> void:
	var presets := HBoxContainer.new()
	presets.alignment = BoxContainer.ALIGNMENT_CENTER
	presets.add_theme_constant_override("separation", 6)
	presets.add_child(label("Presets:", 9, NAME_COLOR))
	for preset_name: String in RunConfig.PRESETS:
		var button := Button.new()
		button.text = preset_name
		button.custom_minimum_size.x = 70
		button.disabled = not editable
		button.pressed.connect(func() -> void:
			config.apply_preset(preset_name)
			_changed())
		presets.add_child(button)
	var current := label("", 9, TITLE_COLOR)
	current.custom_minimum_size.x = 90
	current.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	presets.add_child(current)
	_refreshers.append(func() -> void: current.text = "Now: %s" % config.difficulty_name())
	add_row(presets, false)
	_slider("enemy_health", "Enemy health", "Regular enemies' HP", RunConfigScreen.percent)
	_slider("boss_health", "Boss health", "Boss HP (still grows with players)", RunConfigScreen.percent)
	_slider("enemy_count", "Enemy count", "How fast the horde spawns", RunConfigScreen.percent)
	_slider("xp_rate", "XP gain", "Higher = level up more often", RunConfigScreen.percent)
	_slider("coin_rate", "Coin drops", "Chance enemies drop coins", RunConfigScreen.percent)
	_slider("hp_bonus", "Bonus HP", "Extra max HP for every hero", RunConfigScreen.signed)
	_changed_refresh_only()


## Fill in the preset label without telling the lobby anything changed.
func _changed_refresh_only() -> void:
	for refresh: Callable in _refreshers:
		refresh.call()
