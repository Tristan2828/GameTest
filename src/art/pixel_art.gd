class_name PixelArt
extends RefCounted
## Every sprite in the game, drawn as text: one character per pixel, each
## character a color from PALETTE ("." is transparent). Edit a row, rerun the
## game, and the sprite changes. Textures are built once and cached.
##
## "P" and "p" are recolored per player (their slot color and a darker shade),
## so every character works in every player color.
##
## Most sprites are left/right symmetric; keep them that way when editing.

const PALETTE: Dictionary[String, Color] = {
	".": Color(0, 0, 0, 0),
	"k": Color(0.09, 0.07, 0.11),
	"K": Color(0.27, 0.24, 0.31),
	"w": Color(0.95, 0.93, 0.88),
	"e": Color(1.0, 0.85, 0.35),
	"r": Color(0.8, 0.27, 0.27),
	"R": Color(0.5, 0.14, 0.18),
	"s": Color(0.56, 0.66, 0.48),
	"S": Color(0.37, 0.46, 0.32),
	"b": Color(0.84, 0.8, 0.68),
	"B": Color(0.56, 0.53, 0.45),
	"u": Color(0.52, 0.34, 0.66),
	"U": Color(0.31, 0.19, 0.42),
	"o": Color(0.92, 0.5, 0.17),
	"O": Color(0.6, 0.27, 0.1),
	"y": Color(1.0, 0.85, 0.4),
	"m": Color(0.68, 0.26, 0.45),
	"M": Color(0.42, 0.14, 0.29),
	"l": Color(0.56, 0.6, 0.7),
	"L": Color(0.33, 0.36, 0.45),
	"n": Color(0.33, 0.45, 0.25),
	"N": Color(0.21, 0.29, 0.16),
	"h": Color(0.48, 0.64, 0.42),
	"H": Color(0.3, 0.42, 0.27),
	"a": Color(0.74, 0.78, 0.32),
	"A": Color(0.48, 0.52, 0.18),
	"v": Color(0.5, 0.95, 0.55),
	"V": Color(0.24, 0.62, 0.34),
	"t": Color(0.4, 0.8, 1.0),
	"T": Color(0.18, 0.48, 0.7),
	"g": Color(0.85, 0.64, 0.25),
	"x": Color(0.13, 0.11, 0.16),
	"f": Color(0.93, 0.78, 0.63),
	"F": Color(0.72, 0.55, 0.42),
}

