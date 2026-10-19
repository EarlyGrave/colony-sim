class_name SocietyConds
extends RefCounted
## W1: trigger conditions over Cell Block Standing / Contraband / Informant for society quests (S1-S4).
## Registered into QuestLog via register_cond; every cond is false when its system is missing or disabled.
## Pure reads, no rng.


static func register(log: QuestLog) -> void:
	var sim := log.sim
	log.register_cond("block_standing_below", func(a: Variant) -> bool: return standing_cmp(sim, a, true))
	log.register_cond("block_standing_above", func(a: Variant) -> bool: return standing_cmp(sim, a, false))
	log.register_cond("contraband_stash_over", func(n: Variant) -> bool: return stash_over(sim, int(n)))
	log.register_cond("informant_alive", func(_a: Variant) -> bool: return informant_alive(sim))


## arg: {block, v}. block "any" = any block that has a living member.
static func standing_cmp(sim: Simulation, arg: Variant, below: bool) -> bool:
	if sim.blocks == null or not sim.blocks.is_enabled() or not (arg is Dictionary):
		return false
	var v := float(arg.get("v", 50.0))
	var want := str(arg.get("block", "any"))
	var ids: Array = sim.blocks.standing.keys()
	ids.sort()
	for b: String in ids:
		if want != "any" and b != want:
			continue
		if want == "any" and sim.blocks._members(b).is_empty():
			continue
		var s := sim.blocks.standing_of(b)
		if (below and s < v) or (not below and s > v):
			return true
	return false


static func stash_over(sim: Simulation, n: int) -> bool:
	return sim.contraband != null and sim.contraband.is_enabled() and sim.contraband.stash_total() > n


static func informant_alive(sim: Simulation) -> bool:
	if sim.blocks == null:
		return false
	var c := sim.colonists.get_by_id(sim.blocks.informant_id())
	return c != null and c.alive


## Block with the lowest Standing among blocks with living members ("" if none). Ties: block id order.
static func lowest_block(sim: Simulation) -> String:
	if sim.blocks == null:
		return ""
	var ids: Array = sim.blocks.standing.keys()
	ids.sort()
	var best := ""
	for b: String in ids:
		if sim.blocks._members(b).is_empty():
			continue
		if best == "" or sim.blocks.standing_of(b) < sim.blocks.standing_of(best):
			best = b
	return best
