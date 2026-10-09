class_name PlaytestDoc
extends RefCounted
## Reads the checklist items out of docs/PLAYTEST.md (the human playtest list,
## shipped inside the build) and remembers which ones you've ticked in-game.
##
## Every "### Heading" with "- [ ] question" lines under it becomes a section.
## Indented lines (Claude's "Tune:" hints) are skipped. Markdown marks and
## non-ASCII punctuation are cleaned up for the pixel font.

const PATH: String = "res://docs/PLAYTEST.md"
const SAVE_PATH: String = "user://playtest.cfg"
const SAVE_SECTION: String = "checked"

## Each: {"title": String, "items": Array[Dictionary]}; item: {"text": String, "done_in_doc": bool}.
var sections: Array[Dictionary] = []
## Item key -> ticked in-game.
var _ticked: Dictionary[String, bool] = {}


static func load_default() -> PlaytestDoc:
	var doc := PlaytestDoc.new()
	var text := FileAccess.get_file_as_string(PATH)
	doc.parse(text)
	doc.load_ticks()
	return doc


func parse(text: String) -> void:
	sections.clear()
	var current: Dictionary = {}
	for raw: String in text.split("\n"):
		var line := raw.strip_edges(false, true)
		if line.begins_with("### "):
			current = {"title": clean(line.substr(4)), "items": [] as Array[Dictionary]}
			sections.append(current)
		elif line.begins_with("## ") or line.begins_with("# "):
			current = {}
		elif not current.is_empty() and (line.begins_with("- [ ] ") or line.begins_with("- [x] ") or line.begins_with("- [X] ")):
			var items: Array[Dictionary] = current["items"]
			items.append({"text": clean(line.substr(6)), "done_in_doc": line[3] != " "})
	sections = sections.filter(func(section: Dictionary) -> bool: return not (section["items"] as Array).is_empty())


## Strips **bold**, *italic* and `code` marks and swaps characters the pixel
## font doesn't have.
static func clean(text: String) -> String:
	var result := text.replace("**", "").replace("`", "")
	result = result.replace("—", "-").replace("–", "-").replace("→", "->").replace("’", "'").replace("‘", "'")
	result = result.replace("“", "\"").replace("”", "\"").replace("…", "...").replace("×", "x").replace("·", "-")
	var plain := ""
	for i: int in result.length():
		var code := result.unicode_at(i)
		if code == 42:  # "*" (italic marks)
			continue
		plain += result[i] if code < 128 else ""
	return plain.strip_edges()


static func key_of(item: Dictionary) -> String:
	return str(String(item["text"]).hash())


func is_done(item: Dictionary) -> bool:
	return item["done_in_doc"] or _ticked.get(key_of(item), false)


func set_ticked(item: Dictionary, ticked: bool) -> void:
	_ticked[key_of(item)] = ticked
	save_ticks()


## [done, total] over every item.
func progress() -> Vector2i:
	var done := 0
	var total := 0
	for section: Dictionary in sections:
		for item: Dictionary in section["items"]:
			total += 1
			if is_done(item):
				done += 1
	return Vector2i(done, total)


## Plain-text list of what's left, to paste back to Claude.
func remaining_text() -> String:
	var lines := PackedStringArray(["Still to playtest:"])
	for section: Dictionary in sections:
		var open := PackedStringArray()
		for item: Dictionary in section["items"]:
			if not is_done(item):
				open.append("- " + String(item["text"]))
		if not open.is_empty():
			lines.append("")
			lines.append(String(section["title"]))
			lines.append_array(open)
	return "\n".join(lines)


func load_ticks() -> void:
	_ticked.clear()
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK or not config.has_section(SAVE_SECTION):
		return
	for key: String in config.get_section_keys(SAVE_SECTION):
		_ticked[key] = bool(config.get_value(SAVE_SECTION, key, false))


func save_ticks() -> void:
	var config := ConfigFile.new()
	for key: String in _ticked:
		if _ticked[key]:
			config.set_value(SAVE_SECTION, key, true)
	config.save(SAVE_PATH)
