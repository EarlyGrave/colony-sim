class_name DebtJob
extends Job
## Prison-style mental breaks: "riot" (smash nearby buildings) and
## "escape" (run for the map edge). Type "mental_break" like BreakJob.

var kind: String
var until: int
var _target := Vector2i(-1, -1)
var _next_hit := 0
var _building_id := -1


func _init(p_kind: String, p_until: int) -> void:
	type = "mental_break"
	kind = p_kind
	until = p_until


func tick(c: Colonist, sim: Simulation) -> int:
	if sim.tick >= until:
		return Status.DONE
	return _riot(c, sim) if kind == "riot" else _escape(c, sim)


func _riot(c: Colonist, sim: Simulation) -> int:
	var cfg: Dictionary = sim.debt.cfg
	var b: Building = sim.buildings.get_by_id(_building_id) if _building_id >= 0 else null
	if b == null or b.destroyed:
		b = sim.debt.riot_target(c)
		if b == null:
			return Status.DONE
		_building_id = b.id
	# Close enough (within one cell of the footprint) to smash it.
	var near := c.cell.x >= b.cell.x - 1 and c.cell.x <= b.cell.x + b.size.x \
			and c.cell.y >= b.cell.y - 1 and c.cell.y <= b.cell.y + b.size.y
	if not near:
		var adj := sim.pathfinder.best_adjacent(c.cell, b.cell)
		if adj.x < 0 or c.move_toward(adj, sim) == GridMover.Move.FAILED:
			_building_id = -1
		return Status.RUNNING
	c.clear_path()  # smashing in place: no stale path (it read as "stuck on a path")
	if sim.tick >= _next_hit:
		_next_hit = sim.tick + int(cfg["riot_hit_ticks"])
		sim.buildings.damage(b, float(cfg["riot_damage"]))
	return Status.RUNNING


func _escape(c: Colonist, sim: Simulation) -> int:
	if sim.debt.stopped_by_guard(c):
		sim.debt.on_caught(c)
		return Status.DONE
	if _target.x < 0:
		_target = sim.debt.edge_target(c)
		if _target.x < 0:
			return Status.DONE
	var m := c.move_toward(_target, sim)
	if m == GridMover.Move.ARRIVED:
		sim.debt.on_escaped(c)
		return Status.DONE
	if m == GridMover.Move.FAILED:
		_target = Vector2i(-1, -1)
	return Status.RUNNING


func on_end(c: Colonist, _sim: Simulation) -> void:
	if c.mood != null:
		c.mood.break_kind = ""
	c.clear_path()


func describe() -> String:
	return "Бунт: громит постройки" if kind == "riot" else "Побег к краю карты"
