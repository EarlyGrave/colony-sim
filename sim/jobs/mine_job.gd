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
	_work += sim.jobs.work_tick(c, "mining") * maxf(0.0, 1.0 + sim.perks.mod(c, "mining_speed") + sim.passives.mod(c, "mining_speed"))  # region perks + F11W3
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
		got = sim.map.mine_node(target, float(cfg["yield"]), maxf(0.0, 1.0 + sim.perks.mod(c, "ore_yield") + sim.passives.mod(c, "ore_yield")))  # F11W3
		# Infinite node: the designation stays until the player removes it.
	else:
		got = _mine_legacy(c, sim, cfg)
	got = _passive_rules(c, sim, got)  # region F11W3
	if got > 0:
		sim.ledger.record_produced(item, got, "mining")
		sim.items.drop(c.cell, item, got)
		sim.bus.item_mined.emit(target, item, got)
		sim.colonists.rec(c)["ore_mined"] += got  # region F3
		sim.colonists.record_changed(c)
	return Status.DONE


# region F11W3: keystone rules taint_mining, ore_skim, ore_installment (no rng; ints only)
func _passive_rules(c: Colonist, sim: Simulation, got: int) -> int:
	if got <= 0 or not sim.passives.enabled():
		return got
	if sim.passives.rule(c, "taint_mining"):
		if sim.mutation != null and sim.mutation.is_tainted(target):
			got *= 2
		sim.contamination.add(float(got) / 50.0)
	if sim.passives.rule(c, "ore_installment"):
		var st := sim.passives.state_of(c)
		var acc := int(st.counters.get("ore_credit", 0)) + got
		var units := acc / 10
		st.counters["ore_credit"] = acc - units * 10
		if units > 0:
			sim.debt.credit(c, units)
	if sim.passives.rule(c, "ore_skim") and sim.contraband != null:
		got -= sim.contraband.skim_ore(c, got / 10)
	return got
# endregion


func _mine_legacy(c: Colonist, sim: Simulation, cfg: Dictionary) -> int:
	var item: String = cfg["item"]
	var got := sim.map.take_from_deposit(target, PerkHooks.scaled(c, "ore_yield", float(cfg["yield"]), 1.0 + sim.perks.mod(c, "ore_yield") + sim.passives.mod(c, "ore_yield")))  # region perks + F11W3
	return got


func describe() -> String:
	return "Mining ore"
