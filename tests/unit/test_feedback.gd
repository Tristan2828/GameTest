extends GutTest
## In-game feedback: the message, the Discord upload body and the webhook stamp.
## Nothing here sends anything.

const TEST_CONFIG: String = "user://test_feedback_build_info.cfg"


func after_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CONFIG))


func test_message_has_kind_name_text_and_game_info() -> void:
	var text := FeedbackReport.message_text(0, "Jake", "More bosses please", "v0.16.0\nStage 2/3: The Bone Marsh")
	assert_string_contains(text, "Suggestion")
	assert_string_contains(text, "Jake")
	assert_string_contains(text, "More bosses please")
	assert_string_contains(text, "Stage 2/3: The Bone Marsh")
	assert_lt(text.length(), 2000, "fits in one Discord message")


func test_names_cant_ping_or_format_and_long_text_is_cut() -> void:
	var text := FeedbackReport.message_text(1, "@everyone **boss**", "x".repeat(5000), "info")
	assert_false(text.contains("@everyone"))
	assert_string_contains(text, "everyone boss")
	assert_lt(text.length(), 2000)
	assert_string_contains(FeedbackReport.message_text(2, "  ", "hi", ""), "Anonymous")


func test_payload_never_mentions_anyone_and_lists_the_screenshot() -> void:
	var payload: Dictionary = JSON.parse_string(FeedbackReport.payload_json("hello", true))
	assert_eq(payload["content"], "hello")
	assert_eq(payload["allowed_mentions"]["parse"], [])
	assert_eq(payload["attachments"][0]["filename"], "screenshot.png")
	var without: Dictionary = JSON.parse_string(FeedbackReport.payload_json("hello", false))
	assert_false(without.has("attachments"))


func test_upload_body_holds_the_json_and_the_png() -> void:
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	var png := FeedbackReport.screenshot_png(image)
	var body := FeedbackReport.multipart_body("{\"content\":\"hi\"}", png)
	var text := body.get_string_from_ascii()
	assert_string_contains(text, "name=\"payload_json\"")
	assert_string_contains(text, "{\"content\":\"hi\"}")
	assert_string_contains(text, "filename=\"screenshot.png\"")
	var closing := ("--" + FeedbackReport.BOUNDARY + "--\r\n").to_utf8_buffer()
	assert_eq(body.slice(body.size() - closing.size()), closing, "ends with the closing boundary")
	assert_gt(body.size(), png.size())
	assert_eq(Image.new().load_png_from_buffer(png), OK)


func test_screenshot_is_scaled_up_for_readability() -> void:
	var image := Image.create(640, 360, false, Image.FORMAT_RGBA8)
	var copy := Image.new()
	copy.load_png_from_buffer(FeedbackReport.screenshot_png(image))
	assert_eq(copy.get_size(), Vector2i(1280, 720))
	assert_true(FeedbackReport.screenshot_png(null).is_empty())


func test_webhook_comes_only_from_the_build_stamp_and_must_be_discord() -> void:
	var config := ConfigFile.new()
	config.set_value("feedback", "webhook", "https://discord.com/api/webhooks/123/abc")
	config.save(TEST_CONFIG)
	assert_eq(FeedbackReport.webhook_url(TEST_CONFIG), "https://discord.com/api/webhooks/123/abc")
	config.set_value("feedback", "webhook", "https://example.com/steal")
	config.save(TEST_CONFIG)
	assert_eq(FeedbackReport.webhook_url(TEST_CONFIG), "", "only Discord webhooks")
	assert_eq(FeedbackReport.webhook_url("user://does_not_exist.cfg"), "")


func test_screen_needs_a_message_before_sending() -> void:
	var screen := FeedbackScreen.new()
	add_child_autofree(screen)
	screen.open(null, "Title menu")
	assert_true(screen._screenshot_check.disabled, "no screenshot on the title menu")
	screen._send()
	assert_eq(screen._status_label.text, "Write something first.")
	assert_false(screen._sending)
