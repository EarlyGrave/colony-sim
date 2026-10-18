class_name PowerStub
extends RefCounted
## L4 test / screenshot stand-in for L3's `sim.power` (same read API, see view/power_reader.gd).
## Attach with `sim.set_meta("power_stub", stub)`. Not used once the real grid exists.

const SCN := preload("res://tests/scenario.gd")
const DEF_BASE := {"max_hp": 150, "cost": {}, "buildable": true}

var version := 1
var nets: Array = []
var wires: Array = []
var gens := {}  # building id -> generator_info dict


func networks() -> Array:
	return nets


func links() -> Array:
	return wires


func generator_info(id: int) -> Dictionary:
	return gens.get(id, {})


static func _def(sim: Simulation, id: String, nm: String, size: Vector2i, extra := {}) -> void:
	var d := DEF_BASE.duplicate(true)
	d["name"] = nm
	d["size"] = [size.x, size.y]
	d["color"] = "#888888"
	d.merge(extra, true)
	sim.defs.buildings[id] = d


## Injects the L4 building defs (until L5 lands them) and a powered base around `at`:
## coal generator, nitrogen extractor + turbine, reactor, solar array, 6 poles, smelters, one
## healthy and one browned-out net. Returns {"order": [building ids in plan order], "stub": PowerStub}.
static func build_base(sim: Simulation, at: Vector2i) -> Dictionary:
	_def(sim, "power_pole", "Power Pole", Vector2i(1, 1), {"power_range": 6})
	_def(sim, "coal_generator", "Coal Generator", Vector2i(2, 2), {"power_gen": 80, "fuel": {"item": "coal", "burn_ticks": 200}})
	_def(sim, "nitrogen_extractor", "Nitrogen Extractor", Vector2i(2, 2), {"power_use": 15})
	_def(sim, "nitrogen_turbine", "Nitrogen Turbine", Vector2i(2, 2), {"power_gen": 140, "fuel": {"item": "nitrogen", "burn_ticks": 200}})
	_def(sim, "nuclear_reactor", "Nuclear Reactor", Vector2i(3, 3), {"power_gen": 400, "fuel": {"item": "uranium", "burn_ticks": 600}})
	_def(sim, "solar_array", "Solar Array", Vector2i(2, 2), {"power_gen": 25})
	var plan := [
		["coal_generator", Vector2i(-9, -6)], ["nitrogen_extractor", Vector2i(-5, -6)], ["nitrogen_turbine", Vector2i(-1, -6)],
		["nuclear_reactor", Vector2i(3, -7)], ["solar_array", Vector2i(8, -6)],
		["smelter", Vector2i(-8, 1)], ["smelter", Vector2i(-4, 1)], ["assembler", Vector2i(0, 1)], ["smelter", Vector2i(5, 1)],
		["power_pole", Vector2i(-6, -3)], ["power_pole", Vector2i(-1, -3)], ["power_pole", Vector2i(4, -3)], ["power_pole", Vector2i(8, -3)],
		["power_pole", Vector2i(-2, 0)], ["power_pole", Vector2i(10, 1)],
	]
	var o: Array[int] = []
	for e: Array in plan:
		var b := sim.buildings.place(e[0], SCN.find_spot(sim, e[0], at + (e[1] as Vector2i), 0), false)
		o.append(-1 if b == null else b.id)
	var stub := PowerStub.new()
	stub.wires = [[o[9], o[10]], [o[10], o[11]], [o[11], o[12]], [o[10], o[13]],
		[o[9], o[0]], [o[9], o[1]], [o[10], o[2]], [o[11], o[3]], [o[12], o[4]],
		[o[13], o[5]], [o[13], o[6]], [o[13], o[7]], [o[12], o[14]], [o[14], o[8]]]
	stub.nets = [{"id": 1, "supply": 245.0, "demand": 180.0, "factor": 1.0, "poles": [o[9], o[10], o[11], o[13]],
			"generators": [o[0], o[2], o[3]], "consumers": [o[1], o[5], o[6], o[7]]},
		{"id": 2, "supply": 25.0, "demand": 90.0, "factor": 0.28, "poles": [o[12], o[14]],
			"generators": [o[4]], "consumers": [o[8]]}]
	stub.gens = {o[0]: {"burning": true, "fuel": 14, "fuel_cap": 20, "fuel_item": "coal", "supply": 80.0, "waste_per_min": 2.4},
		o[2]: {"burning": true, "fuel": 9, "fuel_cap": 20, "fuel_item": "nitrogen", "supply": 140.0, "waste_per_min": 0.8},
		o[3]: {"burning": true, "fuel": 3, "fuel_cap": 10, "fuel_item": "uranium", "supply": 25.0, "overheat": 0.85, "waste_per_min": 0.1},
		o[4]: {"burning": true, "fuel": 0, "fuel_cap": 0, "fuel_item": "", "supply": 25.0}}
	sim.set_meta("power_stub", stub)
	return {"order": o, "stub": stub}
