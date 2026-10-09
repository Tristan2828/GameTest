class_name Synth
extends RefCounted
## A tiny software synthesizer that renders sounds into float buffers
## (-1..1 samples). Used for sound effects (Sfx) and music (Music), so the game
## needs no audio files and every sound is defined as text.
##
## A voice is: a waveform sweeping from one pitch to another, with an attack /
## decay envelope, optional vibrato, and a one-pole low-pass filter (lower
## `brightness` = softer, duller sound).

enum Wave { SQUARE, SAW, SINE, TRIANGLE, NOISE }

const MIX_RATE: int = 22050


## Renders one voice. `brightness` 0..1 (1 = unfiltered). Returns samples.
static func voice(wave: Wave, start_hz: float, end_hz: float, seconds: float, volume: float,
		attack: float = 0.004, decay_power: float = 2.0, brightness: float = 1.0,
		vibrato_hz: float = 0.0, vibrato_depth: float = 0.0, seed_value: int = 1) -> PackedFloat32Array:
	var samples := maxi(int(seconds * MIX_RATE), 1)
	var out := PackedFloat32Array()
	out.resize(samples)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var phase := 0.0
	var noise_value := 0.0
	var filtered := 0.0
	var smoothing := clampf(brightness, 0.01, 1.0)
	var attack_samples := maxf(attack * MIX_RATE, 1.0)
	for i: int in samples:
		var t := float(i) / samples
		var frequency := lerpf(start_hz, end_hz, t)
		if vibrato_hz > 0.0:
			frequency *= 1.0 + sin(TAU * vibrato_hz * i / MIX_RATE) * vibrato_depth
		var previous_phase := phase
		phase = fmod(phase + frequency / MIX_RATE, 1.0)
		var value := 0.0
		match wave:
			Wave.SQUARE:
				value = 1.0 if phase < 0.5 else -1.0
			Wave.SAW:
				value = phase * 2.0 - 1.0
			Wave.SINE:
				value = sin(phase * TAU)
			Wave.TRIANGLE:
				value = 4.0 * absf(phase - 0.5) - 1.0
			Wave.NOISE:
				# New random value each cycle: higher "frequency" = hissier noise.
				if phase < previous_phase or i == 0:
					noise_value = rng.randf_range(-1.0, 1.0)
				value = noise_value
		filtered += (value - filtered) * smoothing
		var envelope := minf(i / attack_samples, 1.0) * pow(1.0 - t, decay_power)
		out[i] = filtered * envelope * volume
	return out


## Plays buffers one after another.
static func sequence(parts: Array[PackedFloat32Array]) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for part: PackedFloat32Array in parts:
		out.append_array(part)
	return out


## Plays buffers at the same time (layering).
static func mix(parts: Array[PackedFloat32Array]) -> PackedFloat32Array:
	var length := 0
	for part: PackedFloat32Array in parts:
		length = maxi(length, part.size())
	var out := PackedFloat32Array()
	out.resize(length)
	for part: PackedFloat32Array in parts:
		for i: int in part.size():
			out[i] += part[i]
	return out


## Adds `buffer` into `into` starting at sample `offset` (grows `into` if needed).
static func add_at(into: PackedFloat32Array, buffer: PackedFloat32Array, offset: int) -> void:
	if offset + buffer.size() > into.size():
		into.resize(offset + buffer.size())
	for i: int in buffer.size():
		into[offset + i] += buffer[i]


## A fading echo tail: each repeat `delay` seconds later and `feedback` quieter.
static func echo(buffer: PackedFloat32Array, delay: float, feedback: float, repeats: int) -> PackedFloat32Array:
	var out := buffer.duplicate()
	var step := int(delay * MIX_RATE)
	var gain := 1.0
	for r: int in range(1, repeats + 1):
		gain *= feedback
		var faded := buffer.duplicate()
		for i: int in faded.size():
			faded[i] *= gain
		add_at(out, faded, step * r)
	return out


## Converts samples to a playable 16-bit stream (clipping safely). With `loop`,
## the stream repeats seamlessly (music).
static func to_stream(buffer: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buffer.size() * 2)
	for i: int in buffer.size():
		data.encode_s16(i * 2, int(clampf(buffer[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = buffer.size()
	return stream


static func midi_to_hz(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)
