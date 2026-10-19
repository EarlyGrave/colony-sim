class_name Q2Pilgrims
extends RefCounted
## Quest Q2 "Pilgrims of the Slag" (data/quests_q2.json). Driven by QuestLog (Q0):
##   QuestLog calls `poll()` once per day and `resolve(option_id)` when the player answers.
## Assumed QuestLog API (all optional, guarded): offer(quest_id, beat_id, text, options), set_flag(id),
## set_mod(name, mult, days). Without sim.quests the quest still runs (tests drive it directly).
## Inert unless `q_enabled`; state is hashed only once the quest started.

const ID := "pilgrims_of_the_slag"

var sim: Simulation
var cfg: Dictionary
var state := "idle"  ## idle | offered | active | done
var oto_id := -1
var option := ""
var oto_dies := false
var last_mods: Dictionary = {}  ## name -> [mult, days] (mirror of what was sent to QuestLog)


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests_q2.json"))
	cfg = (parsed as Dictionary)[ID]
	sim.listen(sim.bus.wave_ended, _on_wave_ended)


func _quests() -> Object:
	return sim.get("quests")


func enabled() -> bool:
	return bool(sim.defs.balance.get("q_enabled", false))


## Daily trigger check (pollution first above the threshold).
func poll() -> void:
	if state != "idle" or not enabled():
		return
	if sim.contamination.fraction() >= float(cfg["trigger"]["pollution_min"]):
		begin()


func begin() -> void:
	if state != "idle":
		return
	state = "offered"
	var c := sim.colonists.spawn(sim.map_center())
	c.display_name = str(cfg["zealot_name"])
	oto_id = c.id
	sim.bus.colonist_joined.emit(c.id)
	sim.debt.states.erase(c.id)  # a pilgrim owes the slag, not the Warden: keeps the colony debt total (and audit demands) untouched
	sim.bus.letter_received.emit(str(cfg["zealot_name"]), str(cfg["letter"]) + " " + str(cfg["prayer"]))
	var q := _quests()
	if q != null:
		q.start(ID)
		q.offer(ID, "prayer", str(cfg["prayer"]), cfg["options"])


func dump_cell() -> Vector2i:
	var want := str(cfg["dump_building"])
	for b: Building in sim.buildings.list:
		if b.def_id == want:
			return b.cell
	return sim.map_center()


## Applies the player's choice. Returns false if not pending or unknown option.
func resolve(option_id: String) -> bool:
	if state != "offered" or not cfg["beats"].has(option_id):
		return false
	var beat: Dictionary = cfg["beats"][option_id]
	option = option_id
	state = "active"
	match option_id:
		"let":
			sim.threats.q2_arm(dump_cell(), int(cfg["wave_delay_seconds"]) * Simulation.TICKS_PER_SECOND)
			oto_dies = sim.rng.randf() < float(beat["death_chance"])
		"silence":
			for c in sim.colonists.list:
				if c.alive:
					sim.mood.add_thought(c, str(beat["thought"]))
		"join":
			for _i in int(beat["extra_colonists"]):
				var c := sim.colonists.spawn(sim.map_center())
				sim.bus.colonist_joined.emit(c.id)
			_mod("refine_mult", float(beat["refine_mult"]), float(beat["refine_days"]))
			_mod("wave_mult", float(beat["wave_mult"]), float(beat["wave_days"]))
	sim.bus.letter_received.emit(str(cfg["zealot_name"]), str(beat["text"]))
	var q := _quests()
	if q != null:
		q.set_flag("q2_" + option_id)
	if option_id != "let":
		_done()
	return true


func _done() -> void:
	state = "done"
	var q := _quests()
	if q != null:
		q.finish(ID)


func _mod(mod_name: String, mult: float, days: float) -> void:
	last_mods[mod_name] = [mult, days]
	var q := _quests()
	if q != null:
		q.set_mod(mod_name, mult, days)


func _on_wave_ended(_i: int) -> void:
	if state != "active" or option != "let":
		return
	_done()
	if oto_dies:
		var c := sim.colonists.get_by_id(oto_id)
		if c != null:
			sim.colonists.kill(c)


## Hash rows: empty until the quest has started (keeps existing hashes byte-identical).
func state_parts() -> Array:
	if state == "idle":
		return []
	return ["q2", state, oto_id, option, oto_dies]
