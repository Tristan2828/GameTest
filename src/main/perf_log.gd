class_name PerfLog
extends RefCounted
## Timing instrumentation for performance work (--perf-log). Code wraps a step:
##   var t := PerfLog.start()
##   ...work...
##   PerfLog.stop(&"enemies", t)
## and once a second the arena prints the average and worst time of every step,
## frames per second and the slowest frame. Costs nothing when the flag is off.

static var enabled: bool = false
## Step name -> [total usec, calls, worst usec] since the last report.
static var _sections: Dictionary[StringName, Array] = {}
static var _frames: int = 0
static var _worst_frame_usec: int = 0
static var _last_frame_usec: int = 0


static func start() -> int:
	return Time.get_ticks_usec() if enabled else 0


static func stop(section: StringName, started: int) -> void:
	if not enabled:
		return
	var spent := Time.get_ticks_usec() - started
	var entry: Array = _sections.get(section, [0, 0, 0])
	entry[0] += spent
	entry[1] += 1
	entry[2] = maxi(entry[2], spent)
	_sections[section] = entry


## Call once per rendered frame (tracks fps and the slowest frame).
static func frame() -> void:
	if not enabled:
		return
	var now := Time.get_ticks_usec()
	if _last_frame_usec > 0:
		_worst_frame_usec = maxi(_worst_frame_usec, now - _last_frame_usec)
	_last_frame_usec = now
	_frames += 1


## One report line per second of data, then starts over. `extra` is appended.
static func report(seconds: float, extra: String) -> String:
	var parts := PackedStringArray()
	parts.append("fps %d  worst frame %.1fms" % [roundi(_frames / maxf(seconds, 0.001)), _worst_frame_usec / 1000.0])
	var names: Array[StringName] = []
	names.assign(_sections.keys())
	names.sort_custom(func(a: StringName, b: StringName) -> bool: return _sections[a][0] > _sections[b][0])
	for section: StringName in names:
		var entry: Array = _sections[section]
		parts.append("%s %.2f/%.2fms" % [section, entry[0] / 1000.0 / maxf(entry[1], 1.0), entry[2] / 1000.0])
	_sections.clear()
	_frames = 0
	_worst_frame_usec = 0
	return "[perf] " + "  ".join(parts) + "  |  " + extra
