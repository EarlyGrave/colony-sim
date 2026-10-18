class_name TutorialSystem
extends RefCounted
## Warden's Orientation (R5 O1): a linear chain of lessons driven by the sim's own bus.
## Exists only when opts.tutorial is true (`sim.tutorial` is null otherwise, so normal
## games and goldens are untouched). Never uses sim.rng. The view only reads this and
## issues the recorded commands tutorial_ack / tutorial_skip_step / tutorial_skip_all.
## Data: data/tutorial.json. `step == step_count()` means the orientation is over.

var sim: Simulation
var steps: Array = []
var step := 0
## Ids of completed (or skipped) steps, in order.
var done: Array[String] = []
## True once "Skip all" was used.
var skipped := false
var ticks_in_step := 0
## Per-step progress: distinct cells seen (designations / zone cells) and event flags.
var seen: Array[Vector2i] = []
var sflags: Dictionary = {}
## Facts that stay true across steps (refined, research, forecast).
var latched: Dictionary = {}
var audit_index := -1
var _mined_items: Array[String] = []
var _port_total := 0


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	steps = sim.defs.tutorial.get("steps", [])
	var audit_id := str(sim.defs.tutorial.get("settings", {}).get("audit_step", "audit"))
	for i in steps.size():
		if str(steps[i]["id"]) == audit_id:
			audit_index = i
	var b: Object = sim.bus
	sim.listen(b.designation_changed, _on_designation)
	sim.listen(b.zone_changed, _on_zone)
	sim.listen(b.item_mined, _on_item_mined)
	sim.listen(b.building_placed, _on_building_placed)
	sim.listen(b.first_refine_done, func() -> void: _latch("refined"))
	sim.listen(b.research_completed, func(_t: String) -> void: _latch("research"))
	sim.listen(b.forecast_revealed, func() -> void: _latch("forecast"))
	sim.listen(b.wave_started, _on_wave_started)
	sim.listen(b.wave_repelled, func(_i: int) -> void: _flag("repelled"))
	sim.listen(b.wave_incoming, func(_o: Vector2i, _t: int) -> void: _flag("wave_incoming"))
	sim.listen(b.alarm_changed, _on_alarm)
	_enter()


# --- Queries (view / other systems) ---------------------------------------------

func step_count() -> int:
	return steps.size()


func finished() -> bool:
	return step >= steps.size()


## The active lesson (data row), or {} when finished.
func current() -> Dictionary:
	return {} if finished() else steps[step]


func is_done(id: String) -> bool:
	return done.has(id)


func nudge_due() -> bool:
	return not finished() and ticks_in_step >= int(steps[step].get("nudge_ticks", 600))


## Normal waves are held back until the audit lesson is reached (or the tutorial ends early).
func waves_held() -> bool:
	return not finished() and audit_index >= 0 and step < audit_index


## {have, need} for lessons that count things (HUD progress), {} otherwise.
func progress() -> Dictionary:
	if finished():
		return {}
	var d: Dictionary = steps[step]["done"]
	if d.has("count"):
		if str(d["signal"]) == "item_mined":
			return {"have": _stored_total(), "need": int(d["count"])}
		return {"have": seen.size(), "need": int(d["count"])}
	if d.has("min_cells"):
		return {"have": sim.logistics.belts.belt_count, "need": int(d["min_cells"])}
	return {}


# --- Commands (called from Simulation, already recorded) ---------------------------

func ack() -> void:
	_flag("ack")


func skip_step() -> void:
	if not finished():
		_advance()


func skip_all() -> void:
	if finished():
		return
	while step < steps.size():
		done.append(str(steps[step]["id"]))
		step += 1
	skipped = true
	_reset_step()
	_finish()


# --- Per tick -------------------------------------------------------------------

func tick() -> void:
	if finished():
		return
	ticks_in_step += 1
	var sig := str(steps[step]["done"]["signal"])
	if sig == "belt":
		_poll_ports()
	if sig == "belt" or sig == "item_mined":
		_check()


## Canonical state for `SaveGame.state_hash` (only appended when the tutorial is on).
func state_parts() -> Array:
	var fl: Array = []
	var keys: Array = sflags.keys()
	keys.sort()
	for k in keys:
		fl.append([k, sflags[k]])
	var lt: Array = latched.keys()
	lt.sort()
	return [step, done, skipped, ticks_in_step, seen, fl, lt]


# --- Event handlers ---------------------------------------------------------------

func _flag(name: String) -> void:
	if finished():
		return
	sflags[name] = true
	_check()


