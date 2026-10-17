class_name FleeJob
extends Job
## Run to the shelter and hide inside until the alarm is lifted.

var building_id: int


func _init(p_id: int) -> void:
	type = "flee"
	building_id = p_id
	fail_key = "flee"


func tick(c: Colonist, sim: Simulation) -> int:
	if not sim.alarm:
		return Status.DONE
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
	return "Бежит в укрытие"
