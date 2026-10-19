class_name Remission
extends RefCounted
## EN4: 4th ending "Remission" (proposed, off by default: data/endings.json remission.enabled).
## Cure (recipe `cure`) feeds powered Decontamination Pylons, each cure lowers contamination.
## Contamination below quiet_frac of max for quiet_days in a row -> ending_won("remission").
## Deterministic: plain arithmetic, no rng.

var sim: Simulation
var cures_used := 0
var quiet_ticks := 0


func _init(p_sim: Simulation) -> void:
	sim = p_sim


func _cfg() -> Dictionary:
	return sim.defs.endings.get("remission", {})


func enabled() -> bool:
	return bool(_cfg().get("enabled", false))


func active() -> bool:
	return enabled() and sim.path() == "remission" and not sim.endings.won("remission")


func frac() -> float:
	return sim.contamination.level / float(sim.defs.balance["contamination"]["max"])


func tick() -> void:
	if not active():
		return
	if sim.tick % sim.ticks_per_day == 0:
		_pylons_daily()
	if cures_used > 0 and frac() < float(_cfg().get("quiet_frac", 0.1)):
		quiet_ticks += 1
	else:
		quiet_ticks = 0
	if quiet_ticks >= roundi(float(_cfg().get("quiet_days", 15)) * sim.ticks_per_day):
		sim.bus.letter_received.emit("Remission", str(_cfg().get("lines", {}).get("won", "")))
		sim.endings.mark_won("remission")


func _pylons_daily() -> void:
	var item := str(_cfg().get("item", "cure"))
	var bid := str(_cfg().get("building", "decon_pylon"))
	for b in sim.buildings.list:
		if b.def_id != bid or b.destroyed or b.broken:
			continue
		if sim.power.factor_for(b) < float(_cfg().get("min_power_factor", 0.5)):
			continue
		if sim.items.count_stored(item) < 1:
			return
		sim.items.consume_stored(item, 1, b.cell)
		sim.ledger.record_consumed(item, 1, "remission")
		sim.contamination.level = maxf(0.0, sim.contamination.level - float(_cfg().get("drop_per_cure", 3.0)))
		cures_used += 1


func state_parts() -> Array:
	if cures_used == 0:
		return []
	return [cures_used, quiet_ticks]
