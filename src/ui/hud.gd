class_name Hud
extends CanvasLayer
## In-game overlay. The arena pushes values in; the HUD only displays them.

@onready var _hearts: HeartsDisplay = %Hearts
@onready var _xp_bar: XpBar = %XpBar
@onready var _level_label: Label = %LevelLabel
@onready var _timer_label: Label = %TimerLabel
@onready var _status_label: Label = %StatusLabel
@onready var _info_label: Label = %InfoLabel
@onready var _banner: Control = %Banner
@onready var _banner_title: Label = %BannerTitle
@onready var _banner_subtitle: Label = %BannerSubtitle
@onready var level_up_panel: LevelUpPanel = %LevelUpPanel


func set_hearts(current: int, maximum: int) -> void:
	_hearts.set_hearts(current, maximum)


func set_progress(level: int, ratio: float) -> void:
	_xp_bar.set_ratio(ratio)
	_level_label.text = "Lv %d" % level


func set_time_left(seconds: float) -> void:
	var whole := ceili(maxf(seconds, 0.0))
	_timer_label.text = "%d:%02d" % [whole / 60, whole % 60]


## Top-right: role, ping, player count.
func set_status(text: String) -> void:
	_status_label.text = text


## Bottom-left: controls hint, host invite.
func set_info(text: String) -> void:
	_info_label.text = text


func show_banner(title: String, subtitle: String) -> void:
	_banner_title.text = title
	_banner_subtitle.text = subtitle
	_banner.show()


func hide_banner() -> void:
	_banner.hide()
