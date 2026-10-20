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
		out[item] = maxi(1, roundi(float(parts[item]) * preset_mult() * (sim.quests.mod("petition_fee_mult") if sim.quests != null else 1.0) * sim.endings.effect("petition_fee_mult", 1.0)))  # region F9W2 path x quest; region QX: Q6 tour discount
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
	_alt_rows(rows)  # region W2
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
	return not done_phases.is_empty() or not delivered.is_empty() or not detail.is_empty()


func state_parts() -> Array:
	var out: Array = ["e1", done_phases.duplicate()]
	if not detail.is_empty():  # region W2 (hash part only while a detail runs)
		out.append(["w2", detail["alt"], detail["ids"].duplicate(), detail["done"].duplicate(), detail["start"]])
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


# region W2: Petition Waivers. One alternative payment per phase (petitions.json "alt"), paid in people / risk.
# "detail": volunteers work at a hazardous site; "informant": suspicion + Standing hit. Completion = _complete(p).
## {phase, alt, ids:[int], done:[int], work:{id:ticks}, site:Vector2i, start:tick}; empty = no detail running.
var detail: Dictionary = {}
const DETAIL_PROTECTED := ["draft", "eat", "feed_patient", "fight", "flee", "mental_break", "rescue", "retreat", "sleep", "tend"]


func alt_def(p: int) -> Dictionary:
	if p < 1 or p > phase_count():
		return {}
	return (phase_defs()[p - 1] as Dictionary).get("alt", {})


## "" when the alt of phase p can be started now, else a short reason (the UI shows it greyed out).
func alt_block_reason(p: int) -> String:
	var a := alt_def(p)
	if a.is_empty():
		return "none"
	if p != next_phase() or not sim.milestones.has_terminal():
		return "locked"
	if not detail.is_empty():
		return "detail under way"
	match str(a.get("kind", "")):
		"detail":
			if _volunteers(int(a.get("volunteers", 3))).size() < int(a.get("volunteers", 3)):
				return "not enough healthy volunteers"
			if _site().x < 0:
				return "no site"
		"informant":
			if sim.contraband == null or not sim.contraband.is_enabled() or sim.blocks == null or not sim.blocks.is_enabled():
				return "no covert channel"
			if not SocietyConds.informant_alive(sim):
				return "no informant"
		_:
			return "none"
	return ""


func alt_available(p: int) -> bool:
	return alt_block_reason(p) == ""


func _alt_rows(rows: Array) -> void:
	for r: Dictionary in rows:
		var p := int(r["phase"])
		var a := alt_def(p)
		if a.is_empty() or bool(r["done"]):
			continue
		var reason := alt_block_reason(p) if p == next_phase() else "locked"
		r["alt"] = {"id": str(a.get("id", "")), "title": str(a.get("title", "")), "cost": str(a.get("cost", "")),
			"available": reason == "", "reason": reason,
			"active": not detail.is_empty() and int(detail["phase"]) == p,
			"progress": detail_progress() if not detail.is_empty() and int(detail["phase"]) == p else 0.0}


func detail_active() -> bool:
	return not detail.is_empty()


## 0..1 over all volunteers.
func detail_progress() -> float:
	if detail.is_empty():
		return 0.0
	var need := maxf(1.0, float(alt_def(int(detail["phase"])).get("work_ticks", 1)) * (detail["ids"] as Array).size())
	var got := 0.0
	for id: int in detail["ids"]:
		got += float((detail["work"] as Dictionary).get(id, 0))
	return clampf(got / need, 0.0, 1.0)


## Command body of Simulation.deliver_petition_alt. False (no state change) when not allowed.
func deliver_alt(p: int, alt_id: String) -> bool:
	if not enabled() or alt_block_reason(p) != "" or str(alt_def(p).get("id", "")) != alt_id:
		return false
	var a := alt_def(p)
	if str(a["kind"]) == "informant":
		sim.contraband.suspicion = minf(float(sim.contraband.cfg.get("suspicion_cap", 100.0)), sim.contraband.suspicion + float(a.get("suspicion", 0)))
		var inf := sim.colonists.get_by_id(sim.blocks.informant_id())
		sim.blocks._change(sim.blocks.block_of(inf), -float(a.get("standing", 0)), true)
		sim.contraband._check_suspicion()
		delivered.erase(p)
		_complete(p)
		return true
	var ids: Array = []
	for c: Colonist in _volunteers(int(a.get("volunteers", 3))):
		ids.append(c.id)
	var work: Dictionary = {}
	for id: int in ids:
		work[id] = 0
	detail = {"phase": p, "alt": alt_id, "ids": ids, "done": [], "work": work, "site": _site(), "start": sim.tick}
	return true


