class_name DetailJob
extends Job
## W2 Volunteer Detail: walk to the hazardous site and work there until the petition detail
## has booked enough work ticks for this volunteer. Created only by PetitionSystem.

var site: Vector2i


func _init(p_site: Vector2i) -> void:
	type = "detail"
	site = p_site


func tick(c: Colonist, sim: Simulation) -> int:
	if not sim.petition.detail_active():
		return Status.DONE
	var m := c.move_toward(site, sim)
	if m == GridMover.Move.FAILED:
		return Status.FAILED
	if m == GridMover.Move.MOVING:
		return Status.RUNNING
	return Status.DONE if sim.petition.detail_work(c) else Status.RUNNING


func describe() -> String:
	return "Volunteer detail"
