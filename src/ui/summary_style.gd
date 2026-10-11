class_name SummaryStyle
extends RefCounted
## The run summary's colors and small building blocks (labels, dividers, card
## boxes, bars, short numbers), shared by RunSummaryPanel and its pages.

const DEFEAT_COLOR: Color = Color(0.95, 0.4, 0.38)
const VICTORY_COLOR: Color = Color(0.95, 0.85, 0.55)
const LABEL_COLOR: Color = Color(0.6, 0.57, 0.68)
const VALUE_COLOR: Color = Color(0.95, 0.93, 1.0)
const AWARD_COLOR: Color = Color(0.95, 0.78, 0.4)
const DIVIDER_COLOR: Color = Color(0.3, 0.24, 0.4)
const EMBER_COLOR: Color = Color(0.98, 0.6, 0.25)
const GOOD_COLOR: Color = Color(0.55, 0.9, 0.45)
const CARD_BG: Color = Color(0.1, 0.08, 0.14, 1.0)
const BAR_COLOR: Color = Color(0.95, 0.78, 0.4)
const BAR_BACK_COLOR: Color = Color(0.2, 0.16, 0.26)
## Inside a card: the space its border and margins take.
const CARD_INSET: int = 12
## Wide pages (Stages, Highlights).
const WIDE_CARD: int = 560


static func label(text: String, font_size: int, color: Color, centered: bool) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	if centered:
		result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return result


## Cut off at the edge instead of widening its card.
static func clipped(text_label: Label) -> Label:
	text_label.clip_text = true
	text_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return text_label


## Wraps onto more lines at this width instead of widening its card.
static func wrapped(text_label: Label, width: int) -> Label:
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size.x = width
	return text_label


static func divider() -> ColorRect:
	var line := ColorRect.new()
	line.color = DIVIDER_COLOR
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


static func box(background: Color, border: Color, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_content_margin_all(margin)
	return style


## A thin bar filled to `ratio` (share of damage, share of kills).
static func share_bar(ratio: float, width: int) -> Control:
	var back := ColorRect.new()
	back.color = BAR_BACK_COLOR
	back.custom_minimum_size = Vector2(width, 2)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := ColorRect.new()
	fill.color = BAR_COLOR
	fill.size = Vector2(roundf(width * clampf(ratio, 0.0, 1.0)), 2)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(fill)
	return back


## A label that slowly fades in and out (new best, new hero).
static func pulse(text_label: Label) -> void:
	var tween := text_label.create_tween().set_loops()
	tween.tween_property(text_label, "modulate:a", 0.5, 0.5)
	tween.tween_property(text_label, "modulate:a", 1.0, 0.5)


## 950 -> "950", 12345 -> "12.3k", 2500000 -> "2.5M".
static func compact(value: int) -> String:
	if value >= 1000000:
		return "%.1fM" % (value / 1000000.0)
	if value >= 10000:
		return "%.1fk" % (value / 1000.0)
	return str(value)
