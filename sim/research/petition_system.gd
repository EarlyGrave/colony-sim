class_name PetitionSystem
extends RefCounted
## E1 Sentence Commutation Petition: four staged deliveries at the warden terminal after audit
## tier 2. Replaces the old tier-3 wall (phase 3 clears tier 3). Gated by balance "e1_enabled".
## Phases are 1-based. Partial deliveries accumulate.

var sim: Simulation
## phase (int) -> {item_id: delivered}; only for the phase in progress.
var delivered: Dictionary = {}
var done_phases: Array[int] = []


func _init(p_sim: Simulation) -> void:
	sim = p_sim


func enabled() -> bool:
	return bool(sim.defs.balance.get("e1_enabled", false))


func phase_defs() -> Array:
	return sim.defs.petitions.get("phases", [])


func phase_count() -> int:
	return phase_defs().size()


func preset_mult() -> float:
	var m: Dictionary = sim.defs.petitions.get("preset_mult", {})
	return float(m.get(str(sim.opts.get("preset_id", "standard_term")), 1.0))


## Item -> amount needed for phase p, preset-scaled.
func required(p: int) -> Dictionary:
	var out: Dictionary = {}
	if p < 1 or p > phase_count():
		return out
	var parts: Dictionary = (phase_defs()[p - 1] as Dictionary).get("parts", {})
	for item: String in parts:
		out[item] = maxi(1, roundi(float(parts[item]) * preset_mult() * (sim.quests.mod("petition_fee_mult") if sim.quests != null else 1.0)))  # region QX: Q6 tour discount
	return out


func remaining(p: int) -> Dictionary:
	var out: Dictionary = {}
	var have: Dictionary = delivered.get(p, {})
	var req := required(p)
	for item: String in req:
		out[item] = maxi(0, int(req[item]) - int(have.get(item, 0)))
	return out


## Phase that can be delivered now (-1 if none / locked).
func next_phase() -> int:
	if not enabled() or not sim.milestones.is_tier_done(2):
		return -1
	var p := done_phases.size() + 1
	return p if p <= phase_count() else -1


func is_done(p: int) -> bool:
	return p in done_phases


## Read-only snapshot for the UI: {enabled, phase (current, -1 = none), total, done, phases:[{...}]}.
func state() -> Dictionary:
	var rows: Array = []
	for i in phase_count():
		var p := i + 1
		var d: Dictionary = phase_defs()[i]
		rows.append({"phase": p, "id": str(d.get("id", "")), "title": str(d.get("title", "")), "done": is_done(p),
			"required": required(p), "delivered": (delivered.get(p, {}) as Dictionary).duplicate(),
			"reward": _reward_text(d.get("reward", {}))})
	return {"enabled": enabled(), "phase": next_phase(), "total": phase_count(), "done": done_phases.size(), "phases": rows}


func _reward_text(rw: Dictionary) -> String:
	var parts: Array = []
	if int(rw.get("debt_cut_pct", 0)) > 0:
		parts.append("debts -%d%%" % int(rw["debt_cut_pct"]))
	for item: String in rw.get("items", {}):
		parts.append("%d %s" % [int(rw["items"][item]), item])
	if int(rw.get("unlock_tier", 0)) > 0:
		parts.append("audit tier %d cleared" % int(rw["unlock_tier"]))
	return ", ".join(parts)


## Delivers what is in storage (never more than still required). True when the phase completed now.
func deliver(p: int) -> bool:
	if p != next_phase() or not sim.milestones.has_terminal():
		return false
	var have: Dictionary = delivered.get(p, {})
	var req := required(p)
	var near := sim.map_center()
	var keys := req.keys()
	keys.sort()
	for item: String in keys:
		var n := mini(int(req[item]) - int(have.get(item, 0)), sim.items.count_stored(item))
		if n > 0:
			sim.items.consume_stored(item, n, near)
			sim.ledger.record_consumed(item, n, "petition")
			have[item] = int(have.get(item, 0)) + n
	delivered[p] = have
	for item: String in req:
		if int(have.get(item, 0)) < int(req[item]):
			return false
	_complete(p)
	return true


func _complete(p: int) -> void:
	done_phases.append(p)
	delivered.erase(p)
	var d: Dictionary = phase_defs()[p - 1]
	var rw: Dictionary = d.get("reward", {})
	var pct := int(rw.get("debt_cut_pct", 0))
	if pct > 0:
		_cut_debt(pct)
	var items: Dictionary = rw.get("items", {})
	var ik := items.keys()
	ik.sort()
	for item: String in ik:
		sim.ledger.record_produced(item, int(items[item]), "petition")
		sim.items.drop(sim.map_center(), item, int(items[item]))
	var tier := int(rw.get("unlock_tier", 0))
	if tier > 0 and not sim.milestones.is_tier_done(tier):
		sim.milestones._unlock(tier)
	var text := str(d.get("letter", ""))
	sim.bus.letter_received.emit(str(d.get("title", "")), text)
	sim.bus.story_event.emit("petition_p%d" % p, text)
	sim.bus.petition_phase_done.emit(p)


## Forgives pct% of every colonist's total debt (keeps 1 unit so no payoff choice fires).
func _cut_debt(pct: int) -> void:
	for c in sim.colonists.list:
		var st: DebtState = sim.debt.state_of(c)
		if st == null or st.remaining() <= 1:
			continue
		var cut := mini(ceili(st.total * pct / 100.0), st.remaining() - 1)
		st.paid += cut


func has_state() -> bool:
	return not done_phases.is_empty() or not delivered.is_empty()


func state_parts() -> Array:
	var out: Array = ["e1", done_phases.duplicate()]
	var ps := delivered.keys()
	ps.sort()
	for p: int in ps:
		var row: Array = [p]
		var ks: Array = (delivered[p] as Dictionary).keys()
		ks.sort()
		for item: String in ks:
			row.append([item, delivered[p][item]])
		out.append(row)
	return out
