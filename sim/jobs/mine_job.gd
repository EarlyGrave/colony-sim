class_name MineJob
extends Job
## Walk next to a designated deposit, dig, drop ore at the feet.

var target: Vector2i
var _stand := Vector2i(-1, -1)
var _work := 0


func _init(p_target: Vector2i) -> void:
	type = "mine"
	target = p_target


func tick(c: Colonist, sim: Simulation) -> int:
	if not sim.map.is_deposit(target):
		return Status.DONE
	if _stand.x < 0:
		_stand = sim.pathfinder.best_adjacent(c.cell, target)
		if _stand.x < 0:
			return Status.FAILED
	var m := c.move_toward(_stand, sim)
	if m == GridMover.Move.FAILED:
		return Status.FAILED
	if m == GridMover.Move.MOVING:
		return Status.RUNNING
	_work += 1
	if _work < int(sim.defs.balance["mining"]["work_ticks"]):
		return Status.RUNNING
	var got := sim.map.take_from_deposit(target, int(sim.defs.balance["mining"]["yield"]))
	if got > 0:
		sim.ledger.record_produced("essence_ore", got, "mining")
		sim.items.drop(c.cell, "essence_ore", got)
		sim.bus.item_mined.emit(target, "essence_ore", got)
	return Status.DONE


func describe() -> String:
	return "Добывает руду"
