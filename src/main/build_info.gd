class_name BuildInfo
extends RefCounted
## Which build is running. tools/build.ps1 writes res://build_info.cfg (commit
## and date) into every exported build; running from the editor has none.


## e.g. "v0.12.0  build 1a2b3c4 (2026-10-09 14:30)" or "v0.12.0  dev build".
static func describe() -> String:
	var version: String = ProjectSettings.get_setting("application/config/version", "dev")
	var config := ConfigFile.new()
	if config.load("res://build_info.cfg") != OK:
		return "v%s  dev build" % version
	return "v%s  build %s (%s)" % [version, config.get_value("build", "commit", "?"), config.get_value("build", "date", "?")]
