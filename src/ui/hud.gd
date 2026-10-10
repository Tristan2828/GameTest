class_name Hud
extends CanvasLayer
## In-game overlay. The arena pushes values in; the HUD only displays them.

@onready var _health: HealthBar = %Health
@onready var minimap: Minimap = %Minimap
@onready var teammate_arrows: TeammateArrows = %TeammateArrows
@onready var _hurt_flash: ColorRect = %HurtFlash
@onready var _xp_bar: XpBar = %XpBar
@onready var _level_label: Label = %LevelLabel
@onready var _boss_box: Control = %BossBox
@onready var _boss_name: Label = %BossName
@onready var _boss_bar: XpBar = %BossBar
@onready var _timer_label: Label = %TimerLabel
@onready var _status_label: Label = %StatusLabel
@onready var _info_label: Label = %InfoLabel
@onready var _banner: Control = %Banner
@onready var _banner_title: Label = %BannerTitle
@onready var _banner_subtitle: Label = %BannerSubtitle
@onready var level_up_panel: LevelUpPanel = %LevelUpPanel
@onready var shop_panel: ShopPanel = %ShopPanel
@onready var run_summary: RunSummaryPanel = %RunSummary
@onready var _coins_label: Label = %CoinsLabel
@onready var _weapon_icons: WeaponIcons = %WeaponIcons


## A red flash over the screen (`strength` = how opaque it starts).
func flash_hurt(strength: float = 0.28) -> void:
	_hurt_flash.color.a = maxf(_hurt_flash.color.a, strength)
	create_tween().tween_property(_hurt_flash, "color:a", 0.0, 0.35)


func set_health(current: int, maximum: int) -> void:
	_health.set_health(current, maximum)


## Auto weapon icons with level pips (weapon id -> level).
func set_weapons(levels: Dictionary[int, int]) -> void:
	_weapon_icons.set_weapons(levels)


func set_coins(count: int) -> void:
	_coins_label.text = "%d coins" % count


func set_progress(level: int, ratio: float) -> void:
	_xp_bar.set_ratio(ratio)
	_level_label.text = "Lv %d" % level


func set_time_left(seconds: float) -> void:
	var whole := ceili(maxf(seconds, 0.0))
	_timer_label.text = "%d:%02d" % [whole / 60, whole % 60]


## Big text instead of the countdown (e.g. "BOSS").
func set_timer_text(text: String) -> void:
	_timer_label.text = text


## Boss health bar under the timer. Pass an empty name to hide it.
func set_boss(boss_name: String, hp_ratio: float) -> void:
	_boss_box.visible = not boss_name.is_empty()
	_boss_name.text = boss_name
	_boss_bar.set_ratio(hp_ratio)


## Top-right: role, ping, player count.
func set_status(text: String) -> void:
	_status_label.text = text


## Bottom-left: controls hint, host invite.
func set_info(text: String) -> void:
	_info_label.text = text


var _quest_label: Label = null
const QUEST_COLOR: Color = Color(0.85, 0.8, 0.95)
const QUEST_DONE_COLOR: Color = Color(0.55, 0.95, 0.5)


## Left side, under the weapon icons: "Quest: Slayer 120/250" ("" hides it).
func set_quest(text: String, done: bool) -> void:
	if _quest_label == null:
		_quest_label = Label.new()
		_quest_label.position = Vector2(8, 65)
		_quest_label.size = Vector2(240, 12)
		_quest_label.add_theme_font_size_override("font_size", 9)
		_quest_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_quest_label)
		move_child(_quest_label, _banner.get_index())
	_quest_label.text = text
	_quest_label.visible = not text.is_empty()
	_quest_label.add_theme_color_override("font_color", QUEST_DONE_COLOR if done else QUEST_COLOR)


var _notice: Label = null


## A line low in the middle of the screen (downed / reviving). "" hides it.
func set_notice(text: String) -> void:
	if _notice == null:
		_notice = Label.new()
		_notice.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_notice.offset_left = -300.0
		_notice.offset_right = 300.0
		_notice.offset_top = -96.0
		_notice.offset_bottom = -70.0
		_notice.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_notice.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_notice.add_theme_font_size_override("font_size", 9)
		_notice.add_theme_color_override("font_color", Color(0.75, 1.0, 0.7))
		_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_notice)
		move_child(_notice, _banner.get_index())
	_notice.text = text
	_notice.visible = not text.is_empty()


const TOAST_SECONDS: float = 3.5
const MAX_TOASTS: int = 3
var _toasts: VBoxContainer = null


## A short message under the timer that fades out ("Red grabbed a Holy Bomb!").
## The newest is at the bottom; only a few are kept.
func toast(text: String, color: Color = Color(0.95, 0.9, 1.0)) -> void:
	if _toasts == null:
		_toasts = VBoxContainer.new()
		_toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_toasts.offset_left = -200.0
		_toasts.offset_right = 200.0
		_toasts.offset_top = 62.0
		_toasts.offset_bottom = 110.0
		_toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_toasts.add_theme_constant_override("separation", 1)
		_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_toasts)
		move_child(_toasts, _banner.get_index())
	while _toasts.get_child_count() >= MAX_TOASTS:
		var oldest := _toasts.get_child(0)
		_toasts.remove_child(oldest)
		oldest.queue_free()
	var line := Label.new()
	line.text = text
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_font_size_override("font_size", 9)
	line.add_theme_color_override("font_color", color)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_child(line)
	var tween := line.create_tween()
	tween.tween_interval(TOAST_SECONDS)
	tween.tween_property(line, "modulate:a", 0.0, 0.6)
	tween.tween_callback(line.queue_free)


func show_banner(title: String, subtitle: String) -> void:
	_banner_title.text = title
	_banner_subtitle.text = subtitle
	_banner.show()


func hide_banner() -> void:
	_banner.hide()
