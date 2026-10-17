class_name FarmingSystem
extends RefCounted
## Plants on "growing" zone cells. Sowing and harvesting are done by jobs
## (SowJob / HarvestJob); this system only grows plants. Defs: data/plants.json.

const ZONE := "growing"

var sim: Simulation
## Vector2i -> Plant, insertion-ordered.
var plants: Dictionary = {}


func _init(p_sim: Simulation) -> void:
	sim = p_sim


## The crop sown by default (first entry of data/plants.json).
func default_crop() -> String:
	for id: String in sim.defs.plants:
		return id
	return ""


func plant_at(c: Vector2i) -> Plant:
	return plants.get(c)


func is_mature(p: Plant) -> bool:
	return p.growth >= int(sim.defs.plants[p.def_id]["grow_ticks"])


func growth_fraction(p: Plant) -> float:
	return clampf(float(p.growth) / float(sim.defs.plants[p.def_id]["grow_ticks"]), 0.0, 1.0)


func can_sow(c: Vector2i) -> bool:
	return sim.map.get_zone(c) == ZONE and not plants.has(c) and not sim.items.stacks.has(c) \
		and sim.cell_free_for_items(c)


func sow(c: Vector2i, plant_id: String, sower: Colonist = null) -> bool:
	if not can_sow(c) or not sim.defs.plants.has(plant_id):
		return false
	plants[c] = Plant.new(plant_id, c)
	plants[c].grow_bonus = sim.perks.mod(sower, "grow_speed")  # region perks
	sim.bus.plant_sown.emit(c, plant_id)
	return true


## Removes a mature plant and drops its yield on the cell. Returns the amount.
func harvest(c: Vector2i, harvester: Colonist = null) -> int:
	var p := plant_at(c)
	if p == null or not is_mature(p):
		return 0
	var def: Dictionary = sim.defs.plants[p.def_id]
	plants.erase(c)
	var n := int(def["yield"])
	# region perks
	n = PerkHooks.scaled(harvester, "harvest_yield", float(n), 1.0 + sim.perks.mod(harvester, "harvest_yield"))
	if sim.perks.consume_flag(harvester, "double_harvest"):
		n *= 2
	# endregion
	var item: String = def["item"]
	sim.ledger.record_produced(item, n, "farming")
	sim.items.drop(c, item, n)
	sim.bus.plant_harvested.emit(c, item, n)
	return n


func tick() -> void:
	if plants.is_empty():
		return
	var light := sim.clock.daylight()
	var dead: Array[Vector2i] = []
	for c: Vector2i in plants:
		var p: Plant = plants[c]
		if sim.map.get_zone(c) != ZONE:
			dead.append(c)  # zone removed: the crop is gone
		elif light >= float(sim.defs.plants[p.def_id]["min_daylight"]):
			p.growth += 1
			if p.grow_bonus != 0.0:  # region perks
				p.grow_acc += p.grow_bonus
				var extra := floori(p.grow_acc)
				p.grow_acc -= extra
				p.growth = maxi(0, p.growth + extra)
	for c in dead:
		plants.erase(c)
		sim.jobs.reserved.erase("plant:%d,%d" % [c.x, c.y])
