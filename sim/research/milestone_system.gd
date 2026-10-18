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
	if t == 3 and sim.petition.enabled():  # region E1: the petition replaces the tier-3 wall
		return -1
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
	if sim.petition.has_state():  # region E1: absent until a petition delivery happened
		out.append(sim.petition.state_parts())
	if k2_outpost_days > 0 or k2_decoys > 0:  # region K2: absent unless an outpost was ever held
		out.append(["k2", k2_outpost_days, k2_decoys])
	return out


# region B3: Parole Reviews (mid-game goals after the tutorial). Gated by balance "b3".enabled.
var reviews_done: Array[String] = []
var waves_repelled := 0


func b3_on() -> bool:
	return bool(sim.defs.balance.get("b3", {}).get("enabled", false))


func review_defs() -> Array:
	var base: Array = sim.defs.milestones.get("reviews", [])
	if k2_on():  # region K2
		base = k2_review_defs(base)  # region K2
	if e3_on():  # region E3
		var head: Array = []  # E3 reviews go before any outpost step so they are never blocked by it
		var tail: Array = []
		for r: Dictionary in base:
			(tail if str(r.get("kind", "")) == "outpost_days" else head).append(r)
		return head + e3_review_defs() + tail
	return base


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
		"outpost_days":  # region K2
			return clampf(k2_outpost_days / v, 0.0, 1.0)  # region K2
		"debt_left_below_pct":  # region E3
			return e3_debt_progress(v)  # region E3
		"range_score":  # region E3
			return clampf(e3_range_score() / v, 0.0, 1.0)  # region E3
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


# region K2: preset-scaled Parole Review + outposts. Gated by balance "k2_enabled" (default false).
var k2_preset := ""  # explicit override; empty = sim.opts "preset_id" (set from the meta preset at run start)
var k2_outpost_days := 0  # days an outpost has been held (campaign calls k2_note_day)
var k2_decoys := 0  # unspent audit decoys (one per newly held outpost period)
var k2_outposts_held := 0


func k2_on() -> bool:
	return bool(sim.defs.balance.get("k2_enabled", false))


func k2_row() -> Dictionary:
	var t: Dictionary = sim.defs.balance.get("k2", {}).get("presets", {})
	return t.get(k2_preset_id(), t.get("standard_term", {}))


func k2_preset_id() -> String:
	return k2_preset if k2_preset != "" else str(sim.opts.get("preset_id", "standard_term"))


## One line for the current outpost step ("" when this preset has none).
func outpost_step_text() -> String:
	if not k2_on() or not bool(k2_row().get("outpost_step", false)):
		return ""
	var need := int(sim.defs.balance.get("k2", {}).get("outpost_days", 2))
	return "Outpost step: hold an outpost %d d (%d/%d)" % [need, mini(k2_outpost_days, need), need]


## Per-preset demand summary for the Reviews sheet ("" when k2 is off).
func k2_demand_text() -> String:
	if not k2_on():
		return ""
	var parts: Array[String] = []
	for r: Dictionary in k2_review_defs(sim.defs.milestones.get("reviews", [])):
		if str(r.get("kind", "")) == "waves_repelled":
			parts.append("%d waves repelled" % int(r["value"]))
		elif str(r.get("kind", "")) == "debt_paid_pct":
			parts.append("%d%% debt" % int(r["value"]))
	return "Demands: " + ", ".join(parts)


## Reviews with per-preset demands applied; adds the outpost step where the preset asks for it.
func k2_review_defs(base: Array) -> Array:
	var row := k2_row()
	var out: Array = []
	for r: Dictionary in base:
		var c := r.duplicate(true)
		match str(c.get("kind", "")):
			"waves_repelled":
				c["value"] = maxi(1, int(c["value"]) + int(row.get("waves_delta", 0)))
			"debt_paid_pct":
				c["value"] = int(c["value"]) + int(row.get("debt_delta", 0))
		out.append(c)
	if bool(row.get("outpost_step", false)):
		for r: Dictionary in sim.defs.milestones.get("k2_reviews", []):
			var c := r.duplicate(true)
			c["value"] = int(sim.defs.balance.get("k2", {}).get("outpost_days", c["value"]))
			out.append(c)
	return out


## Called once per campaign day with the number of held (living) outposts.
func k2_note_day(held: int) -> void:
	if not k2_on():
		return
	if held > 0 and k2_outposts_held == 0:
		k2_decoys += 1
	k2_outposts_held = held
	if held > 0:
		k2_outpost_days += 1


## K1 audit spawn calls this: true = the audit patrol hit an outpost instead (skip home audit once).
func k2_consume_decoy() -> bool:
	if not k2_on() or k2_decoys <= 0:
		return false
	k2_decoys -= 1
	return true


## Essence stockpiled at an outpost is exempt from a hoard/essence clock (flag only; clock stays off).
func k2_essence_exempt() -> bool:
	return k2_on() and k2_outposts_held > 0


func k2_export() -> Array:
	return [k2_outpost_days, k2_decoys, k2_outposts_held]


func k2_import(a: Array) -> void:
	k2_outpost_days = int(a[0])
	k2_decoys = int(a[1])
	k2_outposts_held = int(a[2])
# endregion


# region E3: Chain Gang Review (Parole Reviews 4-5). Gated by balance "e3_enabled" (default false).
var e3_seen_debt := false


func e3_on() -> bool:
	return bool(sim.defs.balance.get("e3_enabled", false))


func e3_review_defs() -> Array:
	return sim.defs.milestones.get("e3_reviews", [])


## Progress toward "debt left below v %": 1.0 once remaining debt < v % (needs a non-empty debt book).
func e3_debt_progress(v: float) -> float:
	var total := 0
	for c in sim.colonists.list:
		var st: DebtState = sim.debt.state_of(c)
		if st != null:
			total += st.total
	if total > 0:
		e3_seen_debt = true
	elif e3_seen_debt:
		return 1.0  # everyone cleared and gone
	else:
		return 0.0
	var left := 100.0 - debt_paid_pct()
	if left < v:
		return 1.0
	return clampf((100.0 - left) / (100.0 - v), 0.0, 0.99)


## Range score = total power surplus (all nets) x clean factor (1 at no pollution, 0 at clean_ref pollution fraction).
func e3_range_score() -> float:
	var cfg: Dictionary = sim.defs.balance.get("e3", {})
	var surplus := 0.0
	for n: Dictionary in sim.power.nets:
		var info: Dictionary = sim.power.net_info(int(n["id"]))
		surplus += maxf(0.0, float(info.get("supply", 0.0)) - float(info.get("demand", 0.0)))
	var clean := clampf(1.0 - sim.contamination.fraction() / float(cfg.get("clean_ref", 0.5)), 0.0, 1.0)
	return surplus * clean


## Extra days between sentence audits earned by passed E3 reviews.
func e3_audit_bonus_days() -> float:
	if not e3_on():
		return 0.0
	var d := 0.0
	for r: Dictionary in e3_review_defs():
		if reviews_done.has(str(r["id"])):
			d += float(r.get("audit_bonus_days", 0.0))
	return d


## Cosmetic rank title of the highest passed E3 review ("" if none).
func e3_rank_title() -> String:
	var t := ""
	if e3_on():
		for r: Dictionary in e3_review_defs():
			if reviews_done.has(str(r["id"])):
				t = str(r.get("rank", t))
	return t
# endregion
