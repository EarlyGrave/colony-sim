class_name RetreatJob
extends Job
## A badly hurt colonist runs to the shelter and hides (works without alarm).

var building_id: int


func _init(p_id: int) -> void:
	type = "retreat"
	building_id = p_id


func tick(c: Colonist, sim: Simulation) -> int:
	var b := sim.buildings.get_by_id(building_id)
	if b == null:
		return Status.FAILED
	var m := c.move_toward(b.cell, sim)
	if m == GridMover.Move.FAILED:
		return Status.FAILED
	if m == GridMover.Move.MOVING:
		return Status.RUNNING
	c.hidden = true
	return Status.DONE


func describe() -> String:
	return "Ранен, отступает"
