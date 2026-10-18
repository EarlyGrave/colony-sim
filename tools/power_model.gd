extends SceneTree
## L5 power model: analytic throughput / waste / threat / fuel per day from the data files (no simulation run).
##   godot --headless --path . -s tools/power_model.gd
## A "line" is N smelters running smelt_iron. Unpowered = consumers outside any pole range (factor
## `power.unpowered_factor`); powered = brownout factor clamp(supply/demand, min_factor, 1).
## Generators burn only while demand > 0, one fuel unit per burn_ticks, waste_per_burn each.
## The same statics back tests/test_logistics2_defs.gd (balance gates).


## mix: {building_id: count}. n smelters. Returns throughput/waste/threat/fuel per day for the line.
static func line(defs_: Defs, n: int, mix: Dictionary) -> Dictionary:
	var pw: Dictionary = defs_.balance["power"]
	var tpd := float(defs_.balance["ticks_per_day"])
	var rec: Dictionary = defs_.recipes["smelt_iron"]
	var batch_ticks := float(rec["work_ticks"])
	var waste_batch := float(rec["outputs"].get("waste", 0))
	var demand := float(n) * float(defs_.buildings["smelter"]["power_use"])
	var supply := 0.0
	var threat := 0.0
	var gen_waste := 0.0
	var spent := 0.0
	var fuel := {}
	for bid: String in mix:
		var g: Dictionary = defs_.buildings[bid]
		var k := int(mix[bid])
		supply += gen_of(defs_, bid) * k
		threat += float(g.get("threat", 0)) * k
		var fu: Variant = g.get("fuel", null)
		if fu != null:
			var burns := tpd / float(fu["burn_ticks"]) * k  # demand > 0 all day
			gen_waste += burns * float(fu["waste_per_burn"])
			spent += burns * float(fu.get("spent_per_burn", 0))
			fuel[fu["item"]] = float(fuel.get(fu["item"], 0.0)) + burns
	var unp := float(pw["unpowered_factor"])
	var f := clampf(supply / demand, float(pw["min_factor"]), 1.0) if demand > 0.0 else 1.0
	var base := tpd / batch_ticks * n  # batches/day at factor 1
	return {
		"demand": demand, "supply": supply, "factor": f,
		"thr_unpowered": base * unp, "thr_powered": base * f, "ratio": f / unp,
		"waste_unpowered": base * unp * waste_batch,
		"waste_powered": base * f * waste_batch + gen_waste,
		"gen_waste": gen_waste, "spent": spent, "threat": threat, "fuel": fuel,
	}


# region K5
## Generator output; k5 = true uses the `k5_power_gen` override (solar ~30% of a smelter).
static func gen_of(defs_: Defs, bid: String) -> float:
	var g: Dictionary = defs_.buildings[bid]
	if g.has("k5_power_gen") and bool(defs_.balance.get("k5_enabled", false)):
		return float(g["k5_power_gen"])
	return float(g["power_gen"])


## Solar arrays a "sane build" needs so n smelters run at >= target factor.
static func solars_for(defs_: Defs, n: int, target := 0.75) -> int:
	return ceili(target * float(n) * float(defs_.buildings["smelter"]["power_use"]) / gen_of(defs_, "solar_array"))
# endregion


## Essence cost of a building (ore + 3 x refined), for the solar-vs-burner gate.
static func essence_cost(defs_: Defs, bid: String) -> float:
	var c: Dictionary = defs_.buildings[bid]["cost"]
	return float(c.get("essence_ore", 0)) + 3.0 * float(c.get("refined_essence", 0))


func _init() -> void:
	var bus: Node = load("res://autoload/event_bus.gd").new()
	var d: Defs = Simulation.new(1, bus).defs
	print("== Fuels (per generator) ==")
	print("%-8s %-17s %5s %6s %7s %9s %7s %6s" % ["fuel", "generator", "gen", "burn_t", "waste/b", "energy/u", "w/kE", "threat"])
	for fid: String in d.fuels["fuels"]:
		var fd: Dictionary = d.fuels["fuels"][fid]
		var g: Dictionary = d.buildings[fd["generator"]]
		print("%-8s %-17s %5d %6d %7.1f %9d %7.3f %6d" % [fid, fd["generator"], g["power_gen"], g["fuel"]["burn_ticks"], g["fuel"]["waste_per_burn"],
				fd["energy_per_unit"], 1000.0 * float(fd["waste_per_unit"]) / float(fd["energy_per_unit"]), g["threat"]])
	print("solar_array: gen 25, waste 0, threat 4, essence cost %.0f (coal gen %.0f)" % [essence_cost(d, "solar_array"), essence_cost(d, "coal_generator")])
	print("\n== Smelter line, per day: N smelters x generators (1 smelter = 40 power) ==")
	print("%-2s %-14s %6s %6s %5s %7s %7s %5s %8s %8s %5s %6s  %s" % ["N", "mix", "demand", "supply", "f", "thr_off", "thr_on", "ratio", "waste_off", "waste_on", "w_x", "threat", "fuel/day, spent/day"])
	var mixes: Array = [
		{"coal_generator": 1}, {"coal_generator": 2}, {"coal_generator": 4},
		{"nitrogen_turbine": 1}, {"nuclear_reactor": 1},
		{"solar_array": 1}, {"solar_array": 4}, {"coal_generator": 1, "solar_array": 2},
	]
	for n in [1, 2, 3, 4, 6, 8]:
		for mix: Dictionary in mixes:
			var r := line(d, n, mix)
			var label := ""
			for k: String in mix:
				label += "%s%d " % [k.substr(0, 4), mix[k]]
			print("%-2d %-14s %6.0f %6.0f %5.2f %7.1f %7.1f %5.2f %8.1f %8.1f %5.2f %6.0f  %s %.1f" % [n, label.strip_edges(), r["demand"], r["supply"], r["factor"],
					r["thr_unpowered"], r["thr_powered"], r["ratio"], r["waste_unpowered"], r["waste_powered"],
					float(r["waste_powered"]) / maxf(0.001, float(r["waste_unpowered"])), r["threat"], str(r["fuel"]), r["spent"]])
	print("\n== Gates ==")
	var g3 := line(d, 3, {"coal_generator": 1})
	print("3-smelter line on 1 coal: ratio %.2f (want 1.6..2.0), waste x%.2f (want >= 1.3)" % [g3["ratio"], float(g3["waste_powered"]) / float(g3["waste_unpowered"])])
	print("1 solar covers %.1f%% of a smelter's demand at 0 waste; 4 solars cost %.0f vs 1 coal gen %.0f (want >= 2x)" % [100.0 * 25.0 / 40.0, 4.0 * essence_cost(d, "solar_array"), essence_cost(d, "coal_generator")])
	# region K5
	var d5 := d.duplicate_defs()
	d5.balance["k5_enabled"] = true
	print("\n== K5 (k5_enabled) solar %.0f = %.0f%% of a smelter ==" % [gen_of(d5, "solar_array"), 100.0 * gen_of(d5, "solar_array") / 40.0])
	for n in [1, 2, 3, 4]:
		var k := solars_for(d5, n)
		var r5 := line(d5, n, {"solar_array": k})
		print("%d smelters: %d solars -> factor %.2f, cost %.0f essence" % [n, k, r5["factor"], k * essence_cost(d5, "solar_array")])
	# endregion
	bus.free()
	quit()
