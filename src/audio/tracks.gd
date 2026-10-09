class_name Tracks
extends RefCounted
## The game's music, written as text scores (rendered by MusicComposer).
##
## Each track loops 8 bars of 16 steps (sixteenth notes):
## - "chords": one scale degree per bar (0 = the key's root chord, 3 = fourth...).
## - "bass": "x" = chord root (low), "o" = chord fifth, "." = rest.
## - "arp": digits 0-2 = chord tones, 3 = root an octave up, "." = rest.
## - "lead": one 16-step string per bar. Digits are scale steps above the root
##   (0 = root, 7 = octave, 8/9 = higher), "-" holds the previous note, "." rests.
## - "kick" / "snare" / "hat": "x" = hit.
## - "lead_wave" / "arp_wave": Synth.Wave names; "pad": sustained chords on/off.
##
## Metal tracks (the custom game's Soundtrack option) add:
## - "guitar": distorted power-chord riff, one 16-step string for every bar or
##   one per bar. Digits = scale steps above the bar's chord root, a lone digit
##   is a palm-muted chug, "-" lets the chord ring.
## - "drive": guitar distortion; "lead_drive": crunch on the lead;
##   "bass_volume": quieter bass under the guitars (default 0.32).
## - "crash_bars": bars that start with a crash cymbal; "tight_kick": a short
##   kick for double-bass patterns.

const MINOR: Array[int] = [0, 2, 3, 5, 7, 8, 10]
const HARMONIC_MINOR: Array[int] = [0, 2, 3, 5, 7, 8, 11]
const PHRYGIAN: Array[int] = [0, 1, 3, 5, 7, 8, 10]

## Menu, lobby, shop and run end: slow and sparse.
const MENU: Dictionary = {
	"bpm": 70, "root": 50, "scale": MINOR,
	"chords": [0, 5, 3, 4, 0, 5, 6, 4],
	"bass": "x.......o.......",
	"arp": "0...1...2...1...",
	"arp_wave": "SINE",
	"lead_wave": "TRIANGLE",
	"pad": true,
	"lead": [
		"4-------2---3---", "4-------........", "5---4---3---2---", "1-------........",
		"4-------2---3---", "4-----5-7-------", "6---5---4---3---", "4-------........",
	],
	"kick": "", "snare": "", "hat": "",
}

const CRYPT: Dictionary = {
	"bpm": 100, "root": 45, "scale": MINOR,
	"chords": [0, 3, 5, 4, 0, 3, 6, 4],
	"bass": "x.x.o.x.x.x.o.x.",
	"arp": "0.1.2.3.2.1.0.1.",
	"arp_wave": "SQUARE",
	"lead_wave": "TRIANGLE",
	"pad": true,
	"lead": [
		"7---6-5-4---2---", "4---5-4-2-------", "7---6-5-4---5-6-", "7-------6---4---",
		"7---6-5-4---2---", "4---5-4-2---0---", "2---4---5---6---", "7-------........",
	],
	"kick": "x.......x.x.....", "snare": "....x.......x...", "hat": "x.x.x.x.x.x.x.x.",
}

const MARSH: Dictionary = {
	"bpm": 84, "root": 52, "scale": PHRYGIAN,
	"chords": [0, 1, 0, 6, 0, 1, 3, 0],
	"bass": "x..x..x...x..o..",
	"arp": "0..1..2..1..0...",
	"arp_wave": "TRIANGLE",
	"lead_wave": "SINE",
	"pad": true,
	"lead": [
		"0---1---0-------", "3---2---1---0---", "0---1---3---4---", "3-------........",
		"4---3---1---0---", "1---3---4---5---", "4---3---1---3---", "0-------........",
	],
	"kick": "x.....x...x.....", "snare": "........x.......", "hat": "..x...x...x...x.",
}

