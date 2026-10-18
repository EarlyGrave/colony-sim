class_name RadialMenu
extends Control
## Touch-first radial tool ring opened by a long press on the map. Pure
## geometry + a tiny press tracker, so it is testable without real input.
## The ring is drawn around the finger; releasing over a slot picks it,
## releasing anywhere else closes the menu.

signal slot_picked(tool_id: String)

const HOLD_SEC := 0.45
const DRIFT_PX := 12.0
const SLOT_SIZE := 72.0  ## slot diameter, >= 64 px
const RING_RADIUS := 110.0
## [tool id, label]
const SLOTS: Array = [
	["mine", "Mine"],
	["stockpile", "Zone"],
	["workbench", "Build"],
	["belt", "Belt"],
	["inspect", "Inspect"],
	["miner", "Miner"],  # region B5: machines moved from the strip into the ring
	["smelter", "Smelter"],
	["assembler", "Assembler"],
]

## Optional region F5 hook: returns Array[Rect2] the ring must not overlap (belt strip).
var avoid_provider: Callable = Callable()
var is_open := false
var center := Vector2.ZERO
var hovered := -1

# Press tracker state.
var _pressing := false
var _held := 0.0
var _origin := Vector2.ZERO
var _fired := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


# --- press tracking -------------------------------------------------------
func press_begin(pos: Vector2) -> void:
	_pressing = true
	_held = 0.0
	_origin = pos
	_fired = false


## Returns false once the press can no longer become a long press.
func press_move(pos: Vector2) -> bool:
	if is_open:
		hovered = slot_at(pos)
		queue_redraw()
		return true
	if _pressing and pos.distance_to(_origin) > DRIFT_PX:
		_pressing = false
	return _pressing


func press_cancel() -> void:
	_pressing = false
	_fired = false
	close()


## Advances the hold timer; opens the ring and returns true the frame it fires.
func press_tick(delta: float) -> bool:
	if not _pressing or _fired:
		return false
	_held += delta
	if _held >= HOLD_SEC:
		_fired = true
		open_at(_origin)
		return true
	return false


## Finger lifted. Returns true when this release belonged to a long press
## (so the caller must not treat it as a tap).
func press_end(pos: Vector2) -> bool:
	var was_fired := _fired
	_pressing = false
	_fired = false
	if is_open:
		var idx := slot_at(pos)
		close()
		if idx >= 0:
			slot_picked.emit(str(SLOTS[idx][0]))
	return was_fired


func is_pressing() -> bool:
	return _pressing


# --- geometry ---------------------------------------------------------------
func open_at(pos: Vector2) -> void:
	var vs := get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	var m := RING_RADIUS + SLOT_SIZE * 0.5
	center = Vector2(clampf(pos.x, m, maxf(m, vs.x - m)), clampf(pos.y, m, maxf(m, vs.y - m)))
	center = _f5_clear_center(center, pos, vs, m)  # region F5
	is_open = true
	hovered = -1
	visible = true
	queue_redraw()


func close() -> void:
	is_open = false
	hovered = -1
	visible = false


func slot_center(i: int) -> Vector2:
	var a := -PI * 0.5 + TAU * float(i) / float(SLOTS.size())
	return center + Vector2(cos(a), sin(a)) * RING_RADIUS


func slot_at(pos: Vector2) -> int:
	for i in SLOTS.size():
		if pos.distance_to(slot_center(i)) <= SLOT_SIZE * 0.5:
			return i
	return -1


func _draw() -> void:
	if not is_open:
		return
	draw_circle(center, 14.0, Color(1, 1, 1, 0.35))
	var font := get_theme_default_font()
	for i in SLOTS.size():
		var c := slot_center(i)
		draw_circle(c, SLOT_SIZE * 0.5, Color(0.95, 0.75, 0.2, 0.95) if i == hovered else Color(0.12, 0.14, 0.18, 0.92))
		draw_arc(c, SLOT_SIZE * 0.5, 0, TAU, 32, Color(1, 1, 1, 0.8), 2.0)
		var label := str(SLOTS[i][1])
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(font, c + Vector2(-w * 0.5, 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)


# region F5
func ring_hits(c: Vector2, rects: Array) -> bool:
	for i in SLOTS.size():
		var a := -PI * 0.5 + TAU * float(i) / float(SLOTS.size())
		var sc := c + Vector2(cos(a), sin(a)) * RING_RADIUS
		for r: Rect2 in rects:
			var nx := clampf(sc.x, r.position.x, r.end.x)
			var ny := clampf(sc.y, r.position.y, r.end.y)
			if sc.distance_to(Vector2(nx, ny)) < SLOT_SIZE * 0.5:
				return true
	return false


## Nearest ring center (to the press) whose slots clear every avoid rect.
func _f5_clear_center(c: Vector2, pos: Vector2, vs: Vector2, m: float) -> Vector2:
	if not avoid_provider.is_valid():
		return c
	var rects: Array = avoid_provider.call()
	if rects.is_empty() or not ring_hits(c, rects):
		return c
	var best := c
	var best_d := INF
	var y := m
	while y <= maxf(m, vs.y - m):
		var x := m
		while x <= maxf(m, vs.x - m):
			var cand := Vector2(x, y)
			var d := cand.distance_squared_to(pos)
			if d < best_d and not ring_hits(cand, rects):
				best = cand
				best_d = d
			x += 6.0
		y += 6.0
	return best
# endregion
