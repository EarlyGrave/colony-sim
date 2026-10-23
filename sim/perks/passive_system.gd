class_name PassiveSystem
extends RefCounted
## Passives v2 live system (docs/gdd/03-colony/passives-v2/). Thin wrapper over PassiveTreeV2:
## per-inmate State (kept in _states by colonist id), bus listeners that earn marks, allocation commands,
## keystone side effects. Event-driven (no tick), no rng. With balance.passives_v2_enabled off:
## mod() = 0.0, rule() = false, nothing listens, nothing is hashed.

var sim: Simulation
var tree: PassiveTreeV2 = null
var _on := false
## colonist id -> State. Kept here, not on Colonist: golden part dumps serialise every Colonist property.
var _states: Dictionary = {}


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	_on = bool(sim.defs.balance.get("passives_v2_enabled", false))
	if not _on:
		return
	tree = PassiveTreeV2.new(sim.defs.passives_v2)
	sim.listen(sim.bus.skill_leveled, _on_skill_leveled)
	sim.listen(sim.bus.colonist_joined, _on_joined)
	sim.listen(sim.bus.day_started, _on_day)
	sim.listen(sim.bus.debt_paid, _on_debt_paid)
	sim.listen(sim.bus.colonist_rescued, _on_rescued)
	sim.listen(sim.bus.colonist_tended, _on_tended)
	sim.listen(sim.bus.mood_break_started, _on_break)
	sim.listen(sim.bus.batch_refined, _on_batch)


func enabled() -> bool:
	return _on


# ---- reads (hot path) --------------------------------------------------------------

## Sum of passive effects for `stat` (0.0 when off / no state).
func mod(c: Colonist, stat: String) -> float:
	if not _on or c == null:
		return 0.0
	var st: PassiveTreeV2.State = _states.get(c.id)
	return tree.mod(st, stat) if st != null else 0.0


## True when the inmate holds a keystone carrying rule flag `x`.
func rule(c: Colonist, x: String) -> bool:
	if not _on or c == null:
		return false
	var st: PassiveTreeV2.State = _states.get(c.id)
	return st != null and tree.has_rule(st, x)


## Per-inmate state; created on demand (milestones up to the current levels are credited).
## null when the system is off.
func state_of(c: Colonist) -> PassiveTreeV2.State:
	if not _on or c == null:
		return null
	if not _states.has(c.id):
		var st := PassiveTreeV2.State.new()
		_states[c.id] = st
		if c.skills != null:
			for sk: String in c.skills.levels:
				tree.set_baseline(st, sk, c.skills.join_level(sk))
				tree.on_skill_level(st, sk, c.skills.level(sk))
		if sim.colonists != null:
			tree.check_records(st, sim.colonists.rec(c))
	return _states[c.id]


func has_state() -> bool:
	if not _on:
		return false
	for id: int in _states:
		if _active(_states[id]):
			return true
	return false


func marks_free(c: Colonist) -> int:
	var st := state_of(c)
	return st.marks_free() if st != null else 0


## The state of `c` if it exists, else null (never creates).
func peek(c: Colonist) -> PassiveTreeV2.State:
	return _states.get(c.id) if c != null else null


func _active(st: PassiveTreeV2.State) -> bool:
	return st.marks_earned > 0 or not st.allocated.is_empty()


func _ctx(c: Colonist) -> Dictionary:
	return {"skills": c.skills.levels if c.skills != null else {}}


## "" when allocatable, else a reason code (see PassiveTreeV2.can_allocate); "off" when disabled.
func can_allocate(c: Colonist, id: String) -> String:
	if not _on:
		return "off"
	if c == null or not c.alive:
		return "no_colonist"
	return tree.can_allocate(state_of(c), id, _ctx(c), sim.tick)


func can_undo(c: Colonist, id: String) -> String:
	if not _on:
		return "off"
	if c == null or not c.alive:
		return "no_colonist"
	return tree.can_undo(state_of(c), id, sim.tick)


## Respec price {"item", "count", "standing", "lockout_days"}; {} when off.
func respec_cost(c: Colonist) -> Dictionary:
	if not _on or c == null:
		return {}
	return tree.respec_cost(state_of(c), "")


