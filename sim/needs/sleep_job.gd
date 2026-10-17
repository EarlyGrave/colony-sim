class_name SleepJob
extends Job
## Sleep in a reserved bed (fast rest), or right where standing (slow rest).

var bed_id: int
var _started := false


func _init(p_bed_id: int) -> void:
	type = "sleep"
	bed_id = p_bed_id


func tick(c: Colonist, sim: Simulation) -> int:
	var in_bed := false
	if bed_id >= 0:
		var b := sim.buildings.get_by_id(bed_id)
		if b == null:
			return Status.FAILED
		var m := c.move_toward(b.cell, sim)
		if m == GridMover.Move.FAILED:
			return Status.FAILED
		if m == GridMover.Move.MOVING:
			return Status.RUNNING
		in_bed = true
	if not _started:
		_started = true
		sim.bus.colonist_slept.emit(c.id, in_bed)
	sim.needs.rest_tick(c, in_bed)
	if sim.needs.state_of(c).rest >= float(sim.defs.needs["rest"]["wake_at"]):
		return Status.DONE
	return Status.RUNNING


func describe() -> String:
	return "Спит" + (" в кровати" if bed_id >= 0 else " на полу")
