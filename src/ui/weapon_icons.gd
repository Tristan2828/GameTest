class_name WeaponIcons
extends Control
## A row of auto-weapon icons, each with its level as small pips underneath
## (filled up to the weapon's level, hollow up to the max). Used by the HUD and
## the end-of-run summary.

const PIP: float = 2.0
const PIP_GAP: float = 1.0
const PIP_TOP_GAP: float = 2.0
const ICON_GAP: float = 4.0
const PIP_COLOR: Color = Color(0.95, 0.78, 0.4)
const PIP_EMPTY_COLOR: Color = Color(0.36, 0.3, 0.46)

## Sprite scale (1 in the HUD, 2 on the summary cards). Pips scale with it.
@export var icon_scale: float = 1.0

## [weapon id, level] pairs, in the order they were gained.
var _weapons: Array[Vector2i] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## `levels`: weapon id -> level (Player.weapon_levels).
func set_weapons(levels: Dictionary[int, int]) -> void:
	var fresh: Array[Vector2i] = []
	for weapon_id: int in levels:
		fresh.append(Vector2i(weapon_id, levels[weapon_id]))
	if fresh == _weapons:
		return
	_weapons = fresh
	custom_minimum_size = _row_size()
	queue_redraw()


func _icon_size() -> Vector2:
	return Vector2(9, 9) * icon_scale


func _row_size() -> Vector2:
	if _weapons.is_empty():
		return Vector2.ZERO
	var icon := _icon_size()
	var width := _weapons.size() * icon.x + (_weapons.size() - 1) * ICON_GAP * icon_scale
	return Vector2(width, icon.y + (PIP_TOP_GAP + PIP) * icon_scale)


func _draw() -> void:
	var icon := _icon_size()
	var pip := PIP * icon_scale
	var pip_gap := PIP_GAP * icon_scale
	for i: int in _weapons.size():
		var weapon := AutoWeapons.get_weapon(_weapons[i].x)
		var left := i * (icon.x + ICON_GAP * icon_scale)
		if PixelArt.has_sprite(weapon.icon):
			PixelArt.draw(self, weapon.icon, Vector2(left, 0.0) + icon / 2.0, Color.WHITE, false, false, icon_scale)
		else:
			draw_rect(Rect2(Vector2(left, 0.0), icon), weapon.color)
		var pips_width := AutoWeapons.MAX_LEVEL * (pip + pip_gap) - pip_gap
		var pip_left := left + floorf((icon.x - pips_width) / 2.0)
		var pip_top := icon.y + PIP_TOP_GAP * icon_scale
		for level: int in AutoWeapons.MAX_LEVEL:
			var color := PIP_COLOR if level < _weapons[i].y else PIP_EMPTY_COLOR
			draw_rect(Rect2(pip_left + level * (pip + pip_gap), pip_top, pip, pip), color)