## "" when a respec can be done now, else: off, no_colonist, nothing, locked, no_essence.
func can_respec(c: Colonist) -> String:
	if not _on:
		return "off"
	if c == null or not c.alive:
		return "no_colonist"
	var st := state_of(c)
	if not tree.can_respec(st):
		return "nothing"
	var cost := tree.respec_cost(st, "")
	if sim.items.count_stored(str(cost["item"])) < int(cost["count"]):
		return "no_essence"
	return ""


# ---- commands (called through Simulation) -------------------------------------------

func allocate(c: Colonist, id: String) -> bool:
	if can_allocate(c, id) != "":
		return false
	var st := state_of(c)
	if not tree.allocate(st, id, _ctx(c), sim.tick):
		return false
	_changed(c, id, true)
	sim.bus.passive_allocated.emit(c.id, id)
	sim.bus.passive_marks_changed.emit(c.id, st.marks_free())
	return true


func undo(c: Colonist, id: String) -> bool:
	if can_undo(c, id) != "":
		return false
	var st := state_of(c)
	tree.undo(st, id, sim.tick)
	if st.allocated.has(id):
		return false
	_changed(c, id, false)
	sim.bus.passive_removed.emit(c.id, id)
	sim.bus.passive_marks_changed.emit(c.id, st.marks_free())
	return true


## Forgets the whole board: pays essence + Standing, refunds marks, locks allocation.
func respec(c: Colonist) -> bool:
	if can_respec(c) != "":
		return false
	var st := state_of(c)
	var cost := tree.respec_cost(st, "")
	var old: Array[String] = st.allocated.duplicate()
	if int(cost["count"]) > 0:
		if not sim.items.consume_stored(str(cost["item"]), int(cost["count"]), c.cell):
			return false
		sim.ledger.record_consumed(str(cost["item"]), int(cost["count"]), "respec")
	if int(cost["standing"]) > 0 and sim.blocks != null:
		sim.blocks._change(sim.blocks.block_of(c), -float(cost["standing"]), true)
	tree.respec(st, sim.tick, sim.ticks_per_day)
	for id in old:
		sim.bus.passive_removed.emit(c.id, id)
	_resum(c)
	sim.bus.passive_marks_changed.emit(c.id, st.marks_free())
	return true


## Quest / reward marks. Returns the marks credited (0 when off).
func grant_marks(c: Colonist, n: int, _reason: String = "") -> int:
	var st := state_of(c)
	if st == null:
		return 0
	var got := tree.earn(st, n)
	if got > 0:
		sim.bus.passive_marks_changed.emit(c.id, st.marks_free())
	return got


func grant_deed(c: Colonist, deed_id: String) -> int:
	var st := state_of(c)
	if st == null:
		return 0
	var before := st.marks_earned
	_with_deeds(c, st, func() -> void: tree.grant_deed(st, deed_id))
	return st.marks_earned - before


# ---- NG+ dossier ---------------------------------------------------------------------

func dossier_of(c: Colonist) -> Dictionary:
	var st := peek(c)
	if not _on or st == null:
		return {}
	return tree.dossier_carry(st)


func apply_dossier(c: Colonist, d: Dictionary) -> void:
	var st := state_of(c)
	if st == null or d.is_empty():
		return
	tree.apply_dossier(st, d)
	sim.bus.passive_marks_changed.emit(c.id, st.marks_free())


# ---- save / hash ----------------------------------------------------------------------

## [[cid, state dict], ...] in colonist order; [] when off or nothing happened yet.
func state_parts() -> Array:
	var out: Array = []
	if not _on:
		return out
	for c in sim.colonists.list:
		var st := peek(c)
		if st != null and _active(st):
			out.append([c.id, st.to_dict()])
	return out


## Fingerprint parts for the Simulation state hash (allocation order included).
func hash_parts() -> Array:
	var out: Array = []
	if not _on:
		return out
	for c in sim.colonists.list:
		var st := peek(c)
		if st != null and _active(st):
			out.append([c.id, tree.state_hash(st)])
	return out


func load_parts(parts: Array) -> void:
	if not _on:
		return
	for p: Array in parts:
		var c := sim.colonists.get_by_id(int(p[0]))
		if c != null:
			_states[c.id] = PassiveTreeV2.State.from_dict(p[1])
			_resum(c)


# ---- earning --------------------------------------------------------------------------

