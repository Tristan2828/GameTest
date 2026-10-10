class_name GameCursor
extends RefCounted
## The mouse cursor is hidden while you play (there's nothing to aim since
## v0.22.0: weapons fire by themselves) and shown everywhere you click: menus,
## level-up cards, the shop, the pause menu. The arena says when we're in play.

## True while the cursor should be hidden (set by the arena).
static var _in_game: bool = false


static func set_in_game(on: bool) -> void:
	if on == _in_game:
		return
	_in_game = on
	refresh()


static func refresh() -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if _in_game else Input.MOUSE_MODE_VISIBLE