const CATHEDRAL: Dictionary = {
	"bpm": 112, "root": 48, "scale": HARMONIC_MINOR,
	"chords": [0, 5, 3, 4, 0, 5, 1, 4],
	"bass": "x.x.x.x.o.o.o.o.",
	"arp": "0.1.2.3.2.1.0.1.",
	"arp_wave": "SAW",
	"lead_wave": "SQUARE",
	"pad": true,
	"lead": [
		"7---7-6-5---4---", "6-------4-------", "5---5-4-3---2---", "4-------6---7---",
		"7---9-8-7---6---", "5-------7-------", "4---3---2---1---", "6-------........",
	],
	"kick": "x...x...x...x...", "snare": "....x.......x..x", "hat": "x.xxx.xxx.xxx.xx",
}

## Boss fights (any stage): fast and relentless.
const BOSS: Dictionary = {
	"bpm": 140, "root": 50, "scale": HARMONIC_MINOR,
	"chords": [0, 0, 5, 5, 3, 3, 4, 4],
	"bass": "x.xox.xox.xox.xo",
	"arp": "0.1.2.3.0.1.2.3.",
	"arp_wave": "SQUARE",
	"lead_wave": "SAW",
	"pad": false,
	"lead": [
		"0-0-3-2-0---7-6-", "5-4-3-2-1---0---", "0-0-3-2-0---7-9-", "8-7-6-5-6-------",
		"7-7-6-5-4---3-4-", "5---4---3---2---", "4-5-6-7-8-9-7-6-", "7-------6-------",
	],
	"kick": "x.x.x.x.x.x.x.x.", "snare": "....x.......x.x.", "hat": "xxxxxxxxxxxxxxxx",
}

## --- Metal soundtrack ---

## The Crypt, metal: an E minor gallop with a howling lead.
const METAL_CRYPT: Dictionary = {
	"bpm": 150, "root": 40, "scale": MINOR,
	"chords": [0, 0, 5, 6, 0, 0, 3, 4],
	"guitar": [
		"0.000.000.000.00", "0.000.000.003-2-", "0.000.000.000.00", "0.000.00-...2-1-",
		"0.000.000.000.00", "0.000.000.003-2-", "0-------0.0.0.0.", "0-------2---1---",
	],
	"bass_volume": 0.16,
	"drive": 6.0,
	"bass": "x.xxx.xxx.xxx.xx",
	"arp": "",
	"arp_wave": "SQUARE",
	"lead_wave": "SAW",
	"lead_drive": 3.0,
	"pad": false,
	"lead": [
		"7-------6-5-4---", "5-------........", "7---6---5---7---", "8-------9-------",
		"7-------6-5-4---", "5-------4---3---", "2---3---4---5---", "4-------........",
	],
	"kick": "x.xxx.xxx.xxx.xx", "snare": "....x.......x...", "hat": "x.x.x.x.x.x.x.x.",
	"crash_bars": [0, 4], "tight_kick": true,
}

## The Bone Marsh, metal: slow, crushing doom in D Phrygian.
const METAL_MARSH: Dictionary = {
	"bpm": 76, "root": 38, "scale": PHRYGIAN,
	"chords": [0, 0, 1, 0, 0, 0, 6, 1],
	"guitar": [
		"0---------0-1---", "0-------3---1---", "0---------0.0.0.", "0-------........",
		"0---------0-1---", "0-------3---1---", "0-------1-------", "0---0.0.0---....",
	],
	"bass_volume": 0.16,
	"drive": 7.0,
	"bass": "x.......x.......",
	"arp": "",
	"arp_wave": "SINE",
	"lead_wave": "SAW",
	"lead_drive": 2.5,
	"pad": false,
	"lead": [
		"........0---1---", "3-------2---1---", "4---3---1---0---", "1-------........",
		"........7---8---", "7-------5---4---", "3---4---3---1---", "0-------........",
	],
	"kick": "x.......x.x.....", "snare": "........x.......", "hat": "x...x...x...x...",
	"crash_bars": [0, 2, 4, 6], "tight_kick": true,
}