## Runs `f` (a tree call that may award deeds) and announces new deeds / marks.
func _with_deeds(c: Colonist, st: PassiveTreeV2.State, f: Callable) -> void:
	var before: Array = st.deeds.keys()
	var earned_before := st.marks_earned
	f.call()
	if st.marks_earned == earned_before:
		return
	for id: String in st.deeds:
		if before.has(id):
			continue
		var d: Dictionary = tree.deeds()[id]
		sim.bus.passive_deed.emit(c.id, id)
		if int(d["marks"]) >= 2 and not sim.replaying:  # 1-mark deeds stay out of the letter box
			sim.bus.letter_received.emit("Deed: %s" % str(d["name"]),
				"%s: %s (%d marks)" % [c.display_name, str(d["name"]), int(d["marks"])])
	sim.bus.passive_marks_changed.emit(c.id, st.marks_free())


## Record deeds for one inmate (ColonistSystem.record_changed hook).
func on_record_changed(c: Colonist) -> void:
	if not _on or c == null or not c.alive:
		return
	var st := state_of(c)
	_with_deeds(c, st, func() -> void: tree.check_records(st, sim.colonists.rec(c)))


func _bump(c: Colonist, key: String, n: int = 1) -> void:
	if c == null or not c.alive:
		return
	var st := state_of(c)
	_with_deeds(c, st, func() -> void: tree.bump_counter(st, key, n))


func _on_skill_leveled(cid: int, skill: String, level: int) -> void:
	var c := sim.colonists.get_by_id(cid)
	if c == null:
		return
	var st := state_of(c)
	var before := st.marks_earned
	tree.on_skill_level(st, skill, level)
	if st.marks_earned != before:
		sim.bus.passive_marks_changed.emit(c.id, st.marks_free())


func _on_joined(cid: int) -> void:
	state_of(sim.colonists.get_by_id(cid))


func _on_day(_d: int) -> void:
	for c in sim.colonists.list:
		if not c.alive:
			continue
		var st := state_of(c)
		_with_deeds(c, st, func() -> void:
			tree.check_records(st, sim.colonists.rec(c))
			tree.bump_counter(st, "quiet_days", 1)
			# debt_paid fires only when a debt clears; a first payment is seen here (<= 1 day late)
			var ds: DebtState = sim.debt.state_of(c) if sim.debt != null else null
			if ds != null and ds.paid > 0 and not st.counters.has("installments"):
				tree.bump_counter(st, "installments", 1))


func _on_debt_paid(cid: int) -> void:
	var c := sim.colonists.get_by_id(cid)
	_bump(c, "installments")
	_bump(c, "debt_cleared")


func _on_rescued(_patient: int, carrier: int) -> void:
	_bump(sim.colonists.get_by_id(carrier), "rescues")


func _on_tended(_patient: int, doctor: int, _n: int) -> void:
	_bump(sim.colonists.get_by_id(doctor), "tends")


func _on_break(cid: int, _kind: String) -> void:
	var st: PassiveTreeV2.State = _states.get(cid)
	if st != null:
		st.counters["quiet_days"] = 0


func _on_batch(_building_id: int, _recipe: String) -> void:
	var st := peek(sim.buildings.batch_operator)
	if st != null:  # Overclock's burn counter
		st.counters["batches"] = int(st.counters.get("batches", 0)) + 1


# ---- keystone side effects -------------------------------------------------------------

## Cached stat blocks and keystone side effects after an allocate / undo.
func _changed(c: Colonist, id: String, added: bool) -> void:
	if tree.tier_of(id) != "keystone":
		return
	if added:
		var rs := tree.rules_of(id)
		if rs.has("no_armor") and sim.equipment != null:
			var slots: Dictionary = sim.equipment.equipped.get(c.id, {}).duplicate()
			var keys: Array = slots.keys()
			keys.sort()
			for s: String in keys:
				if s != "weapon":
					sim.equipment.unequip(c.id, s)
		if rs.has("always_informant") and sim.blocks != null:
			sim.blocks._pick_informant()
	_resum(c)


func _resum(c: Colonist) -> void:
	if sim.combat != null:
		sim.combat.resum(c)
	if sim.equipment != null and sim.equipment.equipped.has(c.id):
		sim.equipment._resum(c.id)
