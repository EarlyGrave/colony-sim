class_name ResearchOperator
extends RefCounted
## Who runs a research bench and how fast. Bench defs carry `operator_slot`
## ("colonist" now; a future AI chip slot plugs in via speed()).
##
## Research core interface used (owned by R2a, `sim.research`):
##   active() -> String            id of the tech being researched, "" if none
##   add_progress(work: float)     adds bench-ticks to the active tech


static func system(sim: Simulation) -> ResearchSystem:
	return sim.research


static func active(sim: Simulation) -> String:
	var r := system(sim)
	return "" if r == null else str(r.active())


## Bench-ticks added per tick by `op` (a Colonist for slot "colonist").
static func speed(sim: Simulation, b: Building, op: Colonist) -> float:
	if b != null and sim.chips.has_chip(b):  # region T4: chip operator {kind:"chip"}
		return sim.chips.bench_speed(b)
	if op == null or b == null or b.broken or b.destroyed:
		return 0.0
	var slot := str(b.def.get("operator_slot", "colonist"))
	if slot != "colonist":
		return 0.0  # chip slot: deferred
	var base := float(sim.defs.balance["research"]["bench_rate"])
	return base * (0.5 + float(op.skills.level("crafting")) / 10.0)


static func add_progress(sim: Simulation, amount: float) -> void:
	var r := system(sim)
	if r != null and amount > 0.0:
		r.add_progress(amount)
