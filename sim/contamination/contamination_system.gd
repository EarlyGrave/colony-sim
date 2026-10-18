class_name ContaminationSystem
extends RefCounted
## Global planet contamination. Grows from every refining batch and from
## waste lying around (less inside a waste dump). After the first batch the
## forecast of the planet's end is revealed.

var sim: Simulation
var level := 0.0
## Smoothed contamination growth, units per day.
var rate_per_day := 0.0
var revealed := false
var _cfg: Dictionary
var _last_level := 0.0


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	_cfg = sim.defs.balance["contamination"]
	sim.listen(sim.bus.batch_refined, _on_batch_refined)
	sim.listen(sim.bus.first_refine_done, _on_first_refine)


func _on_batch_refined(_building_id: int, _recipe_id: String) -> void:
	level += float(_cfg["per_batch"]) * maxf(0.0, 1.0 + sim.perks.mod(sim.buildings.batch_operator, "contamination_per_batch")) * sim.crises.mult("refine_contam_mult")  # region perks


func _on_first_refine() -> void:
	revealed = true
	sim.bus.forecast_revealed.emit()


func tick() -> void:
	level += waste_units() * float(_cfg["per_waste_per_day"]) / sim.ticks_per_day
	var per_day := (level - _last_level) * sim.ticks_per_day
	_last_level = level
	var alpha := 1.0 / (float(_cfg["rate_smoothing_days"]) * sim.ticks_per_day)
	rate_per_day += alpha * (per_day - rate_per_day)
	if sim.tick % 10 == 0:
		sim.bus.contamination_changed.emit(level)
	if level >= float(_cfg["max"]):
		sim.end_game("planet_dead")


## Waste weighted by where it lies (zones define an emission factor).
func waste_units() -> float:
	var s := 0.0
	for c: Vector2i in sim.items.stacks:
		var st: Dictionary = sim.items.stacks[c]
		if not sim.defs.items[st["item"]].get("contaminates", false):
			continue
		var zone := sim.map.get_zone(c)
		var f := float(sim.defs.zones[zone]["waste_emission_factor"]) if zone != "" else 1.0
		s += f * int(st["count"])
	for item_id: String in sim.defs.items:
		if not sim.defs.items[item_id].get("contaminates", false):
			continue
		for col in sim.colonists.list:
			if col.carry_item == item_id:
				s += col.carry_count
		s += sim.buildings.count_item(item_id)
	return s


func fraction() -> float:
	return level / float(_cfg["max"])


func forecast() -> Dictionary:
	return ForecastModel.estimate(level, rate_per_day, _cfg, machine_rate_per_day())


## Contamination per day of the processors that are mid-batch right now
## (batches/day x per_batch). Idle or broken machines add nothing.
func machine_rate_per_day() -> float:
	var s := 0.0
	for b in sim.buildings.list:
		if b.broken or b.destroyed or b.progress <= 0 or str(b.def.get("machine", "")) != "processor":
			continue
		if not sim.buildings._is_refining(b):
			continue
		s += float(sim.ticks_per_day) / maxf(1.0, float(b.recipe.get("work_ticks", 100))) * float(_cfg["per_batch"])
	return s
