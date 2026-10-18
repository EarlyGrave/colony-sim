class_name MilestoneSystem
extends RefCounted
## Audit Deliveries (Satisfactory-style milestones): parts delivered at the
## warden terminal unlock research tiers. Partial deliveries accumulate.

var sim: Simulation
var cfg: Dictionary
## tier (int) -> {item_id: delivered count}; filled only for tiers in progress.
var delivered: Dictionary = {}
var done_tiers: Array[int] = [0, 1]  # sorted; T0/T1 are open at start


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	cfg = sim.defs.milestones.get("tiers", {})


func tier() -> int:
	return done_tiers.back()


func is_tier_done(t: int) -> bool:
	return t in done_tiers


func has_terminal() -> bool:
	return sim.buildings.count_of("warden_terminal") > 0


func required(t: int) -> Dictionary:
	return (cfg.get(str(t), {}) as Dictionary).get("parts", {})


func remaining(t: int) -> Dictionary:
	var out: Dictionary = {}
	var have: Dictionary = delivered.get(t, {})
	for item: String in required(t):
		out[item] = maxi(0, int(required(t)[item]) - int(have.get(item, 0)))
	return out


## Next tier that still needs an audit (-1 if none).
func next_tier() -> int:
	var t := tier() + 1
	return t if cfg.has(str(t)) else -1


## Delivers as many parts as are in storage (never more than still required).
## Only the next tier can be audited. Returns true when the tier unlocked now.
func deliver(t: int) -> bool:
	if t != next_tier() or not has_terminal():
		return false
	var have: Dictionary = delivered.get(t, {})
	var req := required(t)
	var near := sim.map_center()
	for item: String in _sorted_keys(req):
		var need := int(req[item]) - int(have.get(item, 0))
		var n := mini(need, sim.items.count_stored(item))
		if n > 0:
			sim.items.consume_stored(item, n, near)
			sim.ledger.record_consumed(item, n, "audit")
			have[item] = int(have.get(item, 0)) + n
	delivered[t] = have
	for item: String in req:
		if int(have.get(item, 0)) < int(req[item]):
			return false
	_unlock(t)
	return true


func _unlock(t: int) -> void:
	done_tiers.append(t)
	done_tiers.sort()
	delivered.erase(t)
	# Research core interface (R2a): tier gate for techs.
	var r: Variant = sim.get("research")
	if r != null and r.has_method("unlock_tier"):
		r.call("unlock_tier", t)
	var letter: Dictionary = cfg[str(t)].get("letter", {})
	sim.bus.letter_received.emit(str(letter.get("title", "")), str(letter.get("text", "")))
	sim.bus.story_event.emit("audit_tier_%d" % t, str(letter.get("text", "")))


func _sorted_keys(d: Dictionary) -> Array:
	var k := d.keys()
	k.sort()
	return k


## Canonical state for state_hash (sorted, no Dictionary order dependence).
func state_parts() -> Array:
	var out: Array = [done_tiers.duplicate()]
	var ts := delivered.keys()
	ts.sort()
	for t: int in ts:
		var row: Array = [t]
		for item: String in _sorted_keys(delivered[t]):
			row.append([item, delivered[t][item]])
		out.append(row)
	return out
