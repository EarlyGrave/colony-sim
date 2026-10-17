class_name FightJob
extends Job
## Reflex of an undrafted colonist: hit back at a creature in reach.


func _init() -> void:
	type = "fight"


func tick(c: Colonist, sim: Simulation) -> int:
	c.clear_path()
	var near := sim.threats.enemies_in_range(Vector2(c.cell), float(sim.combat.cfg["fight_back_range"]))
	if near.is_empty():
		return Status.DONE
	sim.combat.try_attack(c, near[0])
	return Status.RUNNING


func describe() -> String:
	return "Отбивается"
