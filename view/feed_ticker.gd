class_name FeedTicker
extends VBoxContainer
## F2: corner kill/event feed. At most MAX_LINES short lines, each fades after LIFETIME seconds.
## No per-frame work while empty: the HUD calls advance(dt) only when lines exist.

const MAX_LINES := 3
const LIFETIME := 6.0
const FADE := 0.6
const WIDTH := 300.0
const FONT := 13

var _lines: Array[Label] = []
var _ages: Array[float] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 2)
	custom_minimum_size.x = WIDTH
	visible = false


func push(text: String) -> void:
	if text == "":
		return
	while _lines.size() >= MAX_LINES:
		_drop(0)
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.custom_minimum_size.x = WIDTH
	l.add_theme_font_size_override("font_size", FONT)
	l.add_theme_color_override("font_color", Color(0.95, 0.9, 0.78))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	add_child(l)
	_lines.append(l)
	_ages.append(0.0)
	visible = true


func line_count() -> int:
	return _lines.size()


func texts() -> Array[String]:
	var out: Array[String] = []
	for l in _lines:
		out.append(l.text)
	return out


func advance(dt: float) -> void:
	var i := 0
	while i < _lines.size():
		_ages[i] += dt
		var left := LIFETIME - _ages[i]
		if left <= 0.0:
			_drop(i)
			continue
		_lines[i].modulate.a = clampf(left / FADE, 0.0, 1.0)
		i += 1


func _drop(i: int) -> void:
	var l := _lines[i]
	_lines.remove_at(i)
	_ages.remove_at(i)
	remove_child(l)
	l.free()
	visible = not _lines.is_empty()