const SPRITES: Dictionary[String, Array] = {
	"wanderer": [
		"....kkkk....",
		"...kPPPPk...",
		"..kPPPPPPk..",
		"..kPkkkkPk..",
		".kPkekkekPk.",
		".kPkkkkkkPk.",
		".kPPkkkkPPk.",
		"kPPPPPPPPPPk",
		"kpPPPPPPPPpk",
		"kpPPPPPPPPpk",
		"kppPPPPPPppk",
		".kppPPPPppk.",
		".kkppppppkk.",
		"..kk.kk.kk..",
	],
	"gravekeeper": [
		"...kkkkkkkk...",
		"...kxxxxxxk...",
		"...kxxxxxxk...",
		".kkkxxxxxxkkk.",
		"kxxxxxxxxxxxxk",
		".kkkkkkkkkkkk.",
		"..kffffffffk..",
		"..kfekffkefk..",
		"..kffffffffk..",
		".kPkBBBBBBkPk.",
		"kPPPkBBBBkPPPk",
		"kPPPPkkkkPPPPk",
		"kpPPPPPPPPPPpk",
		"kpPPPPPPPPPPpk",
		".kppppppppppk.",
		"..kkk....kkk..",
	],
	"hexblade_witch": [
		".....kk.....",
		"....kxxk....",
		"....kxxk....",
		"...kxxxxk...",
		"...kxxxxk...",
		"..kxxxxxxk..",
		"kkkxxxxxxkkk",
		".kkkkkkkkkk.",
		"..kffffffk..",
		"..kfeffefk..",
		"..kffffffk..",
		".kPkkkkkkPk.",
		"kPPPPPPPPPPk",
		"kpPPPPPPPPpk",
		".kpppPPpppk.",
		"..kkkkkkkk..",
	],
	"ghost": [
		"...kkkkkk...",
		"..kwwwwwwk..",
		".kwwwwwwwwk.",
		".kwkkwwkkwk.",
		".kwkkwwkkwk.",
		".kwwwwwwwwk.",
		".kwwwwwwwwk.",
		".kwwwwwwwwk.",
		".kwkwwwwkwk.",
		".kk.kwwk.kk.",
		".....kk.....",
	],
	"shambler": [
		"...kkkkkk...",
		"..kssssssk..",
		".kssssssssk.",
		".ksrssssrsk.",
		".kssssssssk.",
		".kSkkkkkkSk.",
		"..kSSSSSSk..",
		"ksOOOOOOOOsk",
		"kSkOOOOOOkSk",
		".k.OROORO.k.",
		"...kRkkRk...",
		"...kk..kk...",
	],
	"bat": [
		"k............k",
		"Uk..........kU",
		"uUk..kkkk..kUu",
		"uuUkkuuuukkUuu",
		".uuUuruuruUuu.",
		"..kUuuuuuuUk..",
		"....kUuuUk....",
		".....kkkk.....",
	],
	"bat_1": [
		".....kkkk.....",
		"....kuuuuk....",
		"...kuruuruk...",
		".kkUuuuuuuUkk.",
		"kuuUUuuuuUUuuk",
		"uuk.kUuuUk.kuu",
		"Uk...kkkk...kU",
		"k............k",
	],
	"ghoul": [
		"......kkkkkkkk......",
		"....kkRRRRRRRRkk....",
		"...kRRRRRRRRRRRRk...",
		"..kRRrrrrrrrrrrRRk..",
		"..kRrrrrrrrrrrrrRk..",
		".kRrrerrrrrrrrerrRk.",
		".kRrrrrrrrrrrrrrrRk.",
		".kRrkwkwkwwkwkwkrRk.",
		".kRrrkkkkkkkkkkrrRk.",
		"kRRrrrrrrrrrrrrrrRRk",
		"kRrrrrrrrrrrrrrrrrRk",
		"krRkrrrrrrrrrrrrkRrk",
		"krRkrrrrrrrrrrrrkRrk",
		"kwwkRrrrrrrrrrrRkwwk",
		".kk.kRrrrrrrrrRk.kk.",
		"....kRRrrrrrrRRk....",
		"....kRRRRRRRRRRk....",
		"....kRRkkkkkkRRk....",
		"....kRRk....kRRk....",
		"....kkkk....kkkk....",
	],
	"cultist": [
		"....kkkk....",
		"...kmmmmk...",
		"..kmmmmmmk..",
		"..kmkkkkmk..",
		".kmkekkekmk.",
		".kmkkkkkkmk.",
		".kmmkkkkmmk.",
		"kmmmmmmmmmmk",
		"kMmmgmmgmmMk",
		"kMmmmmmmmmMk",
		"kMMmmmmmmMMk",
		".kMMmmmmMMk.",
		".kMMMMMMMMk.",
		"..kkkkkkkk..",
	],
	"mire_crawler": [
		"..k.kk.k..",
		"...kkkk...",
		"..knnnnk..",
		".knennenk.",
		"knnnnnnnnk",
		"kNnNnnNnNk",
		"k.kNNNNk.k",
		".k.kkkk.k.",
	],
	"plague_spitter": [
		"...kkkkkk...",
		"..kaaaaaak..",
		".kaaaaaaaak.",
		".kaeaaaaeak.",
		"kaaaaaaaaaak",
		"kaAkkkkkkAak",
		"kaAkvvvvkAak",
		"kaAAkkkkAAak",
		"kAaaaaaaaaAk",
		".kAAaaaaAAk.",
		"..kAAAAAAk..",
		"...kkkkkk...",
	],
	"flame_imp": [
		"k........k",
		"ok..kk..ko",
		".kkooookk.",
		"kOkoyyokOk",
		"kOoeooeoOk",
		".kooooook.",
		"..kOooOk..",
		".kOkookOk.",
		".k.kOOk.k.",
		"....kk....",
	],
	"flame_imp_1": [
		"..........",
		"k...kk...k",
		"okkooookko",
		"kOkoyyokOk",
		"kOoeooeoOk",
		".kooooook.",
		"..kOooOk..",
		".kOkookOk.",
		"..kkOOkk..",
		"....kk....",
	],
	"fallen_paladin": [
		"......kkkkkk......",
		".....kLllllLk.....",
		"....kLllllllLk....",
		"....kLllllllLk....",
		"....kkooooookk....",
		"....kLllllllLk....",
		"...kkLLLLLLLLkk...",
		".kkllkLllllLkllkk.",
		"kllllkLlgglLkllllk",
		"kLLLLkLlgglLkLLLLk",
		"kLLkkLLlgglLLkkLLk",
		".kk.kLLllllLLk.kk.",
		"....kLLllllLLk....",
		"....kLLLLLLLLk....",
		"....kLLkkkkLLk....",
		"....kLLk..kLLk....",
		"....kLLk..kLLk....",
		"....kkkk..kkkk....",
	],
	"bone_warden": [
		"k......................k",
		"kk....................kk",
		".kBk................kBk.",
		".kBBk..............kBBk.",
		"..kBBk..kkkkkkkk..kBBk..",
		"...kBBkkbbbbbbbbkkBBk...",
		"....kkbbbbbbbbbbbbkk....",
		"....kbbbbbbbbbbbbbbk....",
		"...kbbbbbbbbbbbbbbbbk...",
		"...kbbkkkkbbbbkkkkbbk...",
		"...kbbkrrkbbbbkrrkbbk...",
		"...kbbkkkkbbbbkkkkbbk...",
		"...kbbbbbbbkkbbbbbbbk...",
		"...kBbbbbbbbbbbbbbbBk...",
		"....kBbbbbbbbbbbbbBk....",
		"....kBkwkwkwwkwkwkBk....",
		"....kBkkkkkkkkkkkkBk....",
		".....kBbbbbbbbbbbBk.....",
		"......kkBBBBBBBBkk......",
		"........kkkkkkkk........",
		"...kk.kKKKKKKKKKKk.kk...",
		"..kKKkKKKKKKKKKKKKkKKk..",
		".kKKKKKKKKKKKKKKKKKKKKk.",
		".kkkkkkkkkkkkkkkkkkkkkk.",
	],
	"mire_hag": [
		"...........kk...........",
		"..........kxxk..........",
		".........kxxxxk.........",
		".........kxxxxk.........",
		"........kxxxxxxk........",
		"........kxxxxxxk........",
		".......kxxxxxxxxk.......",
		"..kkkkkkxxxxxxxxkkkkkk..",
		".kxxxxxxxxxxxxxxxxxxxxk.",
		"..kkkkkkkkkkkkkkkkkkkk..",
		"...kNNkhhhhhhhhhhkNNk...",
		"..kNNkhhhhhhhhhhhhkNNk..",
		"..kNNkhehhhhhhhhehkNNk..",
		"..kNNkhhhhhHHhhhhhkNNk..",
		"..kNNkhhhhhHHhhhhhkNNk..",
		"..kNNkhkkkkkkkkkkhkNNk..",
		"..kNNkhhhwhhhhwhhhkNNk..",
		"..kNNNkhhhhhhhhhhkNNNk..",
		"...kNNNkkkhhhhkkkNNNk...",
		"...knnnnkkkkkkkknnnnk...",
		"..knnnnnnnnnnnnnnnnnnk..",
		".knnNnnnnnnnnnnnnnnNnnk.",
		".knNNnnnnnnnnnnnnnnNNnk.",
		".kkkkkkkkkkkkkkkkkkkkkk.",
	],
	"ashen_bishop": [
		"..........kkkk..........",
		".........kRRRRk.........",
		"........kRRRRRRk........",
		"........kRRggRRk........",
		".......kRRRggRRRk.......",
		".......kRggggggRk.......",
		".......kRRRggRRRk.......",
		".......kRRRggRRRk.......",
		".......kggggggggk.......",
		"......kbbbbbbbbbbk......",
		"......kbkobbbbokbk......",
		"......kbbbbbbbbbbk......",
		"......kbbkkkkkkbbk......",
		".......kbbbbbbbbk.......",
		"....kkkkkwwwwwwkkkkk....",
		"...kwwwwwwgwwgwwwwwwk...",
		"..kwwwwwwwgwwgwwwwwwwk..",
		"..kwwwKwwwgwwgwwwKwwwk..",
		"..kwwwwwwwgwwgwwwwwwwk..",
		"..kwwwwwwwgwwgwwwwwwwk..",
		"..kKwwwwwwgwwgwwwwwwKk..",
		"..kKKwwwwwgwwgwwwwwKKk..",
		"..kKKKwwwwggggwwwwKKKk..",
		"..kkkkkkkkkkkkkkkkkkkk..",
	],
	"gem": [
		"..k..",
		".ktk.",
		"kttTk",
		".kTk.",
		"..k..",
	],
	"gem_big": [
		"...k...",
		"..kwk..",
		".kvvVk.",
		"kvvvVVk",
		".kvVVk.",
		"..kVk..",
		"...k...",
	],
	"coin": [
		".kkk.",
		"kyygk",
		"kygOk",
		"kgOOk",
		".kkk.",
	],
	"coin_big": [
		"..kkk..",
		".kyyyk.",
		"kyyggOk",
		"kyggOOk",
		"kygOOOk",
		".kgOOk.",
		"..kkk..",
	],
	"skull": [
		".kkkk.",
		"kbbbbk",
		"kbkkbk",
		"kbbbbk",
		".kwwk.",
		"..kk..",
	],
}

