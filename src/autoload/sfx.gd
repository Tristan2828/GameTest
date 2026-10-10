extends Node
## Sound effects (reach it anywhere as `Sfx`): `Sfx.play(&"coin")`.
##
## Every sound is designed here with the Synth (waveforms, filters, layering,
## echo), so there are no audio files to manage and each sound is a few lines
## of text. To use a recorded sound instead, load it into `_streams`.

const VOICES: int = 16
const BUS: StringName = &"SFX"

var _streams: Dictionary[StringName, AudioStreamWAV] = {}
## Minimum seconds between two plays of the same sound (keeps hordes listenable).
var _min_gap: Dictionary[StringName, float] = {
	&"shoot": 0.06, &"hit": 0.04, &"death": 0.03, &"gem": 0.03, &"enemy_shot": 0.08, &"ui": 0.04,
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


## The raw samples of a sound (for tests and tools).
func samples_of(sound: StringName) -> int:
	var stream: AudioStreamWAV = _streams.get(sound)
	return stream.data.size() / 2 if stream != null else 0


func _build_sounds() -> void:
	var W := Synth.Wave
	# Your gun: a soft, short blip (it plays constantly, so it must not be harsh).
	_add(&"shoot", Synth.voice(W.SQUARE, 760.0, 520.0, 0.06, 0.16, 0.002, 2.0, 0.45))
	# Bullet hits: a tick of noise over a tiny thud.
	_add(&"hit", Synth.mix([
		Synth.voice(W.NOISE, 3000.0, 1200.0, 0.035, 0.18, 0.001, 2.0, 0.6),
		Synth.voice(W.SINE, 220.0, 120.0, 0.05, 0.25, 0.001, 2.0)]))
	# Enemy deaths: a crumbly burst with a low thump.
	_add(&"death", Synth.mix([
		Synth.voice(W.NOISE, 900.0, 90.0, 0.2, 0.28, 0.002, 1.5, 0.35),
		Synth.voice(W.SINE, 170.0, 55.0, 0.16, 0.35, 0.002, 2.0)]))
	# You got hit: a falling, wobbling buzz.
	_add(&"hurt", Synth.voice(W.SQUARE, 440.0, 110.0, 0.3, 0.35, 0.003, 1.5, 0.5, 28.0, 0.06))
	_add(&"gem", Synth.voice(W.SINE, 1250.0, 1800.0, 0.07, 0.22, 0.002, 2.0))
	_add(&"coin", Synth.echo(Synth.sequence([
		Synth.voice(W.TRIANGLE, 988.0, 988.0, 0.05, 0.32, 0.002, 1.0),
		Synth.voice(W.TRIANGLE, 1319.0, 1319.0, 0.14, 0.32, 0.002, 2.0)]), 0.07, 0.3, 2))
	_add(&"level_up", Synth.echo(_arpeggio([72, 76, 79, 84], 0.07, 0.24, W.SQUARE, 0.55), 0.09, 0.35, 3))
	_add(&"pickup", Synth.echo(_arpeggio([76, 79, 83, 88, 91], 0.05, 0.26, W.TRIANGLE, 1.0), 0.06, 0.4, 3))
	# Grave Blast (and boss deaths): a deep boom under a noise blast, with a rolling echo.
	_add(&"bomb", Synth.echo(Synth.mix([
		Synth.voice(W.NOISE, 360.0, 30.0, 0.8, 0.38, 0.002, 1.6, 0.25),
		Synth.voice(W.SINE, 90.0, 30.0, 0.7, 0.42, 0.002, 1.4)]), 0.14, 0.3, 2))
	# Boss arrival: a heavy impact and a tolling bell over a dissonant, swelling horn.
	_add(&"boss", Synth.echo(Synth.mix([
		Synth.voice(W.NOISE, 500.0, 40.0, 0.6, 0.25, 0.002, 1.8, 0.3),
		Synth.voice(W.SINE, 120.0, 38.0, 0.9, 0.35, 0.002, 1.6),
		Synth.voice(W.SINE, 196.0, 196.0, 2.4, 0.2, 0.003, 1.4),
		Synth.voice(W.SINE, 392.0, 392.0, 2.0, 0.1, 0.003, 1.6),
		Synth.voice(W.SINE, 541.0, 541.0, 1.6, 0.08, 0.003, 1.8),
		Synth.voice(W.SINE, 1058.0, 1058.0, 0.9, 0.05, 0.003, 2.0),
		Synth.voice(W.SAW, 98.0, 92.0, 2.2, 0.12, 0.25, 1.0, 0.25, 5.0, 0.015),
		Synth.voice(W.SAW, 104.0, 97.0, 2.2, 0.12, 0.25, 1.0, 0.25, 5.0, 0.015)]), 0.28, 0.35, 3))
	_add(&"dash", Synth.voice(W.NOISE, 4000.0, 700.0, 0.12, 0.16, 0.003, 1.5, 0.7))
	# Hex Snare: an eerie falling whistle with a wobble, ringing out.
	_add(&"hex", Synth.echo(Synth.mix([
		Synth.voice(W.SINE, 1400.0, 420.0, 0.45, 0.3, 0.01, 1.3, 1.0, 9.0, 0.05),
		Synth.voice(W.TRIANGLE, 700.0, 210.0, 0.45, 0.18, 0.01, 1.3, 1.0, 9.0, 0.05)]), 0.11, 0.35, 3))
	# Bone Effigy rising: a dry clatter of bones.
	_add(&"effigy", Synth.sequence([
		Synth.voice(W.NOISE, 2400.0, 1800.0, 0.04, 0.22, 0.001, 2.0, 0.6),
		Synth.voice(W.NOISE, 1900.0, 1400.0, 0.05, 0.18, 0.001, 2.0, 0.6),
		Synth.voice(W.SQUARE, 220.0, 140.0, 0.12, 0.16, 0.002, 2.0, 0.4)]))
	# A teammate went down: a heavy falling groan with a bell-like ring.
	_add(&"downed", Synth.echo(Synth.mix([
		Synth.voice(W.SAW, 220.0, 70.0, 0.7, 0.22, 0.004, 1.3, 0.3, 6.0, 0.03),
		Synth.voice(W.SINE, 660.0, 640.0, 0.9, 0.12, 0.003, 1.8)]), 0.16, 0.3, 2))
	# Back on your feet: a rising, warm chime.
	_add(&"revive", Synth.echo(_arpeggio([67, 71, 74, 79, 83], 0.06, 0.24, W.TRIANGLE, 0.8), 0.08, 0.35, 3))
	_add(&"enemy_shot", Synth.voice(W.SQUARE, 330.0, 240.0, 0.08, 0.12, 0.002, 2.0, 0.4))
	_add(&"ui", Synth.voice(W.SINE, 900.0, 900.0, 0.03, 0.2, 0.001, 2.0))
	# "3, 2, 1" before play resumes, then a brighter "go".
	_add(&"countdown", Synth.echo(Synth.voice(W.SQUARE, 523.0, 523.0, 0.12, 0.35, 0.002, 1.5, 0.4), 0.08, 0.25, 1))
	_add(&"countdown_go", Synth.echo(Synth.mix([
		Synth.voice(W.SQUARE, 1047.0, 1047.0, 0.3, 0.2, 0.002, 1.5, 0.45),
		Synth.voice(W.TRIANGLE, 523.0, 523.0, 0.3, 0.25, 0.002, 1.5)]), 0.09, 0.3, 2))
	# A map event appeared or woke up: a low toll with a shimmer on top.
	_add(&"event", Synth.echo(Synth.mix([
		Synth.voice(W.SINE, 294.0, 294.0, 1.0, 0.25, 0.003, 1.6),
		Synth.voice(W.SINE, 588.0, 588.0, 0.7, 0.1, 0.003, 1.8),
		Synth.voice(W.TRIANGLE, 1175.0, 1400.0, 0.35, 0.08, 0.02, 1.5, 1.0, 7.0, 0.02)]), 0.14, 0.3, 2))
	# A champion's chest opens: a wooden creak, then a sparkle.
	_add(&"chest", Synth.sequence([
		Synth.voice(W.SAW, 140.0, 190.0, 0.14, 0.18, 0.01, 1.2, 0.3),
		Synth.echo(_arpeggio([79, 84, 88, 91, 96], 0.045, 0.22, W.TRIANGLE, 1.0), 0.06, 0.4, 3)]))
	# Quest complete: a short, bright fanfare.
	_add(&"quest", Synth.echo(_arpeggio([72, 76, 79, 84, 79, 84], 0.08, 0.26, W.SQUARE, 0.5), 0.1, 0.35, 2))
	_add(&"victory", Synth.echo(_arpeggio([67, 72, 76, 79, 84], 0.12, 0.25, W.SQUARE, 0.5), 0.12, 0.35, 3))
	_add(&"defeat", Synth.echo(Synth.sequence([
		Synth.voice(W.SAW, 330.0, 310.0, 0.28, 0.26, 0.005, 1.0, 0.35),
		Synth.voice(W.SAW, 262.0, 245.0, 0.28, 0.26, 0.005, 1.0, 0.35),
		Synth.voice(W.SAW, 196.0, 120.0, 0.7, 0.26, 0.005, 1.5, 0.35)]), 0.15, 0.3, 2))


func _add(sound: StringName, buffer: PackedFloat32Array) -> void:
	_streams[sound] = Synth.to_stream(buffer)


## Notes (MIDI numbers) played one after another.
func _arpeggio(notes: Array[int], note_seconds: float, volume: float, wave: Synth.Wave, brightness: float) -> PackedFloat32Array:
	var parts: Array[PackedFloat32Array] = []
	for i: int in notes.size():
		var hz := Synth.midi_to_hz(notes[i])
		var length := note_seconds * (2.5 if i == notes.size() - 1 else 1.0)
		parts.append(Synth.voice(wave, hz, hz, length, volume, 0.002, 1.2, brightness))
	return Synth.sequence(parts)
