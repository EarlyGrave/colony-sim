class_name DebtSystem
extends RefCounted
## Prisoner essence debt: payment, daily quotas, payoff choice, despair and
## prison-style breaks (riot / escape). Numbers: data/debt.json.
## Uses its own RNG (seeded from the sim seed) so it never perturbs sim.rng.

var sim: Simulation
var cfg: Dictionary
var states: Dictionary = {}  # colonist id -> DebtState
var gone: Dictionary = {}  # colonist id -> "left" | "escaped"
## Legacy hook for future meta-progression: grows when prisoners leave freely.
var legacy_points := 0
var _rng := RandomNumberGenerator.new()


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	cfg = sim.defs.debt
	_rng.seed = sim.seed_value * 7919 + 13
	sim.listen(sim.bus.colonist_joined, _on_joined)


func state_of(c: Colonist) -> DebtState:
	return states.get(c.id)


func _assign(c: Colonist) -> void:
	if states.has(c.id):
		return
	var st := DebtState.new()
	st.total = _rng.randi_range(int(cfg["debt_min"]), int(cfg["debt_max"]))
	if sim.opts.has("debt_mult"):  # region O3
		st.total = roundi(st.total * float(sim.opts["debt_mult"]))
	st.due_day = sim.day() + int(cfg["due_days"])
	states[c.id] = st


# region NG
## Next Sentence: spreads carried debt over the current prisoners (installments + interest apply as usual).
func add_carry(amount: int) -> void:
	for c in sim.colonists.list:  # starting inmates get their state lazily on the first tick: create it now
		if c.alive:
			_assign(c)
	var ids: Array = states.keys()
	ids.sort()
	if ids.is_empty() or amount <= 0:
		return
	var share := amount / ids.size()
	var rest := amount - share * ids.size()
	for i in ids.size():
		(states[ids[i]] as DebtState).total += share + (rest if i == 0 else 0)
# endregion


func _on_joined(id: int) -> void:
	var c := sim.colonists.get_by_id(id)
	if c != null:
		_assign(c)


func is_overdue(c: Colonist) -> bool:
	var st := state_of(c)
	return st != null and st.remaining() > 0 and sim.day() >= st.due_day \
			and st.period_paid < sim.traits.installment(c, int(cfg["installment"]))  # region traits


# --- Commands (called from Simulation) ---------------------------------------------

func pay(c: Colonist, amount: int) -> bool:
	var st := state_of(c) if c != null else null
	if st == null or not c.alive or st.remaining() <= 0 or amount <= 0:
		return false
	return _pay(c, st, mini(amount, st.remaining()))


func _pay(c: Colonist, st: DebtState, n: int) -> bool:
	var item := str(cfg["item"])
	if not sim.items.consume_stored(item, n, c.cell):
		return false
	sim.ledger.record_consumed(item, n, "debt")
	st.paid += n
	st.period_paid += n
	st.despair = maxf(0.0, st.despair - n * float(cfg["despair_relief_per_unit"]))
	if st.remaining() == 0:
		st.pending_choice = true
		st.despair = 0.0
		sim.bus.debt_paid.emit(c.id)
	return true


# region F11W2
## Books `n` units as paid without consuming items (Quota Hawk, Blood Debt); emits debt_paid when it clears.
func credit(c: Colonist, n: int) -> bool:
	var st := state_of(c) if c != null else null
	if st == null or not c.alive or st.remaining() <= 0 or n <= 0:
		return false
	n = mini(n, st.remaining())
	st.paid += n
	st.period_paid += n
	st.despair = maxf(0.0, st.despair - n * float(cfg["despair_relief_per_unit"]))
	if st.remaining() == 0:
		st.pending_choice = true
		st.despair = 0.0
		sim.bus.debt_paid.emit(c.id)
	return true
# endregion


func set_quota(c: Colonist, per_day: int) -> bool:
	var st := state_of(c) if c != null else null
	if st == null or per_day < 0:
		return false
	st.quota = per_day
	return true


## stay = true: free colonist with a bonus; false: leaves the planet (reward).
func choose_payoff(c: Colonist, stay: bool) -> bool:
	var st := state_of(c) if c != null else null
	if st == null or not c.alive or not st.pending_choice:
		return false
	st.pending_choice = false
	if stay:
		st.outcome = "stayed"
		c.bio["work_speed"] = float(c.bio.get("work_speed", 1.0)) + float(cfg["stay_work_speed"])
		sim.mood.add_thought(c, str(cfg["stay_thought"]))
	else:
		st.outcome = "left"
		_remove(c, "left")
		legacy_points += int(cfg["leave_legacy_points"])
		var n := int(cfg["leave_reward"])
		if n > 0:
			var item := str(cfg["item"])
			sim.ledger.record_produced(item, n, "legacy")
			sim.items.drop(sim.map_center(), item, n)
	sim.bus.debt_choice_made.emit(c.id, st.outcome)
	return true


# --- Tick -----------------------------------------------------------------------------

func tick() -> void:
	for c in sim.colonists.list:
		if c.alive:
			_assign(c)
	if sim.tick % sim.ticks_per_day == 0:
		for c in sim.colonists.list:
			if c.alive and states.has(c.id):
				_daily(c, states[c.id])
	var check := int(sim.defs.mood["check_ticks"])
	if check > 0 and sim.tick % check == 0:
		for c in sim.colonists.list:
			if c.alive and states.has(c.id):
				_apply_despair_thought(c, states[c.id])


