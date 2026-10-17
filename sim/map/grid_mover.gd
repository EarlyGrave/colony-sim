class_name GridMover
extends RefCounted
## Something that walks the grid along A* paths, one cell every `move_ticks`.

enum Move { ARRIVED, MOVING, FAILED }

var cell: Vector2i
var move_ticks := 3
var move_t := 0
## Fractional movement progress from speed bonuses.
var move_frac := 0.0
var path: Array[Vector2i] = []
var goal := Vector2i(-1, -1)


## Advances one tick toward `target`. Paths are cached and recomputed when the
## goal changes or the next cell becomes blocked.
func move_toward(target: Vector2i, sim: Simulation) -> int:
	if cell == target:
		clear_path()
		return Move.ARRIVED
	if goal != target or path.is_empty():
		# Keep move_t: a chaser re-pathing every tick must still make steps.
		goal = target
		path = sim.pathfinder.find_path(cell, target)
		if path.is_empty():
			return Move.FAILED
	move_t += 1
	move_t += _bonus_steps(sim)
	if move_t < move_ticks:
		return Move.MOVING
	move_t = 0
	var next: Vector2i = path[0]
	if not sim.pathfinder.is_walkable(next):
		path = sim.pathfinder.find_path(cell, target)
		return Move.FAILED if path.is_empty() else Move.MOVING
	cell = next
	path.pop_front()
	if cell == target:
		clear_path()
		return Move.ARRIVED
	return Move.MOVING


## Extra (or fewer) movement ticks gained this tick; 0 without bonuses.
func _bonus_steps(sim: Simulation) -> int:
	var g := move_gain(sim)
	if is_equal_approx(g, 1.0):
		return 0
	move_frac += g - 1.0
	var n := floori(move_frac)
	move_frac -= n
	return n


## Movement speed factor (1.0 = normal). Colonists override (perks).
func move_gain(_sim: Simulation) -> float:
	return 1.0


func clear_path() -> void:
	path.clear()
	goal = Vector2i(-1, -1)
	move_t = 0


## Fractional position for rendering (between cell and next path cell).
func visual_pos() -> Vector2:
	if path.is_empty() or move_ticks <= 0:
		return Vector2(cell)
	return Vector2(cell).lerp(Vector2(path[0]), float(move_t) / move_ticks)
