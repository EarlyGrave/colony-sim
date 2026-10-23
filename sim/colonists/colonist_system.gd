class_name ColonistSystem
extends RefCounted
## Owns colonists and ticks them (decisions are delegated to JobSystem).

const NAMES: Array[String] = [
	"Vera", "Thunder", "Fox", "Miron", "Wheezy", "Shade", "Whip", "Ginger", "Gramps", "Awl", "Alder", "Wick",
]

var sim: Simulation
var list: Array[Colonist] = []
var _next_id := 1


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	# region F3
	sim.listen(sim.bus.wave_ended, _f3_wave_ended)
	sim.listen(sim.bus.day_started, _f3_day)
	# endregion


func spawn(cell: Vector2i) -> Colonist:
	var nm := NAMES[sim.rng.randi_range(0, NAMES.size() - 1)]
	var c := Colonist.new(_next_id, nm, cell, sim.defs.balance["colonist"])
	_next_id += 1
	# region jobs-core
	c.skills = Skills.create(sim.defs, sim.rng)
	# endregion
	# region combat
	c.combat = CombatState.new()
	c.combat.weapon = str(sim.defs.weapons["combat"]["start_weapon"])
	# endregion
	list.append(c)
	_f3a_start_gear(c)  # region F3a
	return c


# region arrivals
func alloc_id() -> int:
	_next_id += 1
	return _next_id - 1


## Adds an already built colonist (arrivals) to the colony.
func add(c: Colonist) -> void:
	list.append(c)
	sim.bus.colonist_joined.emit(c.id)
# endregion


func tick() -> void:
	_f3a_equip_start()  # region F3a
	for c in list:
		if c.alive:
			sim.jobs.tick_colonist(c)


func alive_count() -> int:
	var n := 0
	for c in list:
		if c.alive:
			n += 1
	return n


func get_by_id(id: int) -> Colonist:
	for c in list:
		if c.id == id:
			return c
	return null


func kill(c: Colonist) -> void:
	if not c.alive:
		return
	if c.job != null and c.job.type == "flee":  # region LD: killed while running for cover
		var sh := sim.buildings.find_shelter(c.cell) if sim.buildings else null
		if sh == null or Vector2(sh.cell).distance_to(Vector2(c.cell)) > 12.0:
			sim.ledger.record_event("died:flee", 1)
	sim.jobs.end_job(c, Job.Status.FAILED)
	if c.carry_count > 0:
		sim.items.drop(c.cell, c.carry_item, c.carry_count, c.carry_quality)
		c.carry_item = ""
		c.carry_count = 0
	c.alive = false
	c.hidden = false
	sim.bus.colonist_died.emit(c.id)


# region F3
## Ids of commendations already awarded this run (rebuilt by replay, not hashed).
var commended: Array = []


## Career counters live here, not on Colonist: golden part dumps serialise every
## Colonist property. Plain Dictionaries (no new Object/script in the sim).
var records: Dictionary = {}


func rec(c: Colonist) -> Dictionary:
	if not records.has(c.id):
		records[c.id] = {"kills": {}, "ore_mined": 0, "refined": 0, "repairs": 0, "belts_repaired": 0, "downs": 0, "waves_survived": 0, "nick_stat": ""}
	return records[c.id]


func rec_stat(c: Colonist, name: String) -> int:
	var r := rec(c)
	if name == "kills":
		var n := 0
		for k: String in r["kills"]:
			n += int(r["kills"][k])
		return n
	return int(r.get(name, 0))


func add_kill(c: Colonist, species: String) -> void:
	var k: Dictionary = rec(c)["kills"]
	k[species] = int(k.get(species, 0)) + 1
	record_changed(c)


func record_changed(c: Colonist) -> void:
	if sim.passives != null and sim.passives.enabled():  # region F11W2
		sim.passives.on_record_changed(c)
	var r := rec(c)
	if r["nick_stat"] != "":
		return
	var cfg: Dictionary = sim.defs.balance["flavor"]
	for s: String in cfg["nick_order"]:
		if rec_stat(c, s) >= int(cfg["nick_" + s]):
			r["nick_stat"] = s
			return


func _f3_wave_ended(_i: int) -> void:
	for c in list:
		if c.alive:
			rec(c)["waves_survived"] += 1
			record_changed(c)


func _f3_day(_d: int) -> void:
	var cm: Dictionary = sim.defs.milestones.get("commendations", {})
	for id: String in _f3_earned():
		commended.append(id)
		if not sim.replaying:
			sim.bus.letter_received.emit(str(cm[id]["title"]), str(cm[id]["text"]))
# endregion


# region F3
func colony_total(stat_name: String) -> int:
	var n := 0
	for c in list:
		n += rec_stat(c, stat_name)
	return n


func _f3_earned() -> Array:
	var out: Array = []
	var defs: Dictionary = sim.defs.milestones.get("commendations", {})
	var ids: Array = defs.keys()
	ids.sort()
	for id: String in ids:
		var d: Dictionary = defs[id]
		if commended.has(id) or colony_total(str(d["stat"])) < int(d["min"]):
			continue
		if d.has("max_other") and colony_total(str(d["other"])) > int(d["max_other"]):
			continue
		out.append(id)
	return out
# endregion


# region F3a
## Start gear: every inmate owns a prison shiv as a real GearItem (common, ilvl 0; no rng draw). Non-engineers wear it from tick 0
## (engineers keep their rifle from weapons.json), so the bot's equip rule and the UI see a real item in the weapon slot.
var _f3a_pending: Array[int] = []


func _f3a_start_gear(c: Colonist) -> void:
	if sim.equipment == null or not sim.defs.gear.has("prison_shiv"):
		return
	if sim.equipment.give(c.id, "prison_shiv", "common", 0) >= 0:
		_f3a_pending.append(c.id)


func _f3a_equip_start() -> void:
	if _f3a_pending.is_empty():
		return
	for cid: int in _f3a_pending:
		var c := get_by_id(cid)
		if c == null or c.engineer:
			continue
		for id: int in sim.equipment.stored_of(cid):
			if sim.equipment.instances[id].base == "prison_shiv":
				sim.equipment.equip(cid, id)
				break
	_f3a_pending.clear()
# endregion
