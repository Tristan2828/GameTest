class_name MusicComposer
extends RefCounted
## Turns a text score (see Tracks) into one seamless looping buffer of samples.
## Pure and deterministic: same score = same music. Slow-ish (a few seconds per
## track), so Music runs it on a background thread.

const STEPS_PER_BAR: int = 16
## Peak level after mixing (leaves headroom for sound effects).
const TARGET_PEAK: float = 0.7


static func render(score: Dictionary) -> PackedFloat32Array:
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
			return Synth.voice(Synth.Wave.TRIANGLE, hz, hz, step_seconds * 1.8, 0.32, 0.004, 1.2, 0.5))
		_pattern(mix, score["arp"], bar_start, step_samples, func(symbol: String) -> PackedFloat32Array:
			var index := symbol.to_int()
			var note := triad[0] + 12 if index == 3 else triad[clampi(index, 0, 2)]
			var hz := Synth.midi_to_hz(note + 12)
			return Synth.voice(arp_wave, hz, hz, step_seconds * 0.9, 0.06, 0.003, 2.0, 0.3))
		_melody(lead, score["lead"][bar], bar_start, step_samples, step_seconds, root, scale, lead_wave)
		_pattern(mix, score["kick"], bar_start, step_samples, func(_symbol: String) -> PackedFloat32Array:
			return Synth.voice(Synth.Wave.SINE, 130.0, 40.0, 0.16, 0.5, 0.002, 2.0))
		_pattern(mix, score["snare"], bar_start, step_samples, func(_symbol: String) -> PackedFloat32Array:
			return Synth.mix([Synth.voice(Synth.Wave.NOISE, 5000.0, 2000.0, 0.13, 0.22, 0.002, 2.0, 0.55),
				Synth.voice(Synth.Wave.SINE, 210.0, 150.0, 0.08, 0.2, 0.002, 2.0)]))
		_pattern(mix, score["hat"], bar_start, step_samples, func(_symbol: String) -> PackedFloat32Array:
			return Synth.voice(Synth.Wave.NOISE, 9000.0, 9000.0, 0.035, 0.06, 0.001, 3.0))

	# The lead gets a soft echo, three steps behind.
	Synth.add_at(mix, Synth.echo(lead, step_seconds * 3.0, 0.28, 2), 0)
	return _normalize(_wrap_tail(mix, length))


## The three notes (MIDI) of the chord built on scale degree `degree`.
static func chord_notes(root: int, scale: Array, degree: int) -> Array[int]:
	var notes: Array[int] = []
	for offset: int in [0, 2, 4]:
		notes.append(root + 12 + scale_note(scale, degree + offset))
	return notes


## Semitones above the root for a scale step (steps past 6 go up octaves).
static func scale_note(scale: Array, step: int) -> int:
	return int(scale[step % scale.size()]) + 12 * (step / scale.size())


## Places one sound per non-"." symbol of a 16-step pattern.
static func _pattern(into: PackedFloat32Array, pattern: String, bar_start: int, step_samples: int, make: Callable) -> void:
	for step: int in pattern.length():
		var symbol := pattern[step]
		if symbol != ".":
			Synth.add_at(into, make.call(symbol), bar_start + step * step_samples)


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
