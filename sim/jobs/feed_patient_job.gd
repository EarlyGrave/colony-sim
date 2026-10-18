class_name FeedPatientJob
extends Job
## Fetch food from storage, carry it to a downed patient and feed them.

var patient_id: int
var food_cell: Vector2i
var _fed := 0


func _init(p_patient: int, p_cell: Vector2i) -> void:
	type = "feed_patient"
	patient_id = p_patient
	food_cell = p_cell


func tick(c: Colonist, sim: Simulation) -> int:
	var p := sim.colonists.get_by_id(patient_id)
	if p == null or not p.alive or p.health == null:
		return Status.DONE
	if c.carry_count == 0:
		var item := sim.items.item_at(food_cell)
		if item == "" or not sim.defs.items[item].has("nutrition"):
			return Status.FAILED
		var m := c.move_toward(food_cell, sim)
		if m == GridMover.Move.FAILED:
			return Status.FAILED
		if m == GridMover.Move.MOVING:
			return Status.RUNNING
		if sim.items.take_at(food_cell, 1) <= 0:
			return Status.FAILED
		c.carry_item = item
		c.carry_count = 1
		return Status.RUNNING
	var m2 := c.move_toward(p.cell, sim)
	if m2 == GridMover.Move.FAILED:
		return Status.FAILED
	if m2 == GridMover.Move.MOVING:
		return Status.RUNNING
	_fed += 1
	if _fed < int(sim.defs.health["doctor"]["feed_ticks"]):
		return Status.RUNNING
	var item2 := c.carry_item
	sim.ledger.record_consumed(item2, 1, "eaten")
	sim.needs.add_food(p, float(sim.defs.items[item2]["nutrition"]))
	c.carry_item = ""
	c.carry_count = 0
	sim.bus.colonist_ate.emit(p.id, item2)
	sim.bus.patient_fed.emit(p.id, c.id)
	return Status.DONE


func describe() -> String:
	return "Feeding a patient"
