class_name CalibrateJob
extends Job
## Stand at a chip building for `calibrate_ticks` ticks and reset its calibration timer.

var building_id: int
var _work := 0


func _init(p_id: int) -> void:
	type = "calibrate"
	building_id = p_id


func tick(c: Colonist, sim: Simulation) -> int:
	var b := sim.buildings.get_by_id(building_id)
	if b == null or not sim.chips.needs_calibration(b):
		return Status.DONE
	var m := c.move_toward(b.cell, sim)
	if m == GridMover.Move.FAILED:
		return Status.FAILED
	if m == GridMover.Move.MOVING:
		return Status.RUNNING
	_work += 1
	if _work < int(sim.defs.chips["calibrate_ticks"]):
		return Status.RUNNING
	sim.chips.calibrate(b)
	return Status.DONE


func describe() -> String:
	return "Calibrating AI chip"
