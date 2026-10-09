class_name MusicComposer
extends RefCounted
## Turns a text score (see Tracks) into one seamless looping buffer of samples.
## Pure and deterministic: same score = same music. Slow-ish (a few seconds per
## track), so Music runs it on a background thread.
##
## Metal scores add distorted power-chord riffs ("guitar"), crash cymbals and an
## overdriven lead; see Tracks for the extra keys.

const STEPS_PER_BAR: int = 16
## Peak level after mixing (leaves headroom for sound effects).
const TARGET_PEAK: float = 0.7


static func render(score: Dictionary) -> PackedFloat32Array:
	return _normalize(render_raw(score))


## The mix before it's normalized (for checking the balance between parts).
static func render_raw(score: Dictionary) -> PackedFloat32Array:
	var step_seconds := 60.0 / float(score["bpm"]) / 4.0
	var step_samples := int(step_seconds * Synth.MIX_RATE)
	var chords: Array = score["chords"]
	var length := chords.size() * STEPS_PER_BAR * step_samples
	var mix := PackedFloat32Array()
	mix.resize(length)
	var root: int = score["root"]
	var scale: Array = score["scale"]
	var lead_wave := Synth.Wave.get(score["lead_wave"], Synth.Wave.TRIANGLE) as Synth.Wave
	var arp_wave := Synth.Wave.get(score["arp_wave"], Synth.Wave.SQUARE) as Synth.Wave
	var lead := PackedFloat32Array()
	lead.resize(length)
	# Drum hits sound the same every time: render each once.
	var drum_cache := {}
	# Metal tracks use a short, punchy kick so fast double-kick patterns stay clear.
	var tight: bool = score.get("tight_kick", false)
	var kick_seconds := 0.09 if tight else 0.16
	var kick_hz := 150.0 if tight else 130.0
	var kick_volume := 0.4 if tight else 0.5
	var bass_volume: float = score.get("bass_volume", 0.32)

	for bar: int in chords.size():
		var bar_start := bar * STEPS_PER_BAR * step_samples
		var triad := chord_notes(root, scale, chords[bar])
		if score["pad"]:
			for note: int in triad:
				var hz := Synth.midi_to_hz(note)
				Synth.add_at(mix, Synth.voice(Synth.Wave.SAW, hz, hz, step_seconds * STEPS_PER_BAR, 0.045,
					0.25, 0.6, 0.08), bar_start)
		_pattern(mix, score["bass"], bar_start, step_samples, func(symbol: String) -> PackedFloat32Array:
			var note := triad[0] - 12 if symbol == "x" else triad[2] - 12
			var hz := Synth.midi_to_hz(note)
			return Synth.voice(Synth.Wave.TRIANGLE, hz, hz, step_seconds * 1.8, bass_volume, 0.004, 1.2, 0.5))
		_pattern(mix, score["arp"], bar_start, step_samples, func(symbol: String) -> PackedFloat32Array:
			var index := symbol.to_int()
			var note := triad[0] + 12 if index == 3 else triad[clampi(index, 0, 2)]
			var hz := Synth.midi_to_hz(note + 12)
			return Synth.voice(arp_wave, hz, hz, step_seconds * 0.9, 0.06, 0.003, 2.0, 0.3))
		_melody(lead, score["lead"][bar], bar_start, step_samples, step_seconds, root, scale, lead_wave)
		_pattern(mix, "x" if score.get("crash_bars", []).has(bar) else "", bar_start, step_samples,
			func(_symbol: String) -> PackedFloat32Array:
				return Synth.voice(Synth.Wave.NOISE, 8000.0, 5000.0, 1.4, 0.13, 0.002, 1.6, 0.7), drum_cache, "crash")
		_pattern(mix, score["kick"], bar_start, step_samples, func(_symbol: String) -> PackedFloat32Array:
			return Synth.voice(Synth.Wave.SINE, kick_hz, 40.0, kick_seconds, kick_volume, 0.002, 2.0), drum_cache, "kick")
		_pattern(mix, score["snare"], bar_start, step_samples, func(_symbol: String) -> PackedFloat32Array:
			return Synth.mix([Synth.voice(Synth.Wave.NOISE, 5000.0, 2000.0, 0.13, 0.22, 0.002, 2.0, 0.55),
				Synth.voice(Synth.Wave.SINE, 210.0, 150.0, 0.08, 0.2, 0.002, 2.0)]), drum_cache, "snare")
		_pattern(mix, score["hat"], bar_start, step_samples, func(_symbol: String) -> PackedFloat32Array:
			return Synth.voice(Synth.Wave.NOISE, 9000.0, 9000.0, 0.035, 0.06, 0.001, 3.0), drum_cache, "hat")
	if score.has("guitar"):
		_guitar(mix, score, step_seconds, step_samples)

	# The lead gets a soft echo, three steps behind (and crunch in metal tracks).
	if score.get("lead_drive", 0.0) > 0.0:
		lead = Synth.lowpass(Synth.drive(lead, score["lead_drive"]), 0.35, 0.75)
	Synth.add_at(mix, Synth.echo(lead, step_seconds * 3.0, 0.28, 2), 0)
	return _wrap_tail(mix, length)


