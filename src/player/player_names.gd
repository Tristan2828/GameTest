class_name PlayerNames
extends RefCounted
## Display names: each player types one on the title menu (Settings.player_name).
## Without one, a player is called by their slot color ("Blue", "Red"...).
## Pure helpers; Net keeps everyone's names in sync.

## Long enough for most names, short enough for lobby cards and name tags.
const MAX_LENGTH: int = 12


## Trims the name, keeps only characters the pixel font can draw, and caps
## the length. Returns "" when nothing usable is left.
static func sanitize(text: String) -> String:
	var kept := ""
	for i: int in text.length():
		var code := text.unicode_at(i)
		if code >= 32 and code <= 126 and PixelFont.GLYPHS.has(char(code)):
			kept += char(code)
		elif code == 32 or code == 9:
			kept += " "
	while kept.contains("  "):
		kept = kept.replace("  ", " ")
	return kept.strip_edges().left(MAX_LENGTH).strip_edges()


## The name to show: the chosen one, or the slot color.
static func display(chosen: String, slot: int) -> String:
	return chosen if not chosen.is_empty() else Player.SLOT_NAMES[slot % Player.SLOT_NAMES.size()]
