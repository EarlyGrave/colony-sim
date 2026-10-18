class_name ResearchSystem
extends RefCounted
## Tech tree state. Operators (bench jobs, later AI chips) feed work through
## `add_progress()`. Gating is off unless `gating` is true (opts `research_locked`),
## so existing content/tests stay playable. All state is sorted/ordered arrays.

var sim: Simulation
## Gating switch. false = everything counts as unlocked.
var gating := false
var done: Array[String] = []  # sorted
var queue: Array[String] = []  # order = priority; first eligible entry is active
var progress: Dictionary = {}  # tech id -> float (read via sorted keys)
var paid: Array[String] = []  # sorted: techs whose essence was spent
var audit_tiers: Array[int] = []  # sorted: tiers unlocked by Audit Deliveries (R2b)

var _bld_owner: Dictionary = {}  # building id -> tech id
var _rec_owner: Dictionary = {}
var _rule_owner: Dictionary = {}


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	gating = bool(sim.opts.get("research_locked", false))
	var techs := sim.defs.research
	for id: String in _ids():
		var un: Dictionary = techs[id].get("unlocks", {})
		for b: String in un.get("buildings", []):
			_bld_owner[b] = id
		for r: String in un.get("recipes", []):
			_rec_owner[r] = id
		for r: String in un.get("rules", []):
			_rule_owner[r] = id
		if int(techs[id]["tier"]) <= free_tiers():
			done.append(id)  # start techs (T0 + T1)
	done.sort()
	for t: Variant in sim.opts.get("research_audit_tiers", []):  # tests/bots: pre-granted tier audits
		unlock_tier(int(t))


func free_tiers() -> int:
	return int(sim.defs.balance.get("research", {}).get("free_tiers", 1))


func _ids() -> Array:
	var a: Array = sim.defs.research.keys()
	a.sort()
	return a


func tech(id: String) -> Dictionary:
	return sim.defs.research.get(id, {})


# --- Queries (view / other systems) -------------------------------------------

func is_done(id: String) -> bool:
	return done.has(id)


func tier_unlocked(tier: int) -> bool:
	return tier <= free_tiers() or audit_tiers.has(tier)


## Called by the milestone system when a tier audit completes.
func unlock_tier(tier: int) -> void:
	if not audit_tiers.has(tier):
		audit_tiers.append(tier)
		audit_tiers.sort()


## "" if `id` can be queued now, else a reason: "unknown", "done",
## "tier audit T<n>", "needs <prereq id>".
func lock_reason(id: String) -> String:
	if not sim.defs.research.has(id):
		return "unknown"
	if is_done(id):
		return "done"
	var t := tech(id)
	if not tier_unlocked(int(t["tier"])):
		return "tier audit T%d" % int(t["tier"])
	for p: String in t["prereqs"]:
		if not is_done(p):
			return "needs " + p
	return ""


func can_afford(id: String) -> bool:
	var n := int(tech(id)["cost"]["essence"])
	return paid.has(id) or n == 0 or sim.items.count_stored(_essence()) >= n


## Active tech = first queue entry whose requirements are met, else "".
func active() -> String:
	for id in queue:
		if lock_reason(id) == "":
			return id
	return ""


func bench_ticks(id: String) -> int:
	return int(tech(id)["cost"]["bench_ticks"])


func progress_of(id: String) -> float:
	return float(progress.get(id, 0.0))


## Progress fraction 0..1.
func fraction(id: String) -> float:
	return clampf(progress_of(id) / float(bench_ticks(id)), 0.0, 1.0)


## Product of `waste_mult` of every finished tech (>= 1.0 normally).
func waste_multiplier() -> float:
	var m := 1.0
	for id in done:
		m *= float(tech(id).get("waste_mult", 1.0))
	return m


func building_unlocked(def_id: String) -> bool:
	return not gating or not _bld_owner.has(def_id) or is_done(_bld_owner[def_id])


func recipe_unlocked(recipe_id: String) -> bool:
	return not gating or not _rec_owner.has(recipe_id) or is_done(_rec_owner[recipe_id])


func rule_unlocked(rule_id: String) -> bool:
	return not gating or not _rule_owner.has(rule_id) or is_done(_rule_owner[rule_id])


## Tech id that gates a building ("" if ungated).
func building_tech(def_id: String) -> String:
	return str(_bld_owner.get(def_id, ""))


# --- Commands (called by Simulation.set_research / queue_research) -------------

## Adds `id` (if needed) and moves it to the front. False if it cannot be queued.
func set_active(id: String) -> bool:
	if not _admit(id):
		return false
	queue.erase(id)
	queue.push_front(id)
	return true


## Appends / removes `id`. Removing a tech with zero progress refunds its essence.
func set_queued(id: String, on: bool) -> bool:
	if on:
		if queue.has(id):
			return true
		if not _admit(id):
			return false
		queue.append(id)
		return true
	if not queue.has(id):
		return false
	queue.erase(id)
	if progress_of(id) <= 0.0 and paid.has(id):
		_refund(id)
	return true


func _admit(id: String) -> bool:
	if not sim.defs.research.has(id) or is_done(id):
		return false
	if not tier_unlocked(int(tech(id)["tier"])) or not can_afford(id):
		return false
	if not paid.has(id):
		var n := int(tech(id)["cost"]["essence"])
		if n > 0:
			if not sim.items.consume_stored(_essence(), n, sim.map_center()):
				return false
			sim.ledger.record_consumed(_essence(), n, "research")
		paid.append(id)
		paid.sort()
	return true


func _refund(id: String) -> void:
	paid.erase(id)
	var n := int(tech(id)["cost"]["essence"])
	if n <= 0:
		return
	sim.ledger.record_produced(_essence(), n, "research_refund")
	var near := sim.map_center()
	var c := sim.items.find_storage_cell(_essence(), near, func(_c: Vector2i) -> bool: return false)
	sim.items.drop(c if c != Vector2i(-1, -1) else near, _essence(), n)


func _essence() -> String:
	return str(sim.defs.balance.get("research", {}).get("essence_item", "refined_essence"))


# --- Operator API ----------------------------------------------------------------

## Adds `work` (bench ticks at speed 1.0) to the active tech. Returns the tech id
## completed by this call, else "". Leftover work past completion is discarded.
func add_progress(work: float) -> String:
	var id := active()
	if id == "" or work <= 0.0:
		return ""
	var total := float(bench_ticks(id))
	var p := progress_of(id) + work
	if p >= total - 1e-6:
		progress.erase(id)
		queue.erase(id)
		done.append(id)
		done.sort()
		sim.bus.research_completed.emit(id)
		return id
	progress[id] = p
	return ""


## Canonical, order-stable state for `SaveGame.state_hash`.
func state_parts() -> Array:
	var prog: Array = []
	var keys: Array = progress.keys()
	keys.sort()
	for k in keys:
		prog.append([k, snappedf(float(progress[k]), 0.0001)])
	return [gating, done, queue, prog, paid, audit_tiers]
