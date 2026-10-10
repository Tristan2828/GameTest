extends GutTest
## The title menu's Compendium and Playtest Checklist.

const SAMPLE: String = """# Playtest Review
Intro text.

## 3. Checklists

### 3.1 Feel
- [ ] Does **movement** feel *instant* — even `online`?
  - *Tune: something.*
- [x] Already confirmed in the doc
Not a checklist line.

### 3.2 Empty section
Just text.

## 4. Other
- [ ] Not under a ### heading, ignored
"""


func test_parser_reads_sections_and_items() -> void:
	var doc := PlaytestDoc.new()
	doc.parse(SAMPLE)
	assert_eq(doc.sections.size(), 1, "sections without items are dropped")
	assert_eq(doc.sections[0]["title"], "3.1 Feel")
	var items: Array = doc.sections[0]["items"]
	assert_eq(items.size(), 2, "the indented Tune hint is skipped")
	assert_eq(items[0]["text"], "Does movement feel instant - even online?")
	assert_false(items[0]["done_in_doc"])
	assert_true(items[1]["done_in_doc"])
	assert_eq(doc.progress(), Vector2i(1, 2))


func test_ticks_count_and_list_whats_left() -> void:
	var doc := PlaytestDoc.new()
	doc.parse(SAMPLE)
	var item: Dictionary = doc.sections[0]["items"][0]
	assert_string_contains(doc.remaining_text(), "movement")
	doc._ticked[PlaytestDoc.key_of(item)] = true
	assert_true(doc.is_done(item))
	assert_eq(doc.progress(), Vector2i(2, 2))
	assert_false(doc.remaining_text().contains("movement"))


func test_clean_leaves_only_ascii_for_the_pixel_font() -> void:
	var cleaned := PlaytestDoc.clean("A → B “quoted” — ✅ done…")
	for i: int in cleaned.length():
		assert_lt(cleaned.unicode_at(i), 128, cleaned)
	assert_eq(cleaned, "A -> B \"quoted\" -  done...")


func test_the_real_playtest_doc_parses_and_ships_in_the_build() -> void:
	var doc := PlaytestDoc.new()
	doc.parse(FileAccess.get_file_as_string(PlaytestDoc.PATH))
	assert_gt(doc.sections.size(), 5)
	assert_gt(doc.progress().y, 30)
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	assert_string_contains(presets, "docs/PLAYTEST.md", "the export includes the checklist")


func test_compendium_fills_every_tab() -> void:
	var compendium := Compendium.new()
	add_child_autofree(compendium)
	compendium.open()
	var tabs := compendium._tab_buttons
	assert_eq(tabs.size(), 8)
	for tab: Button in tabs:
		tab.pressed.emit()
		await wait_process_frames(1)
		assert_not_null(compendium.first_focusable_row(), tab.text + " has rows")


func test_compendium_numbers_come_from_the_data() -> void:
	var wanderer := Characters.get_character(Characters.Id.WANDERER)
	assert_string_contains(Compendium.hero_details(wanderer), "Hearts %d" % wanderer.max_hearts)
	var skulls := AutoWeapons.get_weapon(AutoWeapons.Id.ORBITING_SKULLS)
	assert_string_contains(Compendium.weapon_details(skulls), "Lv %d" % AutoWeapons.MAX_LEVEL)
	var boss_id := Stages.get_stage(2).boss_type
	assert_eq(Compendium.boss_stage(boss_id), 2)
	assert_string_contains(Compendium.enemy_details(EnemyTypes.get_type(boss_id), 2),
		"HP %d" % roundi(EnemyTypes.get_type(boss_id).max_hp * (1.0 + Arena.STAGE_HP_GROWTH)))
	assert_true(Compendium.stages_with(EnemyTypes.Id.SHAMBLER).has(Stages.get_stage(1).title))


func test_checklist_opens_with_rows_and_closes() -> void:
	var checklist := PlaytestChecklist.new()
	add_child_autofree(checklist)
	checklist.doc = PlaytestDoc.new()
	checklist.doc.parse(SAMPLE)
	checklist.open()
	assert_true(checklist.visible)
	assert_not_null(checklist.first_focusable_row())
	watch_signals(checklist)
	checklist.close()
	assert_false(checklist.visible)
	assert_signal_emitted(checklist, "closed")


func test_sprite_icon_scale_fits() -> void:
	assert_eq(SpriteIcon.fit_scale(Vector2i(9, 9), Vector2(40, 34), 2), 2)
	assert_eq(SpriteIcon.fit_scale(Vector2i(30, 30), Vector2(40, 34), 2), 1)
