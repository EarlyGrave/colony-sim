class_name OperateJob
extends Job
## Stand at a production building and run its recipe until one batch is done.

var building_id: int
## Fractional work progress carried between ticks (skill speed).
var _acc := 0.0
## Work type whose skill is trained ("operating", or "cooking" for a stove).
var work_type := "operating"


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
	# region perks
	var stat := "operate_speed" if work_type == "operating" else "craft_speed"
	_acc += sim.jobs.work_tick(c, work_type) * maxf(0.0, 1.0 + sim.perks.mod(c, stat) + sim.passives.mod(c, stat))  # F11W3
	# endregion
	var steps := int(_acc)
	_acc -= steps
	return Status.DONE if sim.buildings.work(b, steps, c) else Status.RUNNING


func describe() -> String:
	return "Working a machine"
