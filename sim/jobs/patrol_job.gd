class_name PatrolJob
extends Job
## Walk a few legs of the patrol route, watching for creatures. Grants a
## little melee/shooting xp while walking.

var points: Array[Vector2i] = []
var _legs_left: int
var _i := 0
var _tick := 0


func _init(p_points: Array[Vector2i], start: int, legs: int) -> void:
	type = "patrol"
	points = p_points
	_i = start % maxi(points.size(), 1)
	_legs_left = legs


func tick(c: Colonist, sim: Simulation) -> int:
	if points.is_empty() or _legs_left <= 0:
		return Status.DONE
	var cfg: Dictionary = sim.defs.idle_work["patrol"]
	_tick += 1
	if _tick % int(cfg["scan_every"]) == 0:
		sim.idle_work.patrol_scan(c)
	_train(c, sim, float(cfg["xp_per_tick"]))
	var m := c.move_toward(points[_i], sim)
	if m == GridMover.Move.MOVING:
		return Status.RUNNING
	# Arrived, or the point is unreachable: skip to the next one.
	_legs_left -= 1
	_i = (_i + 1) % points.size()
	return Status.RUNNING if _legs_left > 0 else Status.DONE


func _train(c: Colonist, sim: Simulation, xp: float) -> void:
	var skill := sim.idle_work.training_skill(c)
	if skill != "" and c.skills.add_xp(sim.defs, skill, xp):
		sim.bus.skill_leveled.emit(c.id, skill, c.skills.level(skill))


func on_end(c: Colonist, sim: Simulation) -> void:
	sim.idle_work.patrol_finished(c)


func describe() -> String:
	return "Patrolling"
