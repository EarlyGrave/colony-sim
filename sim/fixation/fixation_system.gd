class_name FixationSystem
extends RefCounted
## W3 Fixation (strange mood). Once per game (day >= min_day, flag fixation_enabled) a skilled inmate
## asks for plates + refined essence and a workbench. Accept = items leave stock at once (held here, so
## the petition cannot spend them); the bench work runs `work_ticks`; success = one named legendary
## gear piece, deadline missed (no bench) = mood break and the items are lost. Decline/timeout is free.
## Accept/decline reuses Storyteller pending + Simulation.answer_event. Own rng stream; state is derived
## from the command log (answer_event), so save/load needs no extra data.

var sim: Simulation
var cfg: Dictionary
var offered := false
var _rng := RandomNumberGenerator.new()
## Active fixation: {cid, deadline, progress}; empty when none.
var active: Dictionary = {}
## Held (reserved) items while active.
var held: Dictionary = {}
## [{cid, who, base, gear_id, name}] named masterworks (epilogue / Q15 hook).
var masterworks: Array[Dictionary] = []
var failures := 0
var accepted := 0
var cancels := 0


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	cfg = sim.defs.fixation
	_rng.seed = sim.seed_value ^ 0xF1C5A7


func enabled() -> bool:
	return bool(sim.defs.balance.get("fixation_enabled", false)) and not cfg.is_empty()


## Units of `item_id` reserved by an active fixation (not in stock any more).
func reserved(item_id: String) -> int:
	return int(held.get(item_id, 0))


func tick() -> void:
	if not enabled():
		return
	if not active.is_empty():
		_tick_active()
	elif not offered and sim.tick % 60 == 0 and sim.day() >= int(cfg["min_day"]):
		_try_offer()


func _candidates() -> Array[Colonist]:
	var out: Array[Colonist] = []
	for c in sim.colonists.list:
		if c.alive and not c.hidden and not sim.health.is_downed(c) and c.skills.level(str(cfg["skill"])) >= int(cfg["min_level"]):
			out.append(c)
	return out


func _affordable() -> bool:
	for it: String in cfg["cost"]:
		if sim.items.count_stored(it) < int(cfg["cost"][it]):
			return false
	return true


func _try_offer() -> void:
	if sim.storyteller.has_pending() or sim.storyteller.wave_pending() or not _affordable():
		return
	var cands := _candidates()
	if cands.is_empty():
		return
	var total := 0
	for c in cands:
		total += c.skills.level(str(cfg["skill"]))
	var roll := _rng.randi_range(0, maxi(total, 1) - 1)
	var pick: Colonist = cands[0]
	for c in cands:
		roll -= c.skills.level(str(cfg["skill"]))
		if roll < 0:
			pick = c
			break
	offered = true
	_pa("fix_offer")
	sim.storyteller.post_fixation(pick.id, str(cfg["text"]).replace("{who}", pick.display_name),
		str(cfg["yes_label"]), str(cfg["no_label"]), sim.tick + int(cfg["offer_ticks"]))


## Called by Storyteller.answer / timeout for a "fixation" pending entry.
func answer(p: Dictionary, accept: bool) -> bool:
	sim.storyteller.pending.erase(p)
	var c := sim.colonists.get_by_id(int(p["cid"]))
	var ok := accept and c != null and c.alive and active.is_empty() and _affordable()
	if ok:
		accepted += 1
		for it: String in cfg["cost"]:
			sim.items.consume_stored(it, int(cfg["cost"][it]), c.cell)
			held[it] = int(cfg["cost"][it])
		active = {"cid": c.id, "deadline": sim.tick + int(cfg["deadline_days"]) * sim.ticks_per_day, "progress": 0}
	sim.bus.event_choice_resolved.emit(int(p["uid"]), ok)
	return true


func _pa(key: String) -> void:
	var f := FileAccess.open("res://data/flavor.json", FileAccess.READ)
	if f == null:
		return
	var j: Variant = JSON.parse_string(f.get_as_text())
	if j is Dictionary:
		var lines: Array = (j as Dictionary).get("pa", {}).get(key, [])
		if not lines.is_empty():
			sim.bus.letter_received.emit("Warden", str(lines[0]))


func _who(c: Colonist) -> String:
	return c.display_name if c != null else "The inmate"


func _tick_active() -> void:
	var c := sim.colonists.get_by_id(int(active["cid"]))
	if c == null or not c.alive or sim.health.is_downed(c):
		cancels += 1
		_refund(c)
		sim.bus.story_event.emit("fixation_cancel", str(cfg["cancel_text"]).replace("{who}", _who(c)))
		active = {}
		return
	if _bench_ok():
		active["progress"] = int(active["progress"]) + 1
		if int(active["progress"]) >= int(cfg["work_ticks"]):
			_succeed(c)
			return
	if sim.tick >= int(active["deadline"]):
		_fail(c)


func _bench_ok() -> bool:
	for b in sim.buildings.list:
		if b.def_id == str(cfg["bench"]) and not b.broken and not b.destroyed:
			return true
	return false


func _refund(c: Colonist) -> void:
	var cell := c.cell if c != null else Vector2i.ZERO
	for it: String in held:
		sim.items.drop(cell, it, int(held[it]))
	held = {}


func _succeed(c: Colonist) -> void:
	held = {}
	var bases: Array = cfg["bases"]
	var base := str(bases[_rng.randi_range(0, bases.size() - 1)])
	var gid := sim.equipment.give(c.id, base, str(cfg["rarity"]), int(cfg["ilvl"]))  # direct: not a recorded command
	var nm := "%s's %s" % [c.display_name, str(sim.defs.gear[base]["name"])]
	if gid >= 0:
		sim.equipment.equip(c.id, gid)
		c.bio["masterwork"] = nm
		masterworks.append({"cid": c.id, "who": c.display_name, "base": base, "gear_id": gid, "name": nm})
	sim.mood.add_thought(c, "fixation_done")
	_pa("fix_done")
	sim.bus.story_event.emit("fixation_done", str(cfg["done_text"]).replace("{who}", c.display_name).replace("{item}", nm))
	active = {}


func _fail(c: Colonist) -> void:
	held = {}
	failures += 1
	var m := sim.mood.state_of(c)
	if m.break_kind == "":
		m.break_kind = "wander"
		m.break_until = sim.tick + int(cfg["fail_break_ticks"])
		sim.jobs.request_override(c, BreakJob.new("wander", m.break_until, int(sim.mood.cfg["wander_radius"])))
		sim.bus.mood_break_started.emit(c.id, "wander")
	sim.mood.add_thought(c, "fixation_failed")
	_pa("fix_fail")
	sim.bus.story_event.emit("fixation_fail", str(cfg["fail_text"]).replace("{who}", c.display_name))
	active = {}
