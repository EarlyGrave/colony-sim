class_name Colonist
extends RefCounted
## A prisoner. State only plus movement; decisions come from JobSystem.

enum Move { ARRIVED, MOVING, FAILED }

var id: int
var display_name: String
var cell: Vector2i
var hp: float
var max_hp: float
var alive := true
## Inside a shelter (invisible and untargetable).
var hidden := false
var move_ticks: int
var move_t := 0
var path: Array[Vector2i] = []
var goal := Vector2i(-1, -1)

var job: Job = null
var idle_until := 0
var carry_item := ""
var carry_count := 0
## job key -> tick until which that target is considered unreachable
var unreachable: Dictionary = {}

## Diagnostics: ticks since the colonist last changed cell while it had a job.
var stuck_ticks := 0


func _init(p_id: int, p_name: String, p_cell: Vector2i, cfg: Dictionary) -> void:
	id = p_id
	display_name = p_name
	cell = p_cell
	max_hp = float(cfg["max_hp"])
	hp = max_hp
	move_ticks = int(cfg["move_ticks"])


## Advances one tick toward `target`. Paths are cached and recomputed when the
## goal changes or the next cell becomes blocked.
func move_toward(target: Vector2i, sim: Simulation) -> int:
	if cell == target:
		_clear_path()
		return Move.ARRIVED
	if goal != target or path.is_empty():
		goal = target
		path = sim.pathfinder.find_path(cell, target)
		move_t = 0
		if path.is_empty():
			return Move.FAILED
	move_t += 1
	if move_t < move_ticks:
		return Move.MOVING
	move_t = 0
	var next: Vector2i = path[0]
	if not sim.map.is_passable(next):
		path = sim.pathfinder.find_path(cell, target)
		return Move.FAILED if path.is_empty() else Move.MOVING
	cell = next
	path.pop_front()
	if cell == target:
		_clear_path()
		return Move.ARRIVED
	return Move.MOVING


func _clear_path() -> void:
	path.clear()
	goal = Vector2i(-1, -1)
	move_t = 0


## Fractional position for rendering (between cell and next path cell).
func visual_pos() -> Vector2:
	if path.is_empty() or move_ticks <= 0:
		return Vector2(cell)
	return Vector2(cell).lerp(Vector2(path[0]), float(move_t) / move_ticks)


func is_unreachable(key: String, now: int) -> bool:
	return int(unreachable.get(key, -1)) > now
