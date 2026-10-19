class_name ModalStyle
extends RefCounted
## U3: shared look for full-screen sheets: opaque dark panel, input-blocking scrim,
## rounded border, readable fonts, high-contrast title, filled/outlined buttons.

const PANEL_COLOR := Color(0.07, 0.08, 0.11, 0.97)
const SCRIM_COLOR := Color(0, 0, 0, 0.75)
const BORDER_COLOR := Color(0.55, 0.6, 0.75, 1.0)
const TITLE_COLOR := Color(1, 1, 1, 1)
const BODY_COLOR := Color(0.92, 0.93, 0.96, 1)
const ACCENT := Color(0.95, 0.72, 0.18, 1)
const ACCENT_TEXT := Color(0.08, 0.06, 0.02, 1)
const MODAL_IDS: Array[String] = ["reviews", "petition", "dispatch", "shuttle"]
const BODY_FONT := 18
const TITLE_FONT := 26
const BTN_MIN_H := 64.0


static func panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_COLOR
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(2)
	sb.border_color = BORDER_COLOR
	sb.set_content_margin_all(14)
	return sb


## Style any PanelContainer (e.g. a GamePanel) as a modal sheet; returns it for chaining.
static func apply(panel: Control) -> Control:
	panel.add_theme_stylebox_override("panel", panel_style())
	panel.add_theme_font_size_override("font_size", BODY_FONT)
	panel.add_theme_color_override("font_color", BODY_COLOR)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	return panel


static func style_label(l: Label, title := false) -> void:
	l.add_theme_font_size_override("font_size", TITLE_FONT if title else BODY_FONT)
	l.add_theme_color_override("font_color", TITLE_COLOR if title else BODY_COLOR)


## Full-screen dim control that swallows all input so the world below is not clickable.
static func make_scrim() -> ColorRect:
	var s := ColorRect.new()
	s.color = SCRIM_COLOR
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.mouse_filter = Control.MOUSE_FILTER_STOP
	return s


static func style_button(b: Button, primary: bool) -> void:
	b.custom_minimum_size.y = maxf(b.custom_minimum_size.y, BTN_MIN_H)
	b.add_theme_font_size_override("font_size", 20)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(8)
	var fc := ACCENT_TEXT if primary else TITLE_COLOR
	if primary:
		sb.bg_color = ACCENT
	else:
		sb.bg_color = Color(0, 0, 0, 0)
		sb.set_border_width_all(2)
		sb.border_color = ACCENT
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, fc)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)


static func _lin(v: float) -> float:
	return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)


static func luminance(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)


## WCAG contrast ratio of two opaque colours.
static func contrast(fg: Color, bg: Color) -> float:
	var a := luminance(fg)
	var b := luminance(bg)
	return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)