const TINT_CHAR: String = "P"
const TINT_SHADE_CHAR: String = "p"

static var _cache: Dictionary[String, ImageTexture] = {}


static func has_sprite(sprite: String) -> bool:
	return SPRITES.has(sprite)


static func size_of(sprite: String) -> Vector2i:
	var rows: Array = SPRITES[sprite]
	return Vector2i(String(rows[0]).length(), rows.size())


## The sprite as a texture. `tint` recolors the P/p pixels; `flash` makes every
## visible pixel white (hit flash).
static func texture(sprite: String, tint: Color = Color.WHITE, flash: bool = false) -> ImageTexture:
	var key := "%s|%s|%s" % [sprite, tint.to_html(), flash]
	if _cache.has(key):
		return _cache[key]
	var rows: Array = SPRITES[sprite]
	var image := Image.create(String(rows[0]).length(), rows.size(), false, Image.FORMAT_RGBA8)
	var shade := tint.darkened(0.35)
	for y: int in rows.size():
		var row: String = rows[y]
		for x: int in row.length():
			var ch := row[x]
			var color: Color
			if ch == TINT_CHAR:
				color = tint
			elif ch == TINT_SHADE_CHAR:
				color = shade
			else:
				color = PALETTE.get(ch, Color(0, 0, 0, 0))
			if flash and color.a > 0.0:
				color = Color.WHITE
			image.set_pixel(x, y, color)
	var built := ImageTexture.create_from_image(image)
	_cache[key] = built
	return built


## Draws a sprite centered on `center` from a CanvasItem's _draw().
static func draw(canvas: CanvasItem, sprite: String, center: Vector2, tint: Color = Color.WHITE,
		flash: bool = false, flip: bool = false, scale: float = 1.0, modulate: Color = Color.WHITE) -> void:
	var tex := texture(sprite, tint, flash)
	var size := Vector2(tex.get_size()) * scale
	var rect := Rect2((center - size / 2.0).round(), size)
	if flip:
		rect.position.x += size.x
		rect.size.x = -size.x
	canvas.draw_texture_rect(tex, rect, false, modulate)
