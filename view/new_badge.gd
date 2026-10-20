class_name NewBadge
extends Label
## Small "NEW" tag pinned to the top-right corner of a Button. Pure overlay: ignores the mouse and
## never changes the parent's size (<= 28 x 14 px). Use `NewBadge.set_on(button, on)`.

const BADGE_NAME := "NewBadge"


static func set_on(btn: Button, on: bool) -> void:
	if btn == null:
		return
	var b := btn.get_node_or_null(BADGE_NAME) as NewBadge
	if b == null:
		if not on:
			return
		b = NewBadge.new()
		btn.add_child(b)
	b.visible = on


static func is_on(btn: Button) -> bool:
	if btn == null:
		return false
	var b := btn.get_node_or_null(BADGE_NAME) as Control
	return b != null and b.visible


func _init() -> void:
	name = BADGE_NAME
	text = "NEW"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 10)
	add_theme_color_override("font_color", Color.WHITE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.85, 0.2, 0.2)
	sb.set_corner_radius_all(4)
	add_theme_stylebox_override("normal", sb)
	custom_minimum_size = Vector2(26, 14)
	size = Vector2(26, 14)
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -28
	offset_right = -2
	offset_top = 2
	offset_bottom = 16
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