func _latch(name: String) -> void:
	latched[name] = true
	if not finished():
		sflags[name] = true
		_check()


func _cur_signal() -> String:
	return "" if finished() else str(steps[step]["done"]["signal"])


func _on_designation(c: Vector2i) -> void:
	if _cur_signal() == "designation_changed" and sim.map.mine_designated[sim.map.idx(c)] == 1 and not seen.has(c):
		seen.append(c)
		_check()


func _on_zone(c: Vector2i) -> void:
	if _cur_signal() == "zone_changed" and sim.map.get_zone(c) != "" and not seen.has(c):
		seen.append(c)
		_check()


func _on_item_mined(_c: Vector2i, item_id: String, _n: int) -> void:
	if not _mined_items.has(item_id):
		_mined_items.append(item_id)


func _on_building_placed(id: int) -> void:
	var b := sim.buildings.get_by_id(id)
	if b == null or finished():
		return
	var where: Dictionary = steps[step]["done"].get("where", {})
	if where.has("def_in") and (where["def_in"] as Array).has(b.def_id):
		_flag("placed")


func _on_wave_started(_i: int, _s: float) -> void:
	if sim.threats.force_raid_id == "tutorial_audit":
		sim.threats.force_raid_id = ""
	if _cur_signal() == "wave_repelled":
		_flag("wave_started")


## Only player toggles count (the wave itself flips the alarm inside step()).
func _on_alarm(_on: bool) -> void:
	if not sim.in_step:
		_flag("alarm_used")


# --- Evaluation ---------------------------------------------------------------------

func _stored_total() -> int:
	var n := 0
	for it in _mined_items:
		n += sim.items.count_stored(it)
	return n


func _poll_ports() -> void:
	var total := 0
	for b in sim.buildings.list:
		if b.def.get("port_building", false):
			for k in b.output:
				total += int(b.output[k])
	if total > _port_total:
		sflags["delivered"] = true
	_port_total = total


func _has_building(defs_: Array) -> bool:
	for b in sim.buildings.list:
		if not b.destroyed and defs_.has(b.def_id):
			return true
	return false


func _met(d: Dictionary) -> bool:
	match str(d["signal"]):
		"ack":
			return sflags.has("ack")
		"designation_changed", "zone_changed":
			return seen.size() >= int(d["count"])
		"item_mined":
			return not _mined_items.is_empty() and _stored_total() >= int(d["count"])
		"building_placed":
			return sflags.has("placed") or (d.has("or") and sflags.has(str(d["or"])))
		"first_refine_done":
			return sflags.has("refined")
		"research_completed":
			return sflags.has("research")
		"belt":
			return sim.logistics.belts.belt_count >= int(d["min_cells"]) and sflags.has("delivered")
		"forecast_revealed":
			return sflags.has("forecast") or sflags.has("ack")
		"wave_repelled":
			return sflags.has("wave_started") and sflags.has("repelled") \
				and (sflags.has("alarm_used") or _has_building(["turret"]))
	return false


func _check() -> void:
	var guard := 0
	while not finished() and guard < 32 and _met(steps[step]["done"]):
		guard += 1
		_advance()


func _advance() -> void:
	done.append(str(steps[step]["id"]))
	step += 1
	_reset_step()
	if finished():
		_finish()
		return
	sim.bus.tutorial_step_changed.emit(step)
	_enter()
	_check()


func _reset_step() -> void:
	ticks_in_step = 0
	seen.clear()
	sflags.clear()


func _finish() -> void:
	if sim.threats != null and sim.threats.force_raid_id == "tutorial_audit" and not sim.threats.wave_active:
		sim.threats.force_raid_id = ""
	sim.bus.tutorial_step_changed.emit(step)
	sim.bus.tutorial_finished.emit()


## Runs when a step becomes active: carries over latched facts, arms the scripted raid.
func _enter() -> void:
	if finished():
		return
	var s: Dictionary = steps[step]
	for k: String in latched:
		if str(s["done"]["signal"]) in ["first_refine_done", "research_completed"]:
			sflags[k] = true
	if bool(s["done"].get("latch", false)):
		var where: Dictionary = s["done"].get("where", {})
		if _has_building(where.get("def_in", [])):
			sflags["placed"] = true
	_port_total = 0
	if sim.research != null:
		# R5X: the real tier-2 audit (plates + parts) is far beyond a first lesson: the Warden pre-approves it.
		sim.research.unlock_tier(2)
	if step == audit_index and sim.threats != null:
		var delay := int(sim.defs.tutorial.get("settings", {}).get("audit_delay_ticks", 120))
		sim.threats.schedule_scripted(delay)
