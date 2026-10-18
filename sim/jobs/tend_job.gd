class_name TendJob
extends Job
## Walk to a patient and tend their injuries.

var patient_id: int
var _work := 0.0


func _init(p_patient: int) -> void:
	type = "tend"
	patient_id = p_patient


func tick(c: Colonist, sim: Simulation) -> int:
	var p := sim.colonists.get_by_id(patient_id)
	if p == null or not p.alive or not TendGiver.has_untended(p):
		return Status.DONE
	if p.health.carrier_id >= 0 and p.health.carrier_id != c.id:
		return Status.FAILED
	var m := c.move_toward(p.cell, sim)
	if m == GridMover.Move.FAILED:
		return Status.FAILED
	if m == GridMover.Move.MOVING:
		return Status.RUNNING
	_work += sim.jobs.work_tick(c, "doctoring")
	if _work < float(sim.defs.health["doctor"]["tend_ticks"]):
		return Status.RUNNING
	var mult := float(sim.defs.health["doctor"]["self_quality_mult"]) if p == c else 1.0
	var n := sim.health.tend(p, c, mult)
	sim.bus.colonist_tended.emit(p.id, c.id, n)
	return Status.DONE


func describe() -> String:
	return "Tending wounds"