## Healthy, free volunteers: alive, not downed, not the Informant, fewest injuries first, then id.
func _volunteers(n: int) -> Array[Colonist]:
	var inf: int = sim.blocks.informant_id() if sim.blocks != null else 0
	var pool: Array[Colonist] = []
	for c in sim.colonists.list:
		if c.alive and not c.hidden and c.id != inf and not sim.health.is_downed(c):
			pool.append(c)
	pool.sort_custom(func(x: Colonist, y: Colonist) -> bool:
		var ix := sim.health.state_of(x).injuries.size()
		var iy := sim.health.state_of(y).injuries.size()
		return ix < iy or (ix == iy and x.id < y.id))
	return pool.slice(0, n) if pool.size() >= n else []


## Hazardous site: the walkable cell nearest to the first reachable nest, pulled 6 cells towards the base.
func _site() -> Vector2i:
	var home := sim.map_center()
	var target := Vector2i(sim.map.width * 3 / 4, sim.map.height / 2)
	if sim.ecology != null:
		for n: Dictionary in sim.ecology.nests:
			target = n["cell"]
			break
	var dir := Vector2(home - target)
	if dir.length() > 6.0:
		target += Vector2i((dir.normalized() * 6.0).round())
	for r in 12:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := target + Vector2i(dx, dy)
				if sim.map.in_bounds(c) and sim.pathfinder.is_walkable(c) and sim.pathfinder.reachable(home, c):
					return c
	return Vector2i(-1, -1)


## Called by DetailJob at the site. True when this volunteer finished (one injury roll, sim.rng).
func detail_work(c: Colonist) -> bool:
	if detail.is_empty() or not (detail["ids"] as Array).has(c.id):
		return true
	if (detail["done"] as Array).has(c.id):
		return true
	var a := alt_def(int(detail["phase"]))
	var w: int = int(detail["work"].get(c.id, 0)) + 1
	detail["work"][c.id] = w
	if w < int(a.get("work_ticks", 300)):
		return false
	detail["done"].append(c.id)
	if sim.rng.randf() < float(a.get("injury_chance", 0.0)):
		sim.health.apply_damage(c, float(a.get("injury", 8.0)))
	return true


func tick() -> void:
	if detail.is_empty():
		return
	var a := alt_def(int(detail["phase"]))
	if sim.tick - int(detail["start"]) > int(float(a.get("timeout_days", 4)) * sim.ticks_per_day):
		_abort_detail("timeout")
		return
	for id: int in detail["ids"]:
		var c := sim.colonists.get_by_id(id)
		if c == null or not c.alive or sim.health.is_downed(c):
			_abort_detail("volunteer lost")  # phase stays open, nothing paid
			return
	if (detail["done"] as Array).size() >= (detail["ids"] as Array).size():
		var p: int = detail["phase"]
		detail = {}
		delivered.erase(p)
		_complete(p)
		return
	if sim.alarm:
		return
	for id: int in detail["ids"]:
		if (detail["done"] as Array).has(id):
			continue
		var c := sim.colonists.get_by_id(id)
		if c.job == null or not (c.job.type in DETAIL_PROTECTED or c.job.type == "detail"):
			sim.jobs.request_override(c, DetailJob.new(detail["site"]))


func _abort_detail(reason: String) -> void:
	for id: int in detail["ids"]:
		var c := sim.colonists.get_by_id(id)
		if c != null and c.alive and c.job != null and c.job.type == "detail":
			sim.jobs.end_job(c, Job.Status.FAILED, false)
	detail = {}
	sim.bus.letter_received.emit("Volunteer Detail", "The detail is called off (%s). The petition stays open." % reason)
# endregion
