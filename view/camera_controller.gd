class_name CameraController
extends Camera2D
## Pan / zoom for touch and mouse. No hover, no right click.
## One finger or left mouse drag: pan. Two fingers: pinch zoom + pan.
## Mouse wheel: zoom at cursor. A press+release without movement is a tap.
##
## Single-finger input arrives as emulated mouse events (so HUD controls
## swallow them first); raw touch events are used only to track pinches.

signal tapped(world_pos: Vector2)

const TAP_SLOP := 14.0
const MIN_ZOOM := 0.25
const MAX_ZOOM := 3.0

var world_size := Vector2(2048, 2048)

var _touches := {}  # index -> screen position
var _pinch_dist := 0.0
var _pinch_mid := Vector2.ZERO
var _mouse_down := false
var _press_pos := Vector2.ZERO
var _moved := false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		if _touches.size() >= 2:
			_moved = true
			_begin_pinch()
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			_update_pinch()
	elif event is InputEventMouseButton:
		_on_mouse_button(event)
	elif event is InputEventMouseMotion:
		if _mouse_down and _touches.size() < 2:
			if not _moved and (event.position - _press_pos).length() > TAP_SLOP:
				_moved = true
			if _moved:
				_pan_screen(event.relative)


func _on_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				zoom_at(event.position, 1.15)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				zoom_at(event.position, 1.0 / 1.15)
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				_mouse_down = true
				_moved = _touches.size() >= 2
				_press_pos = event.position
			elif _mouse_down:
				_mouse_down = false
				if not _moved:
					tapped.emit(screen_to_world(event.position))


func _begin_pinch() -> void:
	var pts := _two_touches()
	_pinch_dist = maxf(pts[0].distance_to(pts[1]), 1.0)
	_pinch_mid = (pts[0] + pts[1]) * 0.5


func _update_pinch() -> void:
	var pts := _two_touches()
	var dist := maxf(pts[0].distance_to(pts[1]), 1.0)
	var mid: Vector2 = (pts[0] + pts[1]) * 0.5
	_pan_screen(mid - _pinch_mid)
	zoom_at(mid, dist / _pinch_dist)
	_pinch_dist = dist
	_pinch_mid = mid


func _two_touches() -> Array[Vector2]:
	var keys := _touches.keys()
	keys.sort()
	return [_touches[keys[0]], _touches[keys[1]]]


func _pan_screen(screen_delta: Vector2) -> void:
	position -= screen_delta / zoom.x
	_clamp_position()


## Zooms by `factor`, keeping the world point under `screen_pos` fixed.
func zoom_at(screen_pos: Vector2, factor: float) -> void:
	var before := screen_to_world(screen_pos)
	var z := clampf(zoom.x * factor, MIN_ZOOM, MAX_ZOOM)
	zoom = Vector2(z, z)
	var after := screen_to_world(screen_pos)
	position += before - after
	_clamp_position()


func screen_to_world(screen_pos: Vector2) -> Vector2:
	# Computed from our own state (anchor = center, no rotation) so it is
	# correct immediately after changing position/zoom in the same frame.
	return position + (screen_pos - get_viewport_rect().size * 0.5) / zoom.x


func _clamp_position() -> void:
	position = position.clamp(Vector2.ZERO, world_size)
