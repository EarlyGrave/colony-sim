class_name CameraController
extends Camera3D
## "Broadcast" camera: perspective, tilted like a football TV camera (not
## isometric), always looking north. Pan / zoom for touch and mouse; no hover,
## no right click. One finger or left mouse drag: pan. Two fingers: pinch zoom
## + pan. Mouse wheel: zoom at cursor. A press+release without movement is a tap.
##
## Public coordinates are 2D world pixels (WorldView space, TILE px per cell)
## so GameController stays unaware of the 3D scene. One cell = one 3D unit.
##
## Single-finger input arrives as emulated mouse events (so HUD controls
## swallow them first); raw touch events are used only to track pinches.

signal tapped(world_pos: Vector2)

const TAP_SLOP := 14.0
const MIN_ZOOM := 0.35
const MAX_ZOOM := 3.0
const PITCH_DEG := 52.0  ## angle above the ground plane
const BASE_DISTANCE := 28.0  ## camera distance (cells) at zoom 1
const FOV_DEG := 38.0

var world_size := Vector2(2048, 2048)
## Ground point the camera looks at, in world pixels.
var focus := Vector2.ZERO:
	set(v):
		focus = v.clamp(Vector2.ZERO, world_size)
		_apply()
var zoom_level := 1.0:
	set(v):
		zoom_level = clampf(v, MIN_ZOOM, MAX_ZOOM)
		_apply()

var _touches := {}  # index -> screen position
var _pinch_dist := 0.0
var _pinch_mid := Vector2.ZERO
var _mouse_down := false
var _press_pos := Vector2.ZERO
var _moved := false


func _ready() -> void:
	fov = FOV_DEG
	near = 0.5
	far = 400.0
	current = true
	_apply()


func _apply() -> void:
	var target := Vector3(focus.x / WorldView.TILE, 0.0, focus.y / WorldView.TILE)
	var pitch := deg_to_rad(PITCH_DEG)
	var dist := BASE_DISTANCE / zoom_level
	# Behind the target = towards +z (south), so north is up on screen.
	position = target + Vector3(0.0, sin(pitch), cos(pitch)) * dist
	rotation = Vector3(-pitch, 0.0, 0.0)


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
				_pan_screen(event.position - event.relative, event.position)


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
	_pan_screen(_pinch_mid, mid)
	zoom_at(mid, dist / _pinch_dist)
	_pinch_dist = dist
	_pinch_mid = mid


func _two_touches() -> Array[Vector2]:
	var keys := _touches.keys()
	keys.sort()
	return [_touches[keys[0]], _touches[keys[1]]]


## Drags the ground: the point under `from` ends up under `to`.
func _pan_screen(from: Vector2, to: Vector2) -> void:
	focus += screen_to_world(from) - screen_to_world(to)


## Zooms by `factor`, keeping the ground point under `screen_pos` fixed.
func zoom_at(screen_pos: Vector2, factor: float) -> void:
	var before := screen_to_world(screen_pos)
	zoom_level *= factor
	focus += before - screen_to_world(screen_pos)


## Ground point (world pixels) under a screen position: ray vs plane y = 0.
func screen_to_world(screen_pos: Vector2) -> Vector2:
	var o := project_ray_origin(screen_pos)
	var d := project_ray_normal(screen_pos)
	if d.y > -0.01:
		d.y = -0.01  # ray at/above the horizon: clamp to a far ground point
	var t := -o.y / d.y
	var p := o + d * t
	return Vector2(p.x, p.z) * WorldView.TILE


## Screen position of a 3D point given in cells (x, height, z).
func cell_to_screen(p: Vector3) -> Vector2:
	return unproject_position(p)
