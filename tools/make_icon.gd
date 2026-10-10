extends SceneTree
## Writes the Windows exe icon (.ico) from the game's own pixel art (the
## Wanderer on the dark crypt color), so no binary art is kept in the repo.
## tools/build.ps1 runs it before exporting:
##   Godot --headless --path . -s tools/make_icon.gd -- <output.ico>

const SIZES: Array[int] = [16, 32, 48, 64, 128, 256]
const BACKGROUND: Color = Color(0.08, 0.06, 0.11)
const HERO_COLOR: Color = Color(0.36, 0.78, 0.95)


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path := args[0] if not args.is_empty() else "icon.ico"
	var hero := PixelArt.texture("wanderer", HERO_COLOR).get_image()
	var side := maxi(hero.get_width(), hero.get_height()) + 2
	var base := Image.create(side, side, false, Image.FORMAT_RGBA8)
	base.fill(BACKGROUND)
	var at := Vector2i((side - hero.get_width()) / 2, (side - hero.get_height()) / 2)
	base.blend_rect(hero, Rect2i(Vector2i.ZERO, hero.get_size()), at)
	var pngs: Array[PackedByteArray] = []
	for size: int in SIZES:
		var scaled := base.duplicate() as Image
		scaled.resize(size, size, Image.INTERPOLATE_NEAREST)
		pngs.append(scaled.save_png_to_buffer())
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		push_error("Can't write %s" % out_path)
		quit(1)
		return
	# ICO header, then one 16-byte directory entry per size; each image is a PNG.
	file.store_16(0)
	file.store_16(1)
	file.store_16(SIZES.size())
	var offset := 6 + 16 * SIZES.size()
	for i: int in SIZES.size():
		var size := SIZES[i]
		file.store_8(0 if size >= 256 else size)
		file.store_8(0 if size >= 256 else size)
		file.store_8(0)
		file.store_8(0)
		file.store_16(1)
		file.store_16(32)
		file.store_32(pngs[i].size())
		file.store_32(offset)
		offset += pngs[i].size()
	for png: PackedByteArray in pngs:
		file.store_buffer(png)
	file.close()
	print("Wrote %s" % out_path)
	quit(0)
