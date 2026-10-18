class_name ScrubJob
extends Job
## Walk to a waste stack near the base and scrub a little of it away.

var cell: Vector2i
var _work := 0.0


func _init(p_cell: Vector2i) -> void:
	type = "scrub"
	cell = p_cell


func tick(c: Colonist, sim: Simulation) -> int:
	if not sim.items.stacks.has(cell) or not sim.idle_work.can_scrub():
		return Status.DONE
	var m := c.move_toward(cell, sim)
	if m == GridMover.Move.FAILED:
		return Status.FAILED
	if m == GridMover.Move.MOVING:
		return Status.RUNNING
	_work += sim.jobs.work_tick(c, "cleanup")
	if _work < int(sim.defs.idle_work["cleanup"]["work_ticks"]):
		return Status.RUNNING
	sim.idle_work.complete_scrub(c, cell)
	return Status.DONE


func describe() -> String:
	return "Scrubbing waste"