## Metal rhythm guitar. "guitar" is one 16-step riff for every bar, or one per
## bar. Digits are scale steps above the bar's chord root (0 = the chord's
## root), each played as a distorted power chord (root, fifth, octave). A
## digit alone is a short palm-muted chug; "-" after it lets the chord ring.
static func _guitar(into: PackedFloat32Array, score: Dictionary, step_seconds: float, step_samples: int) -> void:
	var chords: Array = score["chords"]
	var scale: Array = score["scale"]
	var root: int = score["root"]
	var gain: float = score.get("drive", 6.0)
	var cache := {}
	for bar: int in chords.size():
		var riff: String = score["guitar"] if score["guitar"] is String else score["guitar"][bar]
		var bar_start := bar * STEPS_PER_BAR * step_samples
		var step := 0
		while step < riff.length():
			var symbol := riff[step]
			if not symbol.is_valid_int():
				step += 1
				continue
			var held := 1
			while step + held < riff.length() and riff[step + held] == "-":
				held += 1
			var note := root + scale_note(scale, int(chords[bar]) + symbol.to_int())
			var key := "%d:%d" % [note, held]
			if not cache.has(key):
				cache[key] = power_chord(note, step_seconds * held, held == 1, gain)
			Synth.add_at(into, cache[key], bar_start + step * step_samples)
			step += held


## One distorted power chord: two slightly detuned saws per note (root, fifth,
## octave), clipped, then filtered like a guitar cabinet. Muted chugs are short
## and dark; open chords ring and are brighter.
static func power_chord(note: int, seconds: float, muted: bool, gain: float) -> PackedFloat32Array:
	var length := seconds * (0.85 if muted else 1.0)
	var parts: Array[PackedFloat32Array] = []
	for interval: int in [0, 7, 12]:
		var hz := Synth.midi_to_hz(note + interval)
		for detune: float in [0.996, 1.004]:
			parts.append(Synth.voice(Synth.Wave.SAW, hz * detune, hz * detune, length, 0.2, 0.002,
				3.0 if muted else 0.6))
	var crunch := Synth.drive(Synth.mix(parts), gain)
	return Synth.lowpass(crunch, 0.16 if muted else 0.24, 0.35 if muted else 0.3)


## The three notes (MIDI) of the chord built on scale degree `degree`.
static func chord_notes(root: int, scale: Array, degree: int) -> Array[int]:
	var notes: Array[int] = []
	for offset: int in [0, 2, 4]:
		notes.append(root + 12 + scale_note(scale, degree + offset))
	return notes


## Semitones above the root for a scale step (steps past 6 go up octaves).
static func scale_note(scale: Array, step: int) -> int:
	return int(scale[step % scale.size()]) + 12 * (step / scale.size())


## Places one sound per non-"." symbol of a 16-step pattern. With a `cache`,
## each symbol's sound is rendered once (under `cache_key`) and reused.
static func _pattern(into: PackedFloat32Array, pattern: String, bar_start: int, step_samples: int, make: Callable,
		cache: Variant = null, cache_key: String = "") -> void:
	for step: int in pattern.length():
		var symbol := pattern[step]
		if symbol == ".":
			continue
		var sound: PackedFloat32Array
		if cache is Dictionary:
			var key := cache_key + symbol
			if not cache.has(key):
				cache[key] = make.call(symbol)
			sound = cache[key]
		else:
			sound = make.call(symbol)
		Synth.add_at(into, sound, bar_start + step * step_samples)


static func _melody(into: PackedFloat32Array, line: String, bar_start: int, step_samples: int, step_seconds: float,
		root: int, scale: Array, wave: Synth.Wave) -> void:
	var step := 0
	while step < line.length():
		var symbol := line[step]
		if not symbol.is_valid_int():
			step += 1
			continue
		var held := 1
		while step + held < line.length() and line[step + held] == "-":
			held += 1
		var hz := Synth.midi_to_hz(root + 24 + scale_note(scale, symbol.to_int()))
		var note := Synth.voice(wave, hz, hz, step_seconds * held, 0.12, 0.01, 0.8, 0.35, 5.0, 0.008)
		Synth.add_at(into, note, bar_start + step * step_samples)
		step += held


## Sounds that ring past the loop's end are folded back onto its start, so the
## loop point is seamless.
static func _wrap_tail(buffer: PackedFloat32Array, length: int) -> PackedFloat32Array:
	for i: int in range(length, buffer.size()):
		buffer[i % length] += buffer[i]
	buffer.resize(length)
	return buffer


static func _normalize(buffer: PackedFloat32Array) -> PackedFloat32Array:
	var peak := 0.0
	for value: float in buffer:
		peak = maxf(peak, absf(value))
	if peak > 0.0:
		var gain := TARGET_PEAK / peak
		for i: int in buffer.size():
			buffer[i] *= gain
	return buffer
