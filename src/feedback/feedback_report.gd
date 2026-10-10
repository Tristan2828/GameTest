class_name FeedbackReport
extends RefCounted
## Builds what the in-game feedback screen sends to the team's Discord channel:
## the message text (name, kind, message, game info) and the upload body with an
## optional screenshot. Pure, so it's unit-testable; FeedbackScreen sends it.
##
## The Discord webhook link is NOT in the repo: tools/build.ps1 reads it from
## the git-ignored file feedback_webhook.txt (or $env:GAMETEST_FEEDBACK_WEBHOOK)
## and stamps it into build_info.cfg, which goes into the exported game only.

const KINDS: Array[String] = ["Suggestion", "Bug report", "Praise"]
const KIND_EMOJI: Array[String] = ["💡", "🐞", "❤️"]
## Discord allows 2000 characters per message; leave room for the header.
const MAX_MESSAGE: int = 1500
const MAX_NAME: int = 32
const BOUNDARY: String = "----GameTestFeedbackBoundary7MA4YWxk"


## The webhook baked into this build ("" = sending is off, e.g. a dev build).
static func webhook_url(config_path: String = "res://build_info.cfg") -> String:
	var config := ConfigFile.new()
	if config.load(config_path) != OK:
		return ""
	var url := str(config.get_value("feedback", "webhook", "")).strip_edges()
	return url if is_webhook(url) else ""


static func is_webhook(url: String) -> bool:
	return url.begins_with("https://discord.com/api/webhooks/") or url.begins_with("https://discordapp.com/api/webhooks/")


## The Discord message: a header line, the message, then the game info.
static func message_text(kind: int, player_name: String, message: String, context: String) -> String:
	var who := player_name.strip_edges().left(MAX_NAME)
	if who.is_empty():
		who = "Anonymous"
	var index := clampi(kind, 0, KINDS.size() - 1)
	var body := message.strip_edges().left(MAX_MESSAGE)
	return "%s **%s** from **%s**\n%s\n```\n%s\n```" % [KIND_EMOJI[index], KINDS[index], _plain(who), body, context.strip_edges()]


## The JSON part: the message, posted under a fixed name, never pinging anyone.
static func payload_json(text: String, has_screenshot: bool) -> String:
	var payload := {"username": "GameTest feedback", "content": text, "allowed_mentions": {"parse": []}}
	if has_screenshot:
		payload["attachments"] = [{"id": 0, "filename": "screenshot.png"}]
	return JSON.stringify(payload)


## multipart/form-data body for the webhook: the JSON, plus the PNG if given.
static func multipart_body(json: String, png: PackedByteArray) -> PackedByteArray:
	var body := PackedByteArray()
	body.append_array(("--" + BOUNDARY + "\r\nContent-Disposition: form-data; name=\"payload_json\"\r\n"
		+ "Content-Type: application/json\r\n\r\n" + json + "\r\n").to_utf8_buffer())
	if not png.is_empty():
		body.append_array(("--" + BOUNDARY + "\r\nContent-Disposition: form-data; name=\"files[0]\"; filename=\"screenshot.png\"\r\n"
			+ "Content-Type: image/png\r\n\r\n").to_utf8_buffer())
		body.append_array(png)
		body.append_array("\r\n".to_utf8_buffer())
	body.append_array(("--" + BOUNDARY + "--\r\n").to_utf8_buffer())
	return body


static func content_type_header() -> String:
	return "Content-Type: multipart/form-data; boundary=" + BOUNDARY


## The screenshot as PNG bytes, scaled up 2x (crisp pixels) so it's readable in Discord.
static func screenshot_png(image: Image) -> PackedByteArray:
	if image == null or image.is_empty():
		return PackedByteArray()
	var copy := image.duplicate() as Image
	if copy.get_width() <= 960:
		copy.resize(copy.get_width() * 2, copy.get_height() * 2, Image.INTERPOLATE_NEAREST)
	return copy.save_png_to_buffer()


## Names can't format the message (no markdown or mentions).
static func _plain(text: String) -> String:
	var result := text
	for symbol: String in ["*", "_", "`", "~", "|", "@", "<", ">"]:
		result = result.replace(symbol, "")
	return result
