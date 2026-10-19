class_name ResearchJob
extends Job
## Sit at a research bench and push the active tech forward while it lasts.

var building_id: int


func _init(p_id: int) -> void:
	type = "research"
	building_id = p_id


func tick(c: Colonist, sim: Simulation) -> int:
	var b := sim.buildings.get_by_id(building_id)
	if b == null or b.broken or b.destroyed or ResearchOperator.active(sim) == "":
		return Status.DONE
	var m := c.move_toward(b.cell, sim)
	if m == GridMover.Move.FAILED:
		return Status.FAILED
	if m == GridMover.Move.MOVING:
		return Status.RUNNING
	ResearchOperator.add_progress(sim, ResearchOperator.speed(sim, b, c))
	sim.progression.award(c, "crafting", float(sim.defs.skills["xp_per_work_tick"]), "research", false)  # region progression
	return Status.RUNNING


func describe() -> String:
	return "Researching"
