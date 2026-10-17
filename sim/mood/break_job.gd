class_name BreakJob
extends Job
## Mental break: the colonist stops working and wanders randomly.

var kind: String
var until: int
var radius: int
var _target := Vector2i(-1, -1)


func _init(p_kind: String, p_until: int, p_radius: int) -> void:
	type = "mental_break"
	kind = p_kind
	until = p_until
	radius = p_radius


func tick(c: Colonist, sim: Simulation) -> int:
	if sim.tick >= until:
		return Status.DONE
	if _target.x < 0 or c.cell == _target:
		_target = c.cell + Vector2i(sim.rng.randi_range(-radius, radius), sim.rng.randi_range(-radius, radius))
		if not sim.map.is_passable(_target):
			_target = Vector2i(-1, -1)
			return Status.RUNNING
	var m := c.move_toward(_target, sim)
	if m != GridMover.Move.MOVING:
		_target = Vector2i(-1, -1)
	return Status.RUNNING


func on_end(c: Colonist, _sim: Simulation) -> void:
	if c.mood != null:
		c.mood.break_kind = ""
	c.clear_path()


func describe() -> String:
	return "Срыв: бродит" if kind == "wander" else "Срыв: саботаж"
