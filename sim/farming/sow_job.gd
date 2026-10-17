class_name SowJob
extends Job
## Walk to an empty growing-zone cell and plant a crop.

var cell: Vector2i
var plant_id: String
var _work := 0.0


func _init(p_cell: Vector2i, p_plant: String) -> void:
	type = "sow"
	cell = p_cell
	plant_id = p_plant


func tick(c: Colonist, sim: Simulation) -> int:
	if not sim.farming.can_sow(cell):
		return Status.DONE
	var m := c.move_toward(cell, sim)
	if m == GridMover.Move.FAILED:
		return Status.FAILED
	if m == GridMover.Move.MOVING:
		return Status.RUNNING
	_work += sim.jobs.work_tick(c, "growing")
	if _work < int(sim.defs.plants[plant_id]["sow_ticks"]):
		return Status.RUNNING
	sim.farming.sow(cell, plant_id)
	return Status.DONE


func describe() -> String:
	return "Сажает"
