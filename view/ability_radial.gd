class_name AbilityRadial
extends RadialMenu
## C5: the long-press ring of a squad banner. Same press tracker and geometry as the tool
## radial (radial_menu.gd is untouched); the slots are role abilities instead of tools.
## Each slot: [ability id, label, ready (bool), detail text (cooldown / reason)].
## `slot_picked` is emitted only for ready slots.

var slots: Array = []
var squad_id := -1


func set_slots(p_squad_id: int, p_slots: Array) -> void:
	squad_id = p_squad_id
	slots = p_slots


func press_end(pos: Vector2) -> bool:
	var was_fired := _fired
	_pressing = false
	_fired = false
	if is_open:
		var idx := slot_at(pos)
		close()
		if idx >= 0 and bool(slots[idx][2]):
			slot_picked.emit(str(slots[idx][0]))
	return was_fired


func slot_center(i: int) -> Vector2:
	var a := -PI * 0.5 + TAU * float(i) / float(maxi(1, slots.size()))
	return center + Vector2(cos(a), sin(a)) * RING_RADIUS


func slot_at(pos: Vector2) -> int:
	for i in slots.size():
		if pos.distance_to(slot_center(i)) <= SLOT_SIZE * 0.5:
			return i
	return -1


func _draw() -> void:
	if not is_open:
		return
	draw_circle(center, 14.0, Color(1, 1, 1, 0.35))
	var font := get_theme_default_font()
	for i in slots.size():
		var c := slot_center(i)
		var ok := bool(slots[i][2])
		var fill := Color(0.12, 0.14, 0.18, 0.92) if ok else Color(0.2, 0.2, 0.22, 0.92)
		if i == hovered and ok:
			fill = Color(0.95, 0.75, 0.2, 0.95)
		draw_circle(c, SLOT_SIZE * 0.5, fill)
		draw_arc(c, SLOT_SIZE * 0.5, 0, TAU, 32, Color(1, 1, 1, 0.8 if ok else 0.3), 2.0)
		var label := str(slots[i][1])
		var tint := Color.WHITE if ok else Color(1, 1, 1, 0.5)
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(font, c + Vector2(-w * 0.5, -2), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, tint)
		var det := str(slots[i][3])
		var dw := font.get_string_size(det, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(font, c + Vector2(-dw * 0.5, 15), det, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, tint)
