class_name BeaconSystem
extends RefCounted
## S2 Penance Beacons: endless essence sink. A Beacon Launcher (not broken) turns
## plate + refined_essence into temporary beacons; each live beacon cuts debt per day with
## diminishing returns (capped), then decays. Gated by balance "s2_enabled". Numbers: data/beacons.json.

var sim: Simulation
var cfg: Dictionary
var expiry: Array[int] = []  # expiry tick of each live beacon (ascending)
var progress: Dictionary = {}  # launcher building id -> accumulated build progress
var launched := 0
var total_cut := 0


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	cfg = sim.defs.beacons


func enabled() -> bool:
	return bool(sim.defs.balance.get("s2_enabled", false))


func has_state() -> bool:
	return launched > 0 or not progress.is_empty()


## Debt cut per day in percent of total debt (diminishing returns, capped).
func rate_pct() -> float:
	var r := 0.0
	var k := 1.0
	for i in expiry.size():
		r += float(cfg.get("cut_pct", 3.0)) * k
		k *= float(cfg.get("diminish", 0.8))
	return minf(r, float(cfg.get("cap_pct", 10.0)))


func state() -> Dictionary:
	var nd := -1
	if not expiry.is_empty():
		nd = expiry[0]
	return {"enabled": enabled(), "alive": expiry.size(), "next_decay": nd, "debt_rate_cut": rate_pct(),
		"launched": launched, "total_cut": total_cut, "max_alive": int(cfg.get("max_alive", 8))}


func tick() -> void:
	if not enabled():
		return
	var tpd := sim.ticks_per_day
	if tpd > 0 and sim.tick % tpd == 0:
		_daily()
	var need := float(cfg.get("build_ticks", 600))
	var cost: Dictionary = cfg.get("cost", {})
	var ks := cost.keys()
	ks.sort()
	for b in sim.buildings.list:
		if b.def_id != str(cfg.get("building", "beacon_launcher")) or b.destroyed or b.broken:
			continue
		if expiry.size() >= int(cfg.get("max_alive", 8)):
			continue
		var ok := true
		for item: String in ks:
			if sim.items.count_stored(item) < int(cost[item]):
				ok = false
		if not ok:
			continue
		var p := float(progress.get(b.id, 0.0)) + sim.power.factor_for(b)
		if p >= need:
			for item: String in ks:
				sim.items.consume_stored(item, int(cost[item]), b.cell)
				sim.ledger.record_consumed(item, int(cost[item]), "beacon")
			expiry.append(sim.tick + int(cfg.get("life_days", 3)) * tpd)
			launched += 1
			p = 0.0
			sim.bus.beacon_launched.emit(expiry.size())
		progress[b.id] = p


func _daily() -> void:
	while not expiry.is_empty() and expiry[0] <= sim.tick:
		expiry.remove_at(0)
	var pct := rate_pct()
	if pct <= 0.0:
		return
	for c in sim.colonists.list:
		var st: DebtState = sim.debt.state_of(c)
		if not c.alive or st == null or st.remaining() <= 1:
			continue
		var cut := mini(ceili(st.total * pct / 100.0), st.remaining() - 1)
		st.paid += cut
		total_cut += cut


func state_parts() -> Array:
	return ["s2", expiry.duplicate(), launched, total_cut]
