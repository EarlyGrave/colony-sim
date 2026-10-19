class_name InformantMod
extends RefCounted
## Quest I2 "The Informant Reports" (data/quests_q13.json). QuestLog module: poll() daily, resolve(option).
## While the Informant lives and reports, mod petition_fee_mult rises (fee_start..fee_max); ends on
## false info / transfer / his death, restoring the pre-quest value. Deterministic, no rng.

const ID := "q13_informant"

var sim: Simulation
var cfg: Dictionary
var state := "idle"  ## idle | offered | reporting | done
var informant_id := -1
var reports := 0
var base_mult := 1.0
var choice := ""
var tolerated := false
## Test hook: Callable() -> int colonist id (-1 none). Default: I1 sim.blocks.informant_id(), else tag fallback.
var informant_fn: Callable = Callable()


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	var d: Dictionary = sim.defs.quests.get(ID, {})
	cfg = d.get("cfg", {})


func enabled() -> bool:
	return bool(sim.defs.balance.get("q_enabled", false)) and not cfg.is_empty()


func _def() -> Dictionary:
	return sim.defs.quests[ID]


func find_informant() -> Colonist:
	var id := -1
	if informant_fn.is_valid():
		id = int(informant_fn.call())
	else:
		var b: Variant = sim.get("blocks")
		if b != null and b.has_method("informant_id"):
			id = int(b.informant_id())
		if id < 0:  # fallback until I1: first colonist tagged Informant
			for c in sim.colonists.list:
				if str(c.bio.get("tag", "")) == str(cfg["tag_informant"]) or str(c.bio.get("block", "")) == "informant":
					id = c.id
					break
	var c := sim.colonists.get_by_id(id) if id >= 0 else null
	return c if c != null and c.alive and not sim.debt.gone.has(c.id) else null


func find_clerk() -> Colonist:
	for c in sim.colonists.list:
		if c.alive and str(c.bio.get("tag", "")) == str(cfg["tag_clerk"]) and not sim.debt.gone.has(c.id):
			return c
	return null


func _name() -> String:
	var c := sim.colonists.get_by_id(informant_id) if informant_id >= 0 else null
	return c.display_name if c != null else "The Informant"


func current_mult() -> float:
	return minf(float(cfg["fee_max"]), float(cfg["fee_start"]) + float(cfg["fee_step"]) * reports + (float(cfg["tolerate_bonus"]) if tolerated else 0.0))


func _set_fee(v: float) -> void:
	sim.quests.add_mod("petition_fee_mult", v, 0.0)


func poll() -> void:
	if not enabled():
		return
	match state:
		"idle":
			if sim.day() < int(cfg["min_day"]):
				return
			var c := find_informant()
			if c == null:
				return
			informant_id = c.id
			base_mult = sim.quests.mod("petition_fee_mult")
			sim.quests.start(ID)
			state = "offered"
			_set_fee(current_mult())
			var opts: Array = []
			for oid: String in ["tolerate", "false_info", "transfer"]:
				var o: Dictionary = _def()["beats"]["report"]["options"][oid]
				opts.append({"id": oid, "label": str(o["label"]), "enabled": not bool(o.get("requires_clerk", false)) or find_clerk() != null})
			sim.quests.offer(ID, "report", str(_def()["beats"]["report"]["text"]).replace("{who}", _name()), opts)
		"offered", "reporting":
			if find_informant() == null:
				_end()
				return
			_w2_pa()  # region W2
			reports += 1
			_set_fee(current_mult())
			if tolerated:
				sim.mood.add_thought(sim.colonists.get_by_id(informant_id), str(cfg["ration_thought"]))


func resolve(option_id: String) -> bool:
	if state != "offered" or not _def()["beats"]["report"]["options"].has(option_id):
		return false
	var o: Dictionary = _def()["beats"]["report"]["options"][option_id]
	match option_id:
		"tolerate":
			state = "reporting"
			tolerated = true
			_set_fee(current_mult())
		"false_info":
			var cl := find_clerk()
			if cl == null:
				return false
			cl.idle_until = sim.tick + sim.ticks_per_day
			_end()
		"transfer":
			var c := find_informant()
			if c != null:
				sim.debt._remove(c, "transferred")
			_end()
	choice = option_id
	sim.bus.story_event.emit("quest_" + ID, str(o["text"]).replace("{who}", _name()))
	return true


func _end() -> void:
	state = "done"
	_set_fee(base_mult)
	var p: Dictionary = sim.quests.pending_for(ID)
	if not p.is_empty():
		sim.quests.pending.erase(p)
	sim.quests.finish(ID)


func state_parts() -> Array:
	if state == "idle":
		return []
	return [state, informant_id, reports, base_mult, choice, tolerated]


# region W2
## Warden PA line from flavor pa.informant_report: once per 3 days while he lives; silent under mod pa_silent.
func _w2_pa() -> void:
	if sim.day() % 3 != 0 or sim.quests.mod("pa_silent") > 0.0:
		return
	var f := FileAccess.open("res://data/flavor.json", FileAccess.READ)
	if f == null:
		return
	var j: Variant = JSON.parse_string(f.get_as_text())
	if not (j is Dictionary):
		return
	var lines: Array = (j as Dictionary).get("pa", {}).get("informant_report", [])
	if lines.is_empty():
		return
	sim.bus.letter_received.emit("Warden", str(lines[sim.day() / 3 % lines.size()]))
# endregion
