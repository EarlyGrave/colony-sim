class_name Storyteller
extends RefCounted
## AI director. A few times a day it may fire one event from data/events.json.
## Design rule: an event breaks exactly ONE link, and a new event only comes
## when the colony is whole again (nothing broken, nobody sick, no wave).

var sim: Simulation
var cfg: Dictionary
## event id -> number of times fired
var fired: Dictionary = {}
var last_event := ""


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	cfg = sim.defs.balance["storyteller"]
	sim.listen(sim.bus.first_refine_done, func() -> void:
		_say("first_refine", "Первая партия очищена. Отходы отравляют планету — запущен прогноз конца."))
	sim.listen(sim.bus.threat_awakened, func() -> void:
		_say("awakened", "Из-под земли доносится скрежет. Твари проснулись."))
	sim.listen(sim.bus.wave_started, func(i: int, _s: float) -> void:
		_say("wave", "Волна %d! Колонисты бегут в капсулу." % i))
	sim.listen(sim.bus.wave_incoming, func(origin: Vector2i, _t: int) -> void:
		_say("wave_incoming", "Твари идут с %s!" % sim.threats.side_name(origin)))
	sim.listen(sim.bus.building_broken, func(id: int) -> void:
		var b := sim.buildings.get_by_id(id)
		if b:
			_say("broken", "%s сломалась — нужен ремонт." % b.def["name"]))


func tick() -> void:
	if not bool(cfg["enabled"]):
		return
	var period := maxi(1, sim.ticks_per_day / int(cfg["checks_per_day"]))
	if sim.tick % period != 0 or not colony_is_whole():
		return
	if sim.rng.randf() >= float(cfg["chance"]):
		return
	var id := _pick_event()
	if id != "":
		fire(id)


## True when no link is currently broken, so a new event is fair.
func colony_is_whole() -> bool:
	var t := sim.threats
	if t.wave_active:
		return false
	if t.awakened and t.next_wave_tick - sim.tick < int(cfg["quiet_before_wave_ticks"]):
		return false
	for b in sim.buildings.list:
		if b.broken:
			return false
	for c in sim.colonists.list:
		if c.alive and c.is_sick(sim.tick):
			return false
	return true


func _pick_event() -> String:
	var options: Array[String] = []
	var total := 0.0
	for id: String in sim.defs.events:
		var e: Dictionary = sim.defs.events[id]
		if sim.day() + 1 >= int(e["min_day"]) and _eligible(id):
			options.append(id)
			total += float(e["weight"])
	if options.is_empty():
		return ""
	var roll := sim.rng.randf() * total
	for id in options:
		roll -= float(sim.defs.events[id]["weight"])
		if roll <= 0.0:
			return id
	return options[-1]


func _eligible(id: String) -> bool:
	match id:
		"lightning":
			return not _machines().is_empty()
		"sickness":
			return _healthy_colonists().size() >= 2
		"cave_in":
			return not _designated_deposits().is_empty()
	return false


## Fires an event now (also used by tests). Returns false if it can't apply.
func fire(id: String) -> bool:
	if not _eligible(id):
		return false
	var e: Dictionary = sim.defs.events[id]
	var target := ""
	match id:
		"lightning":
			var ms := _machines()
			var b: Building = ms[sim.rng.randi_range(0, ms.size() - 1)]
			sim.buildings.wear(b, 1000.0)
			target = b.def["name"]
		"sickness":
			var cs := _healthy_colonists()
			var c: Colonist = cs[sim.rng.randi_range(0, cs.size() - 1)]
			sim.health.add_illness(c, "fever", 1.0, int(e["duration_ticks"]))  # region health
			target = c.display_name
		"cave_in":
			var ds := _designated_deposits()
			var start: Vector2i = ds[sim.rng.randi_range(0, ds.size() - 1)]
			var cells: Array[Vector2i] = [start]
			for d in MapGrid.NEIGHBORS_4:
				if cells.size() < int(e["max_cells"]) and sim.map.is_deposit(start + d):
					cells.append(start + d)
			for c in cells:
				sim.map.collapse_deposit(c)
	fired[id] = int(fired.get(id, 0)) + 1
	last_event = id
	_say(id, str(e["text"]).replace("{target}", target))
	return true


func _machines() -> Array[Building]:
	var out: Array[Building] = []
	for b in sim.buildings.list:
		if b.is_machine() and not b.broken:
			out.append(b)
	return out


func _healthy_colonists() -> Array[Colonist]:
	var out: Array[Colonist] = []
	for c in sim.colonists.list:
		if c.alive and not c.is_sick(sim.tick):
			out.append(c)
	return out


func _designated_deposits() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var m := sim.map
	for i in m.mine_designated.size():
		if m.mine_designated[i] != 0:
			out.append(Vector2i(i % m.width, i / m.width))
	return out


func _say(event_id: String, text: String) -> void:
	sim.bus.story_event.emit(event_id, text)
