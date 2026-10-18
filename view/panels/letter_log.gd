class_name LetterLog
extends RefCounted
## Bus-driven log of important events ("letters"). Pure view-side state.
## Entries: {"text", "tick", "level": "info"|"warn"|"bad", "cell": Vector2i (optional)}.

signal letter_added(entry: Dictionary)

const MAX_ENTRIES := 60

var entries: Array[Dictionary] = []
var unread := 0
var sim: Simulation
var _bus: Object
var _mutation_told := false
var _conns: Array = []  # [signal name, callable]


func bind(p_sim: Simulation, bus: Object) -> void:
	unbind()
	sim = p_sim
	_bus = bus
	entries.clear()
	unread = 0
	_mutation_told = false
	_listen("wave_started", func(i: int = 0, strength: float = 0.0) -> void:
		add("Wave %d has begun (strength ~%.0f)." % [i, strength], "bad"))
	_listen("wave_incoming", func(a: Variant = null, b: Variant = null) -> void:
		add("A creature wave is approaching.", "warn"))
	_listen("wave_ended", func(i: int = 0) -> void: add("Wave %d repelled." % i, "info"))
	_listen("threat_awakened", func() -> void: add("The creatures have awakened.", "warn"))
	_listen("building_broken", func(id: int = 0) -> void: add("Broken: %s." % _building_name(id), "warn"))
	_listen("building_destroyed", func(id: int = 0) -> void: add("Destroyed: %s." % _building_name(id), "bad"))
	_listen("colonist_died", func(id: int = 0) -> void: add("Colonist died: %s." % _colonist_name(id), "bad"))
	_listen("story_event", func(_id: String = "", text: String = "") -> void: add(text, "warn"))
	_listen("raid_started", func(raid_id: String = "", _p: float = 0.0, n: int = 0) -> void:
		var rd: Dictionary = sim.defs.raids.get(raid_id, {}) if sim.get("defs") and sim.defs.get("raids") != null else {}
		add("Raid: %s (%d creatures)." % [str(rd.get("name", raid_id)), n], "bad"))
	_listen("raid_tremor", func(cell: Vector2i = Vector2i.ZERO, _t: int = 0, text: String = "") -> void:
		add(text if text != "" else "The ground trembles…", "warn", cell))
	_listen("raid_burrowed", func(cell: Vector2i = Vector2i.ZERO, n: int = 0) -> void:
		add("Creatures burst from the ground (%d)." % n, "bad", cell))
	_listen("raid_retreat", func(_r: String = "") -> void: add("The creatures fall back.", "info"))
	_listen("colonist_downed", func(id: int = 0) -> void:
		add("Colonist unconscious: %s." % _colonist_name(id), "bad", _colonist_cell(id)))
	_listen("colonist_joined", func(id: int = 0) -> void:
		add("%s joined the colony." % _colonist_name(id), "info", _colonist_cell(id)))
	_listen("event_choice_posted", func(_u: int = 0, text: String = "") -> void:
		add("IMPORTANT: %s (Events panel)" % text, "bad"))
	_listen("mood_break_started", func(id: int = 0, kind: String = "") -> void:
		add("Breakdown for %s: %s." % [_colonist_name(id), kind], "bad", _colonist_cell(id)))
	_listen("colonist_starving", func(id: int = 0) -> void:
		add("Starving: %s." % _colonist_name(id), "warn", _colonist_cell(id)))
	_listen("perk_point_available", func(id: int = 0, skill_id: String = "", _pts: int = 0) -> void:
		var lbl: String = str(sim.defs.skills["skills"].get(skill_id, {}).get("label", skill_id))
		var e := add("%s earned a new point: %s" % [_colonist_name(id), lbl], "info")
		if not e.is_empty():
			e["panel"] = "perks"
			e["colonist_id"] = id
			e["skill"] = skill_id)
	_listen("ammo_depleted", func(kind: String = "", id: int = 0) -> void:  # region ammo
		add("Out of ammo: %s." % (_building_name(id) if kind == "turret" else _colonist_name(id)), "bad"))
	# region debt
	_listen("debt_paid", func(id: int = 0) -> void:
		add("%s paid off the debt. Stay or leave the planet? (inspect)" % _colonist_name(id), "info", _colonist_cell(id)))
	_listen("riot_started", func(id: int = 0) -> void:
		add("Riot: %s is wrecking buildings!" % _colonist_name(id), "bad", _colonist_cell(id)))
	_listen("colonist_escaped", func(id: int = 0) -> void: add("Escape: %s fled the planet." % _colonist_name(id), "bad"))
	_listen("escape_stopped", func(id: int = 0) -> void: add("Escapee %s stopped." % _colonist_name(id), "info", _colonist_cell(id)))
	# endregion
	# region batch3 ui
	_listen("wave_repelled", func(i: int = 0) -> void: add("Raid %d repelled with no defense losses." % i, "info"))
	_listen("patrol_spotted", func(_id: int = 0, cell: Vector2i = Vector2i.ZERO, n: int = 0) -> void:
		add("Patrol spotted creatures: %d." % n, "warn", cell))
	_listen("debt_choice_made", func(id: int = 0, outcome: String = "") -> void:
		add("%s: %s." % [_colonist_name(id), "stayed on as a free colonist" if outcome == "stayed" else "left the planet"], "info"))
	_listen("cell_mutated", func(cell: Vector2i = Vector2i.ZERO) -> void:
		if not _mutation_told:
			_mutation_told = true
			add("The ground has mutated. Essence can purify it (inspect the cell).", "warn", cell))
	_listen("contract_offered", func(_cid: int = 0) -> void:
		var e := add("New warden contract.", "warn")
		if not e.is_empty():
			e["panel"] = "contracts")
	# endregion
	_listen("forecast_revealed", func() -> void: add("Planet doom forecast revealed.", "info"))


func unbind() -> void:
	if _bus != null and is_instance_valid(_bus):
		for c: Array in _conns:
			if _bus.is_connected(c[0], c[1]):
				_bus.disconnect(c[0], c[1])
	_conns.clear()
	_bus = null
	sim = null


## Returns the stored entry (callers may add keys such as "panel"), {} if empty text.
## Note: letter_added is emitted before such keys are added, which is fine for toasts.
func add(text: String, level := "info", cell: Variant = null) -> Dictionary:
	if text == "":
		return {}
	var entry := {"text": text, "tick": sim.tick if sim else 0, "level": level}
	if cell is Vector2i:
		entry["cell"] = cell
	entries.push_front(entry)
	if entries.size() > MAX_ENTRIES:
		entries.pop_back()
	unread += 1
	letter_added.emit(entry)
	return entry


func mark_read() -> void:
	unread = 0


func _listen(signal_name: String, callable: Callable) -> void:
	if _bus == null or not _bus.has_signal(signal_name):
		return
	_bus.connect(signal_name, callable)
	_conns.append([signal_name, callable])


func _building_name(id: int) -> String:
	var b: Building = sim.buildings.get_by_id(id) if sim else null
	return str(b.def["name"]) if b else "building"


func _colonist_name(id: int) -> String:
	if sim:
		for c in sim.colonists.list:
			if c.id == id:
				return c.display_name
	return "?"


func _colonist_cell(id: int) -> Variant:
	if sim:
		for c in sim.colonists.list:
			if c.id == id:
				return c.cell
	return null
