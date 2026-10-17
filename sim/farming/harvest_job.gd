class_name HarvestJob
extends Job
## Walk to a mature plant and harvest it.

var cell: Vector2i
var _work := 0.0


func _init(p_cell: Vector2i) -> void:
	type = "harvest"
	cell = p_cell


func tick(c: Colonist, sim: Simulation) -> int:
	var p := sim.farming.plant_at(cell)
	if p == null or not sim.farming.is_mature(p):
		return Status.DONE
	var m := c.move_toward(cell, sim)
	if m == GridMover.Move.FAILED:
		return Status.FAILED
	if m == GridMover.Move.MOVING:
		return Status.RUNNING
	_work += sim.jobs.work_tick(c, "growing")
	if _work < int(sim.defs.plants[p.def_id]["harvest_ticks"]):
		return Status.RUNNING
	sim.farming.harvest(cell)
	return Status.DONE


func describe() -> String:
	return "Собирает урожай"
