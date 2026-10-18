class_name PowerScene
extends RefCounted
## Test / screenshot helper: builds a real powered base (real defs, real sim.power) around `at`.
## Returns {"order": [building ids in plan order]}: coal gen, nitrogen extractor, turbine, reactor,
## solar, smelter x2, assembler, far smelter, 6 poles. Generators are hand-fuelled.

const SCN := preload("res://tests/scenario.gd")


static func build_base(sim: Simulation, at: Vector2i) -> Dictionary:
	var plan := [
		["coal_generator", Vector2i(-9, -6)], ["nitrogen_extractor", Vector2i(-5, -6)], ["nitrogen_turbine", Vector2i(-1, -6)],
		["nuclear_reactor", Vector2i(3, -7)], ["solar_array", Vector2i(8, -6)],
		["smelter", Vector2i(-8, 1)], ["smelter", Vector2i(-4, 1)], ["assembler", Vector2i(0, 1)], ["smelter", Vector2i(5, 1)],
		["power_pole", Vector2i(-6, -3)], ["power_pole", Vector2i(-1, -3)], ["power_pole", Vector2i(4, -3)], ["power_pole", Vector2i(8, -3)],
		["power_pole", Vector2i(-2, 0)], ["power_pole", Vector2i(10, 1)],
	]
	for t: String in ["electrification", "clean_power", "nuclear"]:  # mark the power techs done (no-op if unknown)
		if sim.research.tech(t).size() > 0 and not sim.research.done.has(t):
			sim.research.done.append(t)
			sim.research.done.sort()
	var o: Array[int] = []
	for e: Array in plan:
		var b := sim.buildings.place(e[0], SCN.find_spot(sim, e[0], at + (e[1] as Vector2i), 0), false)
		o.append(-1 if b == null else b.id)
	for k: Array in [[0, "coal", 14], [2, "nitrogen", 9], [3, "uranium", 3]]:
		var g := sim.buildings.get_by_id(o[k[0]])
		if g != null:
			g.input[k[1]] = k[2]
	sim.run_ticks(5)
	return {"order": o}
