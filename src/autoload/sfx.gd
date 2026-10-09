extends Node
## Sound effects (reach it anywhere as `Sfx`): `Sfx.play("coin")`.
##
## Every sound is synthesized here at startup from simple waveforms and noise
## (retro "sfxr" style), so there are no audio files to manage and every sound
## is tweakable as text. Placeholder quality: swap in real recordings later by
## loading files into `_streams` instead.

const MIX_RATE: int = 22050
const VOICES: int = 16
const BUS: StringName = &"SFX"

enum Wave { SQUARE, SAW, SINE, NOISE }

var _streams: Dictionary[StringName, AudioStreamWAV] = {}
## Minimum seconds between two plays of the same sound (keeps hordes listenable).
var _min_gap: Dictionary[StringName, float] = {
	&"shoot": 0.06, &"hit": 0.04, &"death": 0.03, &"gem": 0.03, &"enemy_shot": 0.08,
}
var _last_played: Dictionary[StringName, float] = {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for i: int in VOICES:
		var voice := AudioStreamPlayer.new()
		voice.bus = BUS
		add_child(voice)
		_voices.append(voice)
	_build_sounds()


## Plays a sound. `volume_db` adjusts loudness; pitch gets a little random variety.
func play(sound: StringName, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream: AudioStreamWAV = _streams.get(sound)
	if stream == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_played.get(sound, -1.0) < _min_gap.get(sound, 0.0):
		return
	_last_played[sound] = now
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	voice.stream = stream
	voice.volume_db = volume_db
	voice.pitch_scale = pitch * _rng.randf_range(0.95, 1.05)
	voice.play()


func has_sound(sound: StringName) -> bool:
	return _streams.has(sound)


func _build_sounds() -> void:
	_streams[&"shoot"] = _tone(Wave.SQUARE, 880.0, 440.0, 0.05, 0.18)
	_streams[&"hit"] = _tone(Wave.NOISE, 2000.0, 800.0, 0.03, 0.25)
	_streams[&"death"] = _tone(Wave.NOISE, 900.0, 120.0, 0.12, 0.35)
	_streams[&"hurt"] = _tone(Wave.SQUARE, 330.0, 90.0, 0.25, 0.4)
	_streams[&"gem"] = _tone(Wave.SINE, 1200.0, 1700.0, 0.06, 0.25)
	_streams[&"coin"] = _join([_tone(Wave.SINE, 988.0, 988.0, 0.05, 0.3), _tone(Wave.SINE, 1319.0, 1319.0, 0.12, 0.3)])
	_streams[&"level_up"] = _join([
		_tone(Wave.SQUARE, 523.0, 523.0, 0.08, 0.25), _tone(Wave.SQUARE, 659.0, 659.0, 0.08, 0.25),
		_tone(Wave.SQUARE, 784.0, 784.0, 0.08, 0.25), _tone(Wave.SQUARE, 1047.0, 1047.0, 0.18, 0.25)])
	_streams[&"pickup"] = _join([
		_tone(Wave.SINE, 660.0, 880.0, 0.08, 0.3), _tone(Wave.SINE, 880.0, 1320.0, 0.15, 0.3)])
	_streams[&"bomb"] = _tone(Wave.NOISE, 400.0, 40.0, 0.6, 0.6)
	_streams[&"boss"] = _tone(Wave.SAW, 70.0, 45.0, 1.2, 0.45)
	_streams[&"dash"] = _tone(Wave.NOISE, 3000.0, 600.0, 0.1, 0.15)
	_streams[&"enemy_shot"] = _tone(Wave.SQUARE, 300.0, 220.0, 0.07, 0.12)
	_streams[&"victory"] = _join([
		_tone(Wave.SQUARE, 392.0, 392.0, 0.12, 0.25), _tone(Wave.SQUARE, 523.0, 523.0, 0.12, 0.25),
		_tone(Wave.SQUARE, 659.0, 659.0, 0.12, 0.25), _tone(Wave.SQUARE, 784.0, 784.0, 0.4, 0.25)])
	_streams[&"defeat"] = _join([
		_tone(Wave.SAW, 330.0, 300.0, 0.25, 0.3), _tone(Wave.SAW, 262.0, 240.0, 0.25, 0.3),
		_tone(Wave.SAW, 196.0, 120.0, 0.6, 0.3)])


## One synthesized sound: a wave sweeping from `start_hz` to `end_hz` over
## `seconds`, with a quick attack and a fading tail. Returns 16-bit mono PCM.
func _tone(wave: Wave, start_hz: float, end_hz: float, seconds: float, volume: float) -> AudioStreamWAV:
	var samples := int(seconds * MIX_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var phase := 0.0
	var noise_value := 0.0
	var noise_rng := RandomNumberGenerator.new()
	noise_rng.seed = int(start_hz * 1000.0 + seconds * 10.0)
	for i: int in samples:
		var t := float(i) / samples
		var frequency := lerpf(start_hz, end_hz, t)
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
			Wave.NOISE:
				# New random value each cycle: higher "frequency" = hissier noise.
				if phase < previous_phase or i == 0:
					noise_value = noise_rng.randf_range(-1.0, 1.0)
				value = noise_value
		var attack := minf(float(i) / (MIX_RATE * 0.004), 1.0)
		var envelope := attack * pow(1.0 - t, 2.0)
		data.encode_s16(i * 2, int(clampf(value * envelope * volume, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream


## Plays sounds one after another (arpeggios).
func _join(parts: Array[AudioStreamWAV]) -> AudioStreamWAV:
	var data := PackedByteArray()
	for part: AudioStreamWAV in parts:
		data.append_array(part.data)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
