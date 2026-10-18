class_name TutorialHighlight
extends Control
## Pulsing outline around a tool button or map cell rect. Never blocks input.

var _tween: Tween
var _style: StyleBoxFlat


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(1, 0.85, 0.2, 0.12)
	_style.border_color = Color(1, 0.85, 0.2, 0.95)
	_style.set_border_width_all(4)
	_style.set_corner_radius_all(10)


func _draw() -> void:
	draw_style_box(_style, Rect2(Vector2.ZERO, size))


## Places the outline over `rect` (viewport coordinates) and starts the pulse.
func show_over(rect: Rect2) -> void:
	var r := rect.grow(4)
	position = r.position
	size = r.size
	pivot_offset = size * 0.5
	visible = true
	queue_redraw()
	if (_tween == null or not _tween.is_valid()) and is_inside_tree():
		_tween = create_tween().set_loops()
		_tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.4)
		_tween.tween_property(self, "scale", Vector2.ONE, 0.4)


func hide_highlight() -> void:
	visible = false
	if _tween != null:
		_tween.kill()
		_tween = null
	scale = Vector2.ONE
