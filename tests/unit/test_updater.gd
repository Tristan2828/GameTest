extends GutTest
## Version checks against GitHub releases and the exe swap the updater does.

const SAMPLE_RELEASE: String = """{
	"tag_name": "v0.15.0",
	"html_url": "https://github.com/Tristan2828/GameTest/releases/tag/v0.15.0",
	"draft": false, "prerelease": false,
	"assets": [
		{"name": "notes.txt", "browser_download_url": "https://github.com/Tristan2828/GameTest/releases/download/v0.15.0/notes.txt", "size": 5},
		{"name": "GameTest-0.15.0-windows.zip", "browser_download_url": "https://github.com/Tristan2828/GameTest/releases/download/v0.15.0/GameTest-0.15.0-windows.zip", "size": 39000000}
	]
}"""

const WORK_DIR: String = "user://test_updater"


func after_each() -> void:
	var dir := DirAccess.open(WORK_DIR)
	if dir != null:
		for file: String in dir.get_files():
			dir.remove(file)


func test_versions_compare_numerically() -> void:
	assert_eq(ReleaseInfo.compare_versions("0.15.0", "0.14.0"), 1)
	assert_eq(ReleaseInfo.compare_versions("0.9.0", "0.10.0"), -1, "not alphabetical")
	assert_eq(ReleaseInfo.compare_versions("v0.14.0", "0.14"), 0)
	assert_eq(ReleaseInfo.compare_versions("1.0.0", "0.99.9"), 1)


func test_parse_finds_the_windows_zip() -> void:
	var info := ReleaseInfo.parse(SAMPLE_RELEASE)
	assert_not_null(info)
	assert_eq(info.version, "0.15.0")
	assert_string_ends_with(info.zip_url, "GameTest-0.15.0-windows.zip")
	assert_eq(info.zip_size, 39000000)
	assert_string_contains(info.page_url, "releases/tag/v0.15.0")


func test_parse_rejects_junk_drafts_and_untrusted_links() -> void:
	assert_null(ReleaseInfo.parse("not json"))
	assert_null(ReleaseInfo.parse("{}"))
	assert_null(ReleaseInfo.parse('{"tag_name": "v9.0.0", "draft": true}'))
	var elsewhere := ReleaseInfo.parse(SAMPLE_RELEASE.replace("https://github.com/Tristan2828/GameTest/releases/download/v0.15.0/GameTest", "https://evil.example/GameTest"))
	assert_eq(elsewhere.zip_url, "", "only downloads from this repo on GitHub")


func test_install_swaps_the_exe_and_keeps_the_old_one() -> void:
	DirAccess.make_dir_recursive_absolute(WORK_DIR)
	var exe := ProjectSettings.globalize_path(WORK_DIR.path_join("GameTest.exe"))
	var zip_path := ProjectSettings.globalize_path(WORK_DIR.path_join("latest.zip"))
	var old_file := FileAccess.open(exe, FileAccess.WRITE)
	old_file.store_string("old game")
	old_file.close()
	var new_bytes := PackedByteArray()
	new_bytes.resize(1_500_000)
	new_bytes.fill(7)
	var packer := ZIPPacker.new()
	packer.open(zip_path)
	packer.start_file("README.txt")
	packer.write_file("hi".to_utf8_buffer())
	packer.close_file()
	packer.start_file("GameTest.exe")
	packer.write_file(new_bytes)
	packer.close_file()
	packer.close()
	assert_eq(Updater._install(zip_path, exe), "")
	assert_eq(FileAccess.get_file_as_bytes(exe).size(), new_bytes.size(), "new exe in place")
	assert_eq(FileAccess.get_file_as_string(exe + Updater.OLD_SUFFIX), "old game", "old exe kept aside")


func test_install_refuses_a_zip_without_the_game() -> void:
	DirAccess.make_dir_recursive_absolute(WORK_DIR)
	var exe := ProjectSettings.globalize_path(WORK_DIR.path_join("GameTest.exe"))
	var zip_path := ProjectSettings.globalize_path(WORK_DIR.path_join("bad.zip"))
	var old_file := FileAccess.open(exe, FileAccess.WRITE)
	old_file.store_string("old game")
	old_file.close()
	var packer := ZIPPacker.new()
	packer.open(zip_path)
	packer.start_file("README.txt")
	packer.write_file("hi".to_utf8_buffer())
	packer.close_file()
	packer.close()
	assert_ne(Updater._install(zip_path, exe), "")
	assert_eq(FileAccess.get_file_as_string(exe), "old game", "nothing touched")


func test_updater_stays_off_in_tests_and_the_editor() -> void:
	assert_false(Updater.can_run())
