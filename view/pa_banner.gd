class_name PaBanner
extends PanelContainer
## F2: Warden PA announcement banner. One line at a time for SHOW_TIME seconds, at most
## MAX_QUEUE waiting (older dropped). Never takes input.

const SHOW_TIME := 2.5
const MAX_QUEUE := 2
const MAX_W := 440.0
const FONT := 14

var _label: Label
var _queue: Array[String] = []
var _left := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.09, 0.05, 0.9)
	sb.border_color = Color(0.95, 0.75, 0.3)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(5)
	add_theme_stylebox_override("panel", sb)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.custom_minimum_size.x = 100.0
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.add_theme_font_size_override("font_size", FONT)
	_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	add_child(_label)
	visible = false


func announce(text: String) -> void:
	if text == "":
		return
	if not visible:
		_show(text)
		return
	_queue.append(text)
	while _queue.size() > MAX_QUEUE:
		_queue.pop_front()


func pending() -> int:
	return _queue.size()


func current() -> String:
	return _label.text if visible else ""


func advance(dt: float) -> void:
	if not visible:
		return
	_left -= dt
	if _left > 0.0:
		return
	if _queue.is_empty():
		visible = false
		_label.text = ""
	else:
		_show(_queue.pop_front())


func _show(text: String) -> void:
	_label.text = text
	_left = SHOW_TIME
	visible = true


func is_active() -> bool:
	return visible
