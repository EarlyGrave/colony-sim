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
	# region B3
	if b3_on():
		sim.listen(sim.bus.wave_repelled, func(_i: int) -> void: waves_repelled += 1)
	# endregion


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
	if not reviews_done.is_empty():  # region B3: only after a review, other hashes stay as they were
		out.append(["reviews", reviews_done.duplicate(), waves_repelled])
	return out


# region B3: Parole Reviews (mid-game goals after the tutorial). Gated by balance "b3".enabled.
var reviews_done: Array[String] = []
var waves_repelled := 0


func b3_on() -> bool:
	return bool(sim.defs.balance.get("b3", {}).get("enabled", false))


func review_defs() -> Array:
	return sim.defs.milestones.get("reviews", [])


## Aggregate debt paid, 0..100.
func debt_paid_pct() -> float:
	var total := 0
	var paid := 0
	for c in sim.colonists.list:
		var st: DebtState = sim.debt.state_of(c)
		if st != null:
			total += st.total
			paid += st.paid
	return 100.0 * paid / total if total > 0 else 0.0


func review_progress(r: Dictionary) -> float:
	var v := float(r.get("value", 1))
	match str(r.get("kind", "")):
		"debt_paid_pct":
			return clampf(debt_paid_pct() / v, 0.0, 1.0)
		"tier":
			return 1.0 if tier() >= int(v) else 0.0
		"waves_repelled":
			return clampf(waves_repelled / v, 0.0, 1.0)
	return 0.0


## Next unfinished review (reviews are sequential), {} if none or not active.
func current_review() -> Dictionary:
	if not b3_on():
		return {}
	if sim.tutorial != null and not sim.tutorial.finished():
		return {}
	for r: Dictionary in review_defs():
		if not reviews_done.has(str(r["id"])):
			return r
	return {}


## Called every tick from Simulation.step (checks once per second).
func tick_reviews() -> void:
	if sim.tick % Simulation.TICKS_PER_SECOND != 0:
		return
	var r := current_review()
	if r.is_empty() or review_progress(r) < 1.0:
		return
	reviews_done.append(str(r["id"]))
	var near := sim.map_center()
	var rw: Dictionary = r.get("reward", {})
	for item: String in _sorted_keys(rw):
		var n := int(rw[item])
		sim.ledger.record_produced(item, n, "review")
		sim.items.drop(near, item, n)
	sim.bus.letter_received.emit(str(r.get("title", "")), str(r.get("text", "")))
	sim.bus.story_event.emit("review_" + str(r["id"]), str(r.get("text", "")))
# endregion
