class_name QuestClerkNote
extends RefCounted
## Quest Q1 "The Clerk's Margin Note". Data: data/quests_q1.json.
## Runs only when balance q_enabled is true AND a QuestLog (sim.quests) exists.
## Debt stays almost unpayable: the loophole cuts ONE inmate's debt by a capped
## percentage and never more than a small share of the colony's total debt.

const QUEST_ID := "q1"
const DATA_PATH := "res://data/quests_q1.json"

var sim: Simulation
var cfg: Dictionary
## Test hook: stands in for sim.quests.
var log_override: Object = null
## 0 idle, 1 clause shown, 2 offer posted, 3 resolved (payoff due), 4 done.
var stage := 0
var next_day := 0
var choice := ""
var clerk_id := -1
var removed := false
## Fallback when the QuestLog has no mod setter: name -> {value, until}.
var mods: Dictionary = {}
var total_cut := 0


static func load_cfg() -> Dictionary:
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d[QUEST_ID] if d is Dictionary and d.has(QUEST_ID) else {}


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	cfg = load_cfg()
	if not bool(sim.defs.balance.get("q_enabled", false)):
		return


func _log() -> Object:
	return log_override if log_override != null else sim.get("quests")


func enabled() -> bool:
	if cfg.is_empty() or not bool(sim.defs.balance.get("q_enabled", false)):
		return false
	var l := _log()
	return l != null and (not l.has_method("is_enabled") or bool(l.call("is_enabled")))


func has_state() -> bool:
	return stage > 0


## Hash rows; empty until the quest started (goldens unchanged).
func state_parts() -> Array:
	if stage == 0:
		return []
	return [["q1", stage, next_day, choice, clerk_id, removed, total_cut]]


func mod(name: String) -> float:
	var l := _log()
	if l != null and l.has_method("mod") and not mods.has(name):
		return float(l.call("mod", name))
	var m: Dictionary = mods.get(name, {})
	return float(m["value"]) if not m.is_empty() and sim.tick < int(m["until"]) else 1.0


func find_clerk() -> Colonist:
	if clerk_id >= 0:
		return sim.colonists.get_by_id(clerk_id)
	for c in sim.colonists.list:
		if c.alive and str(c.bio.get("tag", "")) == str(cfg["tag"]) and not sim.debt.gone.has(c.id):
			return c
	return null


func _trigger_met() -> bool:
	var c := find_clerk()
	if c == null or not c.alive:
		return false
	var st := sim.debt.state_of(c)
	return st != null and st.paid >= int(cfg["trigger"]["min_paid"])


func _say(beat: String) -> void:
	var b: Dictionary = cfg["beats"][beat]
	var c := sim.colonists.get_by_id(clerk_id) if clerk_id >= 0 else null
	var nm := c.display_name if c != null else "The Clerk"
	sim.bus.letter_received.emit(str(b["title"]), str(b["text"]).replace("{clerk}", nm))


## Called by QuestLog once per day (register_module).
func poll() -> void:
	if not enabled():
		return
	var day := sim.day()
	var l := _log()
	match stage:
		0:
			if _trigger_met():
				clerk_id = find_clerk().id
				if l.has_method("start"):
					l.call("start", QUEST_ID)
				_say("clause")
				stage = 1
				next_day = day + int(cfg["start_delay_days"])
		1:
			if day >= next_day:
				var o: Dictionary = cfg["beats"]["offer"]
				var c := find_clerk()
				var nm := c.display_name if c != null else "The Clerk"
				l.call("offer", QUEST_ID, "offer", str(o["text"]).replace("{clerk}", nm), o["options"])
				stage = 2
		3:
			if day >= next_day:
				_payoff()


## Called by QuestLog when the player answers the offer.
func resolve(option_id: String) -> void:
	on_resolved(QUEST_ID, option_id)


## Test-facing entry for an answer.
func on_resolved(quest_id: String, option_id: String) -> void:
	if quest_id != QUEST_ID or stage != 2:
		return
	choice = option_id
	var day := sim.day()
	match option_id:
		"loophole":
			_loophole()
			_say("notice_loophole")
			next_day = day + int(cfg["notice_delay_days"])
		"report":
			_report()
			next_day = day
		_:
			var l := _log()
			if l != null and l.has_method("set_flag"):
				l.call("set_flag", "clue_clause")
			next_day = day + int(cfg["clue_delay_days"])
	stage = 3
	if option_id == "report":
		_payoff()


func _colony_debt_total() -> int:
	var t := 0
	for id: int in sim.debt.states:
		t += sim.debt.states[id].total
	return t


func _loophole() -> void:
	var c := find_clerk()
	if c != null:
		var st := sim.debt.state_of(c)
		if st != null:
			var by_inmate := int(floor(st.total * float(cfg["cap_pct_inmate"]) / 100.0))
			var by_colony := int(floor(_colony_debt_total() * float(cfg["cap_pct_colony"]) / 100.0))
			var cut := mini(mini(by_inmate, by_colony), st.remaining())
			st.total -= cut
			total_cut += cut
	var lh: Dictionary = cfg["loophole"]
	var days := float(lh["audit_mult_days"])
	var until := sim.tick + roundi(days * sim.ticks_per_day)
	var l := _log()
	if l != null and l.has_method("set_mod"):
		l.call("set_mod", "audit_parts_mult", float(lh["audit_parts_mult"]), until)
	else:
		mods["audit_parts_mult"] = {"value": float(lh["audit_parts_mult"]), "until": until}


func _report() -> void:
	var r: Dictionary = cfg["report"]
	var n := int(r["allowance"])
	var item := str(sim.defs.debt["item"])
	sim.ledger.record_produced(item, n, "q1_allowance")
	sim.items.drop(sim.map_center(), item, n)
	var c := find_clerk()
	if c != null:
		sim.mood.add_thought(c, str(r["mood_thought"]))
		if sim.rng.randf() < float(r["escape_chance"]):
			sim.debt._remove(c, "escaped")
			removed = true


func _payoff() -> void:
	match choice:
		"loophole":
			if sim.rng.randf() < float(cfg["loophole"]["remove_chance"]):
				var c := find_clerk()
				if c != null and c.alive:
					sim.debt._remove(c, "left")
					removed = true
				_say("payoff_loophole")
			else:
				_say("payoff_loophole_kept")
		"report":
			_say("payoff_report_escape" if removed else "payoff_report")
		_:
			_say("clue")
	stage = 4
	var l := _log()
	if l != null and l.has_method("finish"):
		l.call("finish", QUEST_ID)
