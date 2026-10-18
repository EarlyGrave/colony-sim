class_name BuildJob
extends Job
## Walk to a fully supplied blueprint and build it.

var blueprint_id: int


func _init(p_id: int) -> void:
	type = "build"
	blueprint_id = p_id


func tick(c: Colonist, sim: Simulation) -> int:
	var bp := sim.buildings.get_blueprint(blueprint_id)
	if bp == null or not bp.has_all_materials():
		return Status.DONE
	var m := c.move_toward(bp.cell, sim)
	if m == GridMover.Move.FAILED:
		return Status.FAILED
	if m == GridMover.Move.MOVING:
		return Status.RUNNING
	bp.work_done += sim.jobs.work_tick(c, "construction") * maxf(0.0, 1.0 + sim.perks.mod(c, "build_speed"))  # region perks
	if bp.work_done < bp.work_total:
		return Status.RUNNING
	sim.buildings.complete_blueprint(bp, c)
	return Status.DONE


func describe() -> String:
	return "Building"
