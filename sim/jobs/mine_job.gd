class_name MineJob
extends Job
## Walk next to a designated deposit, dig, drop ore at the feet.

var target: Vector2i
var _stand := Vector2i(-1, -1)
var _work := 0.0


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
	_work += sim.jobs.work_tick(c, "mining") * maxf(0.0, 1.0 + sim.perks.mod(c, "mining_speed"))  # region perks
	if _work < int(sim.defs.balance["mining"]["work_ticks"]):
		return Status.RUNNING
	var cfg: Dictionary = sim.defs.balance["mining"]
	var item: String = cfg["item"]
	var got := 0
	if sim.map.node_rubbled(target, sim.tick):
		return Status.DONE  # buried while walking/digging
	if sim.map.is_node(target):  # region A1a: infinite node, resource + purity decide the yield
		item = String(NodeData.resource(sim.map.node_resource(target)).get("item", item))
		if not sim.defs.items.has(item):
			item = String(cfg["item"])
		got = sim.map.mine_node(target, float(cfg["yield"]), maxf(0.0, 1.0 + sim.perks.mod(c, "ore_yield")))
		# Infinite node: the designation stays until the player removes it.
	else:
		got = _mine_legacy(c, sim, cfg)
	if got > 0:
		sim.ledger.record_produced(item, got, "mining")
		sim.items.drop(c.cell, item, got)
		sim.bus.item_mined.emit(target, item, got)
	return Status.DONE


func _mine_legacy(c: Colonist, sim: Simulation, cfg: Dictionary) -> int:
	var item: String = cfg["item"]
	var got := sim.map.take_from_deposit(target, PerkHooks.scaled(c, "ore_yield", float(cfg["yield"]), 1.0 + sim.perks.mod(c, "ore_yield")))  # region perks
	return got


func describe() -> String:
	return "Mining ore"
