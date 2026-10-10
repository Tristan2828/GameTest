class_name WeaponIcons
extends Control
## A row of build icons, each with its level as small pips underneath (filled up
## to the level, hollow up to the max; an evolved weapon gets a gold bar). Used
## by the HUD (weapons row: main weapon first, then auto weapons; passives row)
## and the end-of-run summary.

const PIP: float = 1.0
const PIP_GAP: float = 1.0
const PIP_TOP_GAP: float = 2.0
const ICON_GAP: float = 3.0
const PIP_COLOR: Color = Color(0.95, 0.78, 0.4)
const PIP_EMPTY_COLOR: Color = Color(0.36, 0.3, 0.46)
const EVOLVED_COLOR: Color = Color(0.6, 1.0, 0.6)

## Sprite scale (1 in the HUD, 2 on the summary cards). Pips scale with it.
@export var icon_scale: float = 1.0

## One Entry per icon, in order.
var _entries: Array[Entry] = []


class Entry:
	var sprite: String
	var level: int
	var max_level: int
	var evolved: bool
	var color: Color = Color.WHITE

	func _init(entry_sprite: String, entry_level: int, entry_max: int, entry_evolved: bool = false) -> void:
		sprite = entry_sprite
		level = entry_level
		max_level = entry_max
		evolved = entry_evolved

	func same_as(other: Entry) -> bool:
		return sprite == other.sprite and level == other.level and max_level == other.max_level and evolved == other.evolved


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The weapons row for this player: the main weapon, then each auto weapon.
static func weapon_entries(player: Player) -> Array[Entry]:
	var entries: Array[Entry] = [Entry.new(player.stats.main_weapon_icon, player.main_level,
		player.stats.main_max_level(), player.main_evolved)]
	for weapon_id: int in player.weapon_levels:
		var weapon := AutoWeapons.get_weapon(weapon_id)
		var entry := Entry.new(weapon.icon, player.weapon_levels[weapon_id], weapon.max_level(), weapon.is_evolution())
		entry.color = weapon.color
		entries.append(entry)
	return entries


## The passives row for this player.
static func passive_entries(player: Player) -> Array[Entry]:
	var entries: Array[Entry] = []
	var levels := Cards.passive_levels(player)
	for id: int in levels:
		entries.append(Entry.new(Upgrades.get_upgrade(id).icon, levels[id], Upgrades.get_upgrade(id).max_stacks))
	return entries


func set_entries(entries: Array[Entry]) -> void:
	var same := entries.size() == _entries.size()
	for i: int in mini(entries.size(), _entries.size()):
		same = same and entries[i].same_as(_entries[i])
	if same:
		return
	_entries = entries
	custom_minimum_size = _row_size()
	queue_redraw()


## Auto weapons only (weapon id -> level), e.g. for tests and simple rows.
func set_weapons(levels: Dictionary[int, int]) -> void:
	var entries: Array[Entry] = []
	for weapon_id: int in levels:
		var weapon := AutoWeapons.get_weapon(weapon_id)
		entries.append(Entry.new(weapon.icon, levels[weapon_id], weapon.max_level(), weapon.is_evolution()))
	set_entries(entries)


func _icon_size() -> Vector2:
	return Vector2(9, 9) * icon_scale


func _pips_width(entry: Entry) -> float:
	var count := 1 if entry.evolved else entry.max_level
	return count * (PIP + PIP_GAP) * icon_scale - PIP_GAP * icon_scale


func _item_width(entry: Entry) -> float:
	return maxf(_icon_size().x, _pips_width(entry))


func _row_size() -> Vector2:
	if _entries.is_empty():
		return Vector2.ZERO
	var width := 0.0
	for entry: Entry in _entries:
		width += _item_width(entry)
	width += (_entries.size() - 1) * ICON_GAP * icon_scale
	return Vector2(width, _icon_size().y + (PIP_TOP_GAP + PIP) * icon_scale)


func _draw() -> void:
	var icon := _icon_size()
	var pip := PIP * icon_scale
	var pip_gap := PIP_GAP * icon_scale
	var left := 0.0
	for entry: Entry in _entries:
		var width := _item_width(entry)
		var center := Vector2(left + width / 2.0, icon.y / 2.0).floor()
		if PixelArt.has_sprite(entry.sprite):
			PixelArt.draw(self, entry.sprite, center, Color.WHITE, false, false, icon_scale)
		else:
			draw_rect(Rect2(Vector2(left + (width - icon.x) / 2.0, 0.0), icon), entry.color)
		var pip_top := icon.y + PIP_TOP_GAP * icon_scale
		if entry.evolved:
			draw_rect(Rect2(left, pip_top, width, pip), EVOLVED_COLOR)
		else:
			var pip_left := left + floorf((width - _pips_width(entry)) / 2.0)
			for level: int in entry.max_level:
				var color := PIP_COLOR if level < entry.level else PIP_EMPTY_COLOR
				draw_rect(Rect2(pip_left + level * (pip + pip_gap), pip_top, pip, pip), color)
		left += width + ICON_GAP * icon_scale