func _daily(c: Colonist, st: DebtState) -> void:
	if st.remaining() <= 0:
		return
	if st.quota > 0:
		_pay(c, st, mini(st.quota, st.remaining()))
		if st.remaining() == 0:
			return
	var inst := sim.traits.installment(c, int(cfg["installment"]))  # region traits
	if sim.day() >= st.due_day and st.period_paid < inst:
		# Grace period, then despair grows in proportion to the unpaid share.
		if sim.day() >= st.due_day + int(cfg.get("grace_days", 0)) + int(sim.endings.effect("grace_days", 0.0)):  # region F9W2
			if sim.quests != null and sim.quests.is_enabled() and not sim.quests.flag("installment_missed"):  # region R1
				sim.quests.set_flag("installment_missed")
			var short := float(inst - st.period_paid) / float(maxi(1, inst))
			var bm := sim.blocks.despair_mult(c) if sim.blocks != null else 1.0  # region I1
			var dm := sim.quests.mod("despair_mult") if sim.quests != null else 1.0  # region CD
			var tm := maxf(0.0, 1.0 + sim.traits.mod(c, "despair_mult"))  # region PW2
			if sim.traits.has_tag(c, "despair_frozen"):
				tm = 0.0
			st.despair = minf(100.0, st.despair + float(cfg["despair_per_day"]) * short * bm * dm * tm)
			if sim.blocks != null and not (sim.quests != null and sim.quests.flag("path_fight")):  # region I1 (N3: fight path: not counted as missed)
				sim.blocks.on_installment_missed(c)
	else:
		if sim.day() >= st.due_day:  # installment met: roll the period, interest grows the debt
			st.period_paid -= inst
			if sim.blocks != null:  # region I1
				sim.blocks.on_installment_paid(c)
			st.due_day += int(cfg["period_days"])
			var add := ceili(st.remaining() * float(cfg["interest_pct"]) / 100.0)
			st.total += add
			st.interest += add
		st.despair = maxf(0.0, st.despair - float(cfg["despair_decay_per_day"]))


func _apply_despair_thought(c: Colonist, st: DebtState) -> void:
	if st.despair >= float(cfg["despair_high"]):
		sim.mood.add_thought(c, "despair_2")
	elif st.despair >= float(cfg["despair_mid"]):
		sim.mood.add_thought(c, "despair_1")


# --- Breaks (called from MoodSystem._roll_break) -------------------------------------

## True if this colonist's break is prison-style instead of the generic one.
func handles_break(c: Colonist) -> bool:
	var st := state_of(c)
	return st != null and not gone.has(c.id) and st.remaining() > 0 \
			and st.despair >= float(cfg["break_despair_min"])


func pick_break_kind() -> String:
	return "escape" if _rng.randf() < float(cfg["escape_weight"]) else "riot"


func start_break(c: Colonist, kind: String) -> Job:
	if kind == "riot":
		sim.bus.riot_started.emit(c.id)
		for o in sim.colonists.list:
			if o.alive and o.id != c.id:
				sim.mood.add_thought(o, str(cfg["riot_witness_thought"]))
		return DebtJob.new("riot", sim.tick + int(cfg["riot_ticks"]))
	return DebtJob.new("escape", sim.tick + int(cfg["escape_ticks"]))


func break_ticks(kind: String) -> int:
	return int(cfg["riot_ticks"] if kind == "riot" else cfg["escape_ticks"])


func riot_target(c: Colonist) -> Building:
	var best: Building = null
	var best_d := int(cfg["riot_radius"]) * int(cfg["riot_radius"])
	for b in sim.buildings.list:
		if b.destroyed or bool(b.def.get("critical", false)):
			continue
		var d := (b.cell - c.cell).length_squared()
		if d <= best_d:
			best_d = d
			best = b
	return best


func edge_target(c: Colonist) -> Vector2i:
	var w := sim.map.width
	var h := sim.map.height
	var cands: Array[Vector2i] = []
	for x in w:
		cands.append(Vector2i(x, 0))
		cands.append(Vector2i(x, h - 1))
	for y in range(1, h - 1):
		cands.append(Vector2i(0, y))
		cands.append(Vector2i(w - 1, y))
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for e in cands:
		var d := (e - c.cell).length_squared()
		if d < best_d and sim.pathfinder.is_walkable(e) and sim.pathfinder.reachable(c.cell, e):
			best_d = d
			best = e
	return best


func stopped_by_guard(c: Colonist) -> bool:
	# A drafted colonist stops an escapee within escape_stop_range; one on patrol
	# (the non-drafted guard) within the wider escape_patrol_range.
	var r := int(cfg["escape_stop_range"])
	var rp := int(cfg.get("escape_patrol_range", r))
	for o in sim.colonists.list:
		if not o.alive or o.id == c.id or o.hidden or (o.health != null and o.health.downed):
			continue
		var d := maxi(absi(o.cell.x - c.cell.x), absi(o.cell.y - c.cell.y))
		if o.combat != null and o.combat.drafted and d <= r:
			return true
		if o.job != null and o.job.type == "patrol" and d <= rp:
			return true
	return false


func on_caught(c: Colonist) -> void:
	var st := state_of(c)
	if st != null:
		st.despair = maxf(0.0, st.despair - float(cfg["caught_relief"]))
	sim.bus.escape_stopped.emit(c.id)


func on_escaped(c: Colonist) -> void:
	var st := state_of(c)
	if st != null:
		st.outcome = "escaped"
	_remove(c, "escaped")
	sim.bus.colonist_escaped.emit(c.id)


## Removes a colonist from the colony without a death.
func _remove(c: Colonist, reason: String) -> void:
	if c.carry_count > 0:
		if reason == "escaped":
			sim.ledger.record_consumed(c.carry_item, c.carry_count, "escape")
		else:
			sim.items.drop(c.cell, c.carry_item, c.carry_count)
		c.carry_item = ""
		c.carry_count = 0
	sim.jobs.end_job(c, Job.Status.FAILED)
	c.alive = false
	c.hidden = true
	gone[c.id] = reason
