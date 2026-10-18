class_name TrainJob
extends Job
## Hit a training dummy to practise the colonist's weakest combat skill.

var building_id: int
var skill: String
var _ticks := 0


func _init(p_building: int, p_skill: String) -> void:
	type = "train"
	building_id = p_building
	skill = p_skill


func tick(c: Colonist, sim: Simulation) -> int:
	var b := sim.buildings.get_by_id(building_id)
	if b == null or sim.idle_work.training_left(c) <= 0.0:
		return Status.DONE
	var m := c.move_toward(b.cell, sim)
	if m == GridMover.Move.FAILED:
		return Status.FAILED
	if m == GridMover.Move.MOVING:
		return Status.RUNNING
	sim.idle_work.train_tick(c, skill)
	_ticks += 1
	return Status.RUNNING if _ticks < int(sim.defs.idle_work["training"]["chunk_ticks"]) else Status.DONE


func describe() -> String:
	return "Training"
