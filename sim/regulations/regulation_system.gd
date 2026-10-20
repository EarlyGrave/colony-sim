class_name RegulationSystem
extends RefCounted
## F5 W1 Standing Orders: at set days the warden offers a slot with 3 exclusive options (data/regulations.json).
## Effects are permanent multipliers (quests.set_mod hooks + a waste mult). An unanswered slot takes its
## default after `timeout_days`. State is rebuilt by command replay (choose_regulation), so no save code.

var sim: Simulation
var slots: Array = []
var timeout_ticks := 0
## slot index -> chosen option id
var chosen: Dictionary = {}
## Open slot: index, or -1
var pending := -1
var expires := 0
## stat -> product of picked multipliers
var _mults: Dictionary = {}


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	var d: Dictionary = sim.defs.regulations
	slots = d.get("slots", [])
	timeout_ticks = roundi(float(d.get("settings", {}).get("timeout_days", 2.0)) * sim.ticks_per_day)


func enabled() -> bool:
	return bool(sim.defs.balance.get("reg_enabled", false)) and not slots.is_empty()


func tick() -> void:
	if not enabled():
		return
	if pending >= 0:
		if sim.tick >= expires:
			_apply(pending, str(slots[pending]["default"]), true)
		return
	var next := chosen.size()
	if next < slots.size() and sim.day() >= int(slots[next]["day"]):
		pending = next
		expires = sim.tick + timeout_ticks
		var s: Dictionary = slots[next]
		sim.bus.story_event.emit("reg_slot_%d" % next, "Standing Orders: %s. %s" % [s["title"], s["text"]])
		sim.bus.regulation_offered.emit(next)  # region F7W3


## Why an option cannot be picked ("" = fine).
func reject_reason(slot: int, id: String) -> String:
	if not enabled() or pending < 0 or slot != pending:
		return "not open"
	var opts: Dictionary = slots[slot]["options"]
	if not opts.has(id):
		return "unknown option"
	for ex in opts[id].get("excludes", []):
		if picked(str(ex)):
			return "locked by " + str(ex)
	return ""


func picked(id: String) -> bool:
	for k in chosen:
		if chosen[k] == id:
			return true
	return false


func choose(slot: int, id: String) -> bool:
	if reject_reason(slot, id) != "":
		return false
	_apply(slot, id, false)
	return true


func _apply(slot: int, id: String, by_timeout: bool) -> void:
	var o: Dictionary = slots[slot]["options"][id]
	chosen[slot] = id
	pending = -1
	var fx: Dictionary = o.get("effects", {})
	for stat: String in fx:
		_mults[stat] = float(_mults.get(stat, 1.0)) * float(fx[stat])
		if stat != "waste" and sim.quests != null:
			sim.quests.set_mod(stat, float(sim.quests.mod(stat)) * float(fx[stat]), 0.0)
	sim.bus.story_event.emit("reg_done_%d" % slot, "Standing Orders: %s%s." % [o["label"], " (by default)" if by_timeout else ""])
	sim.bus.regulation_chosen.emit(slot, id, by_timeout)  # region F7W3


func mult(stat: String) -> float:
	return float(_mults.get(stat, 1.0))


## Count of answered slots (bot report column).
func count() -> int:
	return chosen.size()
