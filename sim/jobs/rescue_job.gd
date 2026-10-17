class_name RescueJob
extends Job
## Walk to a downed colonist, carry them (their cell follows the carrier)
## and lay them in a bed / shelter.

var patient_id: int
var bed_id: int
var _carrying := false


func _init(p_patient: int, p_bed: int) -> void:
	type = "rescue"
	patient_id = p_patient
	bed_id = p_bed


func tick(c: Colonist, sim: Simulation) -> int:
	var p := sim.colonists.get_by_id(patient_id)
	var bed := sim.buildings.get_by_id(bed_id)
	if p == null or not p.alive or p.health == null or not p.health.downed or bed == null:
		return Status.DONE if p == null or not p.alive or not p.health.downed else Status.FAILED
	if not _carrying:
		var m := c.move_toward(p.cell, sim)
		if m == GridMover.Move.FAILED:
			return Status.FAILED
		if m == GridMover.Move.MOVING:
			return Status.RUNNING
		_carrying = true
		p.health.carrier_id = c.id
		p.clear_path()
	var m2 := c.move_toward(bed.cell, sim)
	p.cell = c.cell
	if m2 == GridMover.Move.FAILED:
		return Status.FAILED
	if m2 == GridMover.Move.MOVING:
		return Status.RUNNING
	p.cell = bed.cell
	p.health.bed_id = bed.id
	sim.bus.colonist_rescued.emit(p.id, c.id)
	return Status.DONE


func on_end(_c: Colonist, sim: Simulation) -> void:
	var p := sim.colonists.get_by_id(patient_id)
	if p != null and p.health != null and p.health.carrier_id == _c.id:
		p.health.carrier_id = -1


func describe() -> String:
	return "Несёт раненого"
