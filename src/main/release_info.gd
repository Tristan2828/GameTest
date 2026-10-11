class_name ReleaseInfo
extends RefCounted
## The newest published release on GitHub, read from the public API
## (https://api.github.com/repos/<repo>/releases/latest; no login needed), plus
## the version comparison the updater uses. Pure logic, so it's testable.

## Renamed from Tristan2828/GameTest (GitHub redirects the old name). Versions up
## to v0.24.0 only trusted links under the old name, and GitHub's API now answers
## with the new one, so their updater found "no Windows download" (playtest 8).
const REPO: String = "Tristan2828/medieval-survival"
const OLD_REPO: String = "Tristan2828/GameTest"
const LATEST_URL: String = "https://api.github.com/repos/" + REPO + "/releases/latest"
## Fallback when the API refuses: this page redirects to the newest release's tag.
const LATEST_PAGE_URL: String = "https://github.com/" + REPO + "/releases/latest"
## The last release whose zip was named GameTest-<version>-windows.zip.
const LAST_GAMETEST_ZIP: String = "0.24.0"
## Only download from GitHub (the API answers with these hosts).
const TRUSTED_PREFIXES: Array[String] = ["https://github.com/" + REPO + "/", "https://github.com/" + OLD_REPO + "/"]

## e.g. "0.15.0" (the tag without its "v").
var version: String = ""
## The release page (fallback: open it in the browser).
var page_url: String = ""
## The Windows zip's download link (empty if the release has none).
var zip_url: String = ""
var zip_size: int = 0


## Parses the API's JSON reply. Returns null if it isn't a usable release.
static func parse(json_text: String) -> ReleaseInfo:
	var json := JSON.new()  # (JSON.parse_string would log an error on bad input)
	if json.parse(json_text) != OK:
		return null
	var data: Variant = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return null
	var tag: String = str(data.get("tag_name", ""))
	if tag.is_empty() or data.get("draft", false) or data.get("prerelease", false):
		return null
	var info := ReleaseInfo.new()
	info.version = tag.trim_prefix("v")
	info.page_url = str(data.get("html_url", ""))
	var assets: Variant = data.get("assets", [])
	if typeof(assets) == TYPE_ARRAY:
		for asset: Variant in assets:
			if typeof(asset) != TYPE_DICTIONARY:
				continue
			var asset_name: String = str(asset.get("name", ""))
			var url: String = str(asset.get("browser_download_url", ""))
			if (asset_name.begins_with("GameTest-") or asset_name.begins_with("MedievalSurvival-")) \
					and asset_name.ends_with("-windows.zip") and is_trusted(url):
				info.zip_url = url
				info.zip_size = int(asset.get("size", 0))
	return info


## The fallback: a release from its tag page link (".../releases/tag/v0.25.0").
## The zip's link follows the naming release.ps1 uses (no size known).
static func from_tag_url(url: String) -> ReleaseInfo:
	var marker := "/releases/tag/"
	if not is_trusted(url) or not url.contains(marker):
		return null
	var tag := url.get_slice(marker, 1).get_slice("?", 0).get_slice("#", 0).uri_decode()
	var version := tag.trim_prefix("v")
	if version.is_empty() or not version.replace(".", "").is_valid_int():
		return null
	var info := ReleaseInfo.new()
	info.version = version
	info.page_url = url
	var prefix := "GameTest" if compare_versions(version, LAST_GAMETEST_ZIP) <= 0 else "MedievalSurvival"
	info.zip_url = "https://github.com/%s/releases/download/%s/%s-%s-windows.zip" % [REPO, tag, prefix, version]
	return info


static func is_trusted(url: String) -> bool:
	for prefix: String in TRUSTED_PREFIXES:
		if url.begins_with(prefix):
			return true
	return false


## -1 if a is older than b, 0 if the same, 1 if newer ("0.9.0" < "0.10.0").
static func compare_versions(a: String, b: String) -> int:
	var left := a.trim_prefix("v").split(".")
	var right := b.trim_prefix("v").split(".")
	for i: int in maxi(left.size(), right.size()):
		var x := left[i].to_int() if i < left.size() else 0
		var y := right[i].to_int() if i < right.size() else 0
		if x != y:
			return -1 if x < y else 1
	return 0


## The version this game is (project setting, bumped for every release).
static func current_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
