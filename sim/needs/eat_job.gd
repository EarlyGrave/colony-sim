class_name EatJob
extends Job
## Walk to a stack of stored food and eat one unit.

var cell: Vector2i
var _eating := 0


func _init(p_cell: Vector2i) -> void:
	type = "eat"
	cell = p_cell


func tick(c: Colonist, sim: Simulation) -> int:
	var item := sim.items.item_at(cell)
	if item == "" or not sim.defs.items[item].has("nutrition"):
		return Status.DONE  # somebody took it; the needs system looks again
	var m := c.move_toward(cell, sim)
	if m == GridMover.Move.FAILED:
		return Status.FAILED
	if m == GridMover.Move.MOVING:
		return Status.RUNNING
	_eating += 1
	if _eating < int(sim.defs.needs["food"]["eat_ticks"]):
		return Status.RUNNING
	if sim.items.take_at(cell, 1) > 0:
		sim.ledger.record_consumed(item, 1, "eaten")
		sim.needs.add_food(c, float(sim.defs.items[item]["nutrition"]))
		sim.bus.colonist_ate.emit(c.id, item)
	return Status.DONE


func describe() -> String:
	return "Ест"