## The Burning Cathedral, metal: fast neoclassical thrash in C harmonic minor.
const METAL_CATHEDRAL: Dictionary = {
	"bpm": 168, "root": 36, "scale": HARMONIC_MINOR,
	"chords": [0, 5, 3, 4, 0, 5, 1, 4],
	"guitar": [
		"0.00.00.0.00.00.", "0.00.00.0.00.2-.", "0.00.00.0.00.00.", "0.0.0.0.1-1-0---",
		"0.00.00.0.00.00.", "0.00.00.0.00.2-.", "0.00.00.0.00.00.", "0---0---0.0.0.0.",
	],
	"bass_volume": 0.16,
	"drive": 6.5,
	"bass": "x.x.x.x.x.x.x.x.",
	"arp": "",
	"arp_wave": "SQUARE",
	"lead_wave": "SAW",
	"lead_drive": 3.0,
	"pad": false,
	"lead": [
		"7-6-5-4-5-6-7-9-", "8-7-6-5-4---2---", "5-4-3-2-3-4-5-7-", "6-5-4-3-6-------",
		"9-8-7-6-7-8-9-.-", "8-7-6-5-7-------", "4-3-2-1-2-3-4-5-", "6-------........",
	],
	"kick": "x.x.x.x.x.x.x.x.", "snare": "....x.......x...", "hat": "xxxxxxxxxxxxxxxx",
	"crash_bars": [0, 4], "tight_kick": true,
}

## Boss fights, metal: tremolo-picked riffs over a blast beat.
const METAL_BOSS: Dictionary = {
	"bpm": 190, "root": 38, "scale": HARMONIC_MINOR,
	"chords": [0, 0, 5, 5, 3, 3, 4, 4],
	"guitar": [
		"0000000000000000", "0000000033332222", "0000000000000000", "0000000011110000",
		"0000000000000000", "0000000022221111", "0000000000000000", "0-------0-------",
	],
	"bass_volume": 0.16,
	"drive": 7.0,
	"bass": "x.x.x.x.x.x.x.x.",
	"arp": "",
	"arp_wave": "SQUARE",
	"lead_wave": "SAW",
	"lead_drive": 3.5,
	"pad": false,
	"lead": [
		"0-0-3-2-0---7-6-", "5-4-3-2-1---0---", "0-0-3-2-0---7-9-", "8-7-6-5-6-------",
		"7-7-6-5-4---3-4-", "5---4---3---2---", "4-5-6-7-8-9-7-6-", "7-------6-------",
	],
	"kick": "x.x.x.x.x.x.x.x.", "snare": ".x.x.x.x.x.x.x.x", "hat": "x...x...x...x...",
	"crash_bars": [0, 2, 4, 6], "tight_kick": true,
}

const ALL: Dictionary[StringName, Dictionary] = {
	&"menu": MENU, &"crypt": CRYPT, &"marsh": MARSH, &"cathedral": CATHEDRAL, &"boss": BOSS,
	&"metal_crypt": METAL_CRYPT, &"metal_marsh": METAL_MARSH, &"metal_cathedral": METAL_CATHEDRAL,
	&"metal_boss": METAL_BOSS,
}

## The custom game's Soundtrack choices (RunConfig.soundtrack is the index).
const SOUNDTRACKS: Array[String] = ["Classic", "Metal", "Metal boss fights", "Shuffle"]


## The track to play for a stage or boss track (`base`, e.g. &"crypt" or
## &"boss") with this soundtrack. Shuffle picks classic or metal per stage.
static func for_soundtrack(base: StringName, soundtrack: int, stage: int = 1) -> StringName:
	var metal := StringName("metal_" + base)
	if not ALL.has(metal):
		return base
	match soundtrack:
		1:
			return metal
		2:
			return metal if base == &"boss" else base
		3:
			return metal if (stage + (1 if base == &"boss" else 0)) % 2 == 0 else base
	return base
