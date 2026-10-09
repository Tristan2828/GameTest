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

const ALL: Dictionary[StringName, Dictionary] = {
	&"menu": MENU, &"crypt": CRYPT, &"marsh": MARSH, &"cathedral": CATHEDRAL, &"boss": BOSS,
}
