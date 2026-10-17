class_name RepairJob
extends Job
## Walk to a damaged / worn / broken building and fix it.

var building_id: int
var _work := 0.0


func _init(p_id: int) -> void:
	type = "repair"
	building_id = p_id


func tick(c: Colonist, sim: Simulation) -> int:
	var b := sim.buildings.get_by_id(building_id)
	if b == null or not b.needs_repair(sim):
		return Status.DONE
	var m := c.move_toward(b.cell, sim)
	if m == GridMover.Move.FAILED:
		return Status.FAILED
	if m == GridMover.Move.MOVING:
		return Status.RUNNING
	_work += sim.jobs.work_tick(c, "repair")
	if _work < int(sim.defs.balance["repair"]["work_ticks"]):
		return Status.RUNNING
	sim.buildings.repair(b)
	return Status.DONE


func describe() -> String:
	return "Чинит"
