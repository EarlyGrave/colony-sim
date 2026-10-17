class_name OperateJob
extends Job
## Stand at a production building and run its recipe until one batch is done.

var building_id: int


func _init(p_id: int) -> void:
	type = "operate"
	building_id = p_id


func tick(c: Colonist, sim: Simulation) -> int:
	var b := sim.buildings.get_by_id(building_id)
	if b == null or not b.can_run_recipe():
		return Status.DONE
	var m := c.move_toward(b.cell, sim)
	if m == GridMover.Move.FAILED:
		return Status.FAILED
	if m == GridMover.Move.MOVING:
		return Status.RUNNING
	return Status.DONE if sim.buildings.work(b) else Status.RUNNING


func describe() -> String:
	return "Работает на установке"
