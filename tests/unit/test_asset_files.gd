extends GutTest
## Finished art and audio files (assets/, docs/ART_BRIEF.md and AUDIO_BRIEF.md)
## replace the text sprites and synth sounds one at a time.

const ART_DIR := "res://assets/art/"
const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"


func after_each() -> void:
	PixelArt.set_file_image("wanderer", null)
	PixelArt.set_file_image("test_only", null)
	PixelArt.set_file_image("test_only_lg", null)


## Colors match after a round trip through an 8-bit image.
func _close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01 and absf(a.a - b.a) < 0.01


func _image(width: int, height: int, color: Color) -> Image:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return image


func test_an_art_file_replaces_the_text_sprite() -> void:
	var image := _image(3, 2, Color(0, 0, 0, 0))
	image.set_pixel(0, 0, PixelArt.FILE_TINT)
	image.set_pixel(1, 0, PixelArt.FILE_TINT_SHADE)
	image.set_pixel(2, 0, Color8(23, 18, 28))
	PixelArt.set_file_image("wanderer", image)
	assert_eq(PixelArt.size_of("wanderer"), Vector2i(3, 2))
	var red := PixelArt.texture("wanderer", Color.RED).get_image()
	assert_true(_close(red.get_pixel(0, 0), Color.RED), "magenta takes the player color")
	assert_true(_close(red.get_pixel(1, 0), Color.RED.darkened(0.35)), "dark magenta takes its shade")
	assert_true(_close(red.get_pixel(2, 0), Color8(23, 18, 28)), "other colors stay")
	assert_eq(red.get_pixel(0, 1).a, 0.0, "transparent stays transparent")
	var flash := PixelArt.texture("wanderer", Color.RED, true).get_image()
	assert_true(_close(flash.get_pixel(2, 0), Color.WHITE), "hit flash whitens")


func test_a_file_only_sprite_exists_and_big_icons_find_it() -> void:
	assert_false(PixelArt.has_sprite("test_only_lg"))
	PixelArt.set_file_image("test_only_lg", _image(16, 16, Color.WHITE))
	assert_true(PixelArt.has_sprite("test_only_lg"))
	assert_eq(PixelArt.big_icon("test_only"), "test_only_lg")


func test_going_back_to_the_text_sprite() -> void:
	var size := PixelArt.size_of("wanderer")
	PixelArt.set_file_image("wanderer", _image(3, 2, Color.WHITE))
	PixelArt.set_file_image("wanderer", null)
	assert_eq(PixelArt.size_of("wanderer"), size)


func _files(dir: String, extension: String) -> Array[String]:
	var names: Array[String] = []
	if not DirAccess.dir_exists_absolute(dir):
		return names
	for file: String in DirAccess.get_files_at(dir):
		if file.get_extension() == extension:
			names.append(file.get_basename())
	return names


func test_art_files_are_known_sprites_at_their_size() -> void:
	if _files(ART_DIR, "png").is_empty():
		pass_test("no art files yet")
	for sprite: String in _files(ART_DIR, "png"):
		var known := PixelArt.SPRITES.has(sprite) or PixelArt.SPRITES.has(sprite.trim_suffix("_lg"))
		assert_true(known, "%s.png doesn't match a sprite (see docs/ART_BRIEF.md)" % sprite)
		if PixelArt.SPRITES.has(sprite):
			var rows: Array = PixelArt.SPRITES[sprite]
			var text_size := Vector2i(String(rows[0]).length(), rows.size())
			assert_eq(PixelArt.size_of(sprite), text_size, "%s.png must keep the sprite's size" % sprite)


func test_sound_and_music_files_are_known() -> void:
	if _files(SFX_DIR, "wav").is_empty() and _files(MUSIC_DIR, "ogg").is_empty():
		pass_test("no sound or music files yet")
	for sound: String in _files(SFX_DIR, "wav"):
		assert_true(Sfx.has_sound(StringName(sound)), "%s.wav doesn't match a sound" % sound)
		assert_true(Sfx.is_from_file(StringName(sound)), "%s.wav isn't used" % sound)
	for track: String in _files(MUSIC_DIR, "ogg"):
		assert_true(Tracks.ALL.has(StringName(track)), "%s.ogg doesn't match a track" % track)


func test_music_files_load_ready_and_looping() -> void:
	for track: String in _files(MUSIC_DIR, "ogg"):
		assert_true(Music.is_from_file(StringName(track)), track)
		assert_true(Music.is_ready(StringName(track)), "%s is ready at once" % track)
		var stream := Music._streams[StringName(track)] as AudioStreamOggVorbis
		assert_not_null(stream, track)
		if stream != null:
			assert_true(stream.loop, "%s loops" % track)
