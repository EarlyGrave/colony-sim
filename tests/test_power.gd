extends TestCase
## L3: power grid (networks, brownout, fuel burn, waste, threat, meltdown, determinism, perf).
## Defs are injected here (frozen schema), so the test does not depend on L5's data files.

const W := 40


func _defs() -> Defs:
	var d := peaceful_defs()
	d.chips["unoperated_speed"] = 1.0
	d.skills["xp_per_work_tick"] = 0.0
	d.events.erase("lightning")
	d.items["coal"] = {"name": "Coal", "color": "#222222", "stack": 50, "value": 1.0}
	d.items["spent_fuel"] = {"name": "Spent fuel", "color": "#445544", "stack": 20, "value": 0.0}
	d.fuels = {"coal": {"burn_ticks": 200, "waste": 1.0, "spent_item": "spent_fuel", "spent_per_burn": 1}}
	d.buildings["smelter"]["power_use"] = 40.0
	d.buildings["smelter"]["wear_per_batch"] = 0.0
	d.buildings["t_pole"] = {"name": "Pole", "size": [1, 1], "color": "#888888", "max_hp": 30, "cost": {}, "build_work": 10, "buildable": true, "power_range": 6}
	d.buildings["t_burner"] = _gen("coal", 100.0)
	d.buildings["t_solar"] = {"name": "Solar", "size": [2, 2], "color": "#223366", "max_hp": 60, "cost": {}, "build_work": 10, "buildable": true, "power_gen": 25.0, "fuel": null}
	var reactor := _gen("coal", 300.0)
	reactor["wear_per_burn"] = 0.0
	reactor["meltdown"] = {"fuse_ticks": 50, "condition_below": 20.0, "radius": 4.0, "damage": 40.0, "contamination": 30.0}
	d.buildings["t_reactor"] = reactor
	return d


func _gen(item: String, gen: float) -> Dictionary:
	return {"name": "Gen", "size": [2, 2], "color": "#aa5522", "max_hp": 100, "cost": {}, "build_work": 10, "buildable": true,
		"power_gen": gen, "fuel": {"item": item, "burn_ticks": 200, "waste_per_burn": 1.0}, "input_capacity": 20, "output_capacity": 20, "threat": 15.0}


func _sim(defs: Defs = null) -> Simulation:
	return make_sim(3, false, W, W, defs if defs != null else _defs())


## Pole line at y=12 plus `n` smelters (one batch of iron ore kept stocked) and `gens` burners.
func _plant(sim: Simulation, n: int, gens: int) -> Dictionary:
	var out := {"smelters": [], "gens": []}
	sim.buildings.place("t_pole", Vector2i(8, 8), false)
	for i in n:
		out["smelters"].append(sim.buildings.place("smelter", Vector2i(10, 4 + i * 4), false))
	for i in gens:
		out["gens"].append(sim.buildings.place("t_burner", Vector2i(4, 4 + i * 4), false))
	return out


func _run(sim: Simulation, fed: Dictionary, ticks: int, fuel := true) -> void:
	for t in ticks:
		for s: Building in fed["smelters"]:
			s.input["iron_ore"] = 20
			s.output.clear()
		if fuel:
			for g: Building in fed["gens"]:
				g.input["coal"] = 20
		sim.run_ticks(1)


func test_enforcement_off_without_poles() -> void:
	var sim := _sim()
	var fed := _plant(sim, 1, 0)
	sim.buildings.deconstruct(Vector2i(8, 8))
	_run(sim, fed, 5)
	assert_false(sim.power.enabled, "no pole/generator -> off")
	assert_eq(sim.power.factor_for(fed["smelters"][0]), 1.0)
	assert_true(sim.power.state_parts().is_empty(), "nothing in the hash")


func test_network_merge_and_split() -> void:
	var sim := _sim()
	var p1 := sim.buildings.place("t_pole", Vector2i(2, 20), false)
	var p3 := sim.buildings.place("t_pole", Vector2i(14, 20), false)
	var s := sim.buildings.place("smelter", Vector2i(15, 21), false)
	sim.run_ticks(1)
	assert_eq(sim.power.nets.size(), 2, "12 apart: two nets")
	var p2 := sim.buildings.place("t_pole", Vector2i(8, 20), false)
	sim.run_ticks(1)
	assert_eq(sim.power.nets.size(), 1, "middle pole merges")
	assert_eq(sim.power.net_id_of(s), p1.id)
	var ver := sim.power.version
	sim.run_ticks(5)
	assert_eq(sim.power.version, ver, "no recompute without changes")
	assert_true(sim.buildings.deconstruct(p2.cell))
	sim.run_ticks(1)
	assert_eq(sim.power.nets.size(), 2, "split again")
	assert_eq(sim.power.net_id_of(s), p3.id)
	sim.buildings.deconstruct(p3.cell)
	sim.run_ticks(1)
	assert_eq(sim.power.factor_for(s), 0.5, "no pole in range -> 0.5 within one tick")


func test_brownout_math_and_throughput() -> void:
	var sim := _sim()
	var fed := _plant(sim, 3, 1)
	_run(sim, fed, 50)
	var net: Dictionary = sim.power.nets[0]
	assert_near(float(sim.power.net_info(net["id"])["demand"]), 120.0, 0.01)
	assert_near(float(sim.power.net_info(net["id"])["supply"]), 100.0, 0.01)
	assert_near(float(sim.power.net_info(net["id"])["factor"]), 0.833, 0.01)
	var base := sim.buildings.refined_batches
	_run(sim, fed, 3000)
	var slow := sim.buildings.refined_batches - base
	var full := _sim()
	var fed2 := _plant(full, 3, 2)
	_run(full, fed2, 50)
	assert_near(float(full.power.net_info(full.power.nets[0]["id"])["factor"]), 1.0, 0.001, "second burner -> 1.0")
	var base2 := full.buildings.refined_batches
	_run(full, fed2, 3000)
	var fast := full.buildings.refined_batches - base2
	assert_true(fast > 20, "batches ran: %d" % fast)
	assert_near(float(slow) / float(fast), 0.83, 0.05, "throughput ratio %d/%d" % [slow, fast])


func test_no_fuel_floor_never_zero() -> void:
	var sim := _sim()
	var fed := _plant(sim, 1, 1)
	_run(sim, fed, 600, false)
	assert_near(float(sim.power.net_info(sim.power.nets[0]["id"])["factor"]), 0.2, 0.001)
	assert_true(sim.buildings.refined_batches >= 1, "machines still finish batches")


func test_idle_grid_burns_nothing_and_full_load_waste() -> void:
	var sim := _sim()
	var fed := _plant(sim, 0, 1)
	var g: Building = fed["gens"][0]
	g.input["coal"] = 10
	sim.run_ticks(1000)
	assert_eq(int(g.input["coal"]), 10, "idle grid burns 0 fuel")
	assert_eq(sim.ledger.get_count("power_waste:waste"), 0)
	var fed2 := _plant(sim, 3, 0)
	fed["smelters"] = fed2["smelters"]
	_run(sim, fed, 1000)
	var waste := sim.ledger.get_count("power_waste:waste")
	assert_near(float(waste), 5.0, 0.5, "5 waste per 1000 ticks at full load")
	assert_eq(sim.ledger.get_count("power_fuel:coal"), waste, "one fuel unit per burn")
	assert_eq(sim.ledger.get_count("power_spent:spent_fuel"), waste, "spent fuel item")
	assert_true(sim.contamination.waste_units() > 0.0, "waste counts for contamination")


func test_generator_threat_drops_without_fuel() -> void:
	var sim := _sim()
	var fed := _plant(sim, 1, 1)
	var g: Building = fed["gens"][0]
	_run(sim, fed, 20)
	var running := sim.threats.model.building_value(g)
	assert_near(running, 15.0, 0.01, "burner 15 while running")
	_run(sim, fed, 400, false)
	g.input.clear()
	g.burn_left = 0
	sim.run_ticks(2)
	assert_near(sim.threats.model.building_value(g), 15.0 * 0.25, 0.01, "x0.25 without fuel")


func test_solar_is_clean_and_constant() -> void:
	var sim := _sim()
	var fed := _plant(sim, 1, 0)
	var sol := sim.buildings.place("t_solar", Vector2i(4, 4), false)
	_run(sim, fed, 100)
	assert_near(float(sim.power.net_info(sim.power.nets[0]["id"])["supply"]), 25.0, 0.01)
	assert_near(float(sim.power.net_info(sim.power.nets[0]["id"])["factor"]), 25.0 / 40.0, 0.01)
	assert_eq(sim.ledger.get_count("power_waste:waste"), 0)
	assert_true(sol != null)


func test_reactor_meltdown() -> void:
	var out: Array = []
	for run in 2:
		var sim := _sim()
		var fed := _plant(sim, 1, 0)
		var r := sim.buildings.place("t_reactor", Vector2i(4, 4), false)
		var neighbour := sim.buildings.place("smelter", Vector2i(4, 8), false)
		fed["gens"] = [r]
		_run(sim, fed, 30)
		assert_true(sim.buildings.get_by_id(r.id) != null, "stable while healthy")
		r.condition = 5.0  # overheating: worn down
		var before := sim.contamination.level
		_run(sim, fed, 120)
		assert_true(r.destroyed, "melted down")
		assert_true(sim.contamination.level >= before + 25.0, "contamination burst (40, minus b2 decay; smelters no longer block decay)")
		assert_true(neighbour.hp < neighbour.max_hp, "blast damage")
		out.append(SaveGame.state_hash(sim))
	assert_eq(out[0], out[1], "meltdown is deterministic")


func test_repair_cools_reactor() -> void:
	var sim := _sim()
	var fed := _plant(sim, 1, 0)
	var r := sim.buildings.place("t_reactor", Vector2i(4, 4), false)
	fed["gens"] = [r]
	r.condition = 5.0
	_run(sim, fed, 40)
	assert_true(r.heat > 0)
	r.condition = 100.0
	_run(sim, fed, 60)
	assert_eq(r.heat, 0, "cooled")
	assert_false(r.destroyed)


func test_determinism_and_save_replay() -> void:
	var hashes: Array = []
	for run in 2:
		var sim := _sim()
		var fed := _plant(sim, 2, 1)
		_run(sim, fed, 700)
		hashes.append(SaveGame.state_hash(sim))
		assert_true(sim.power.enabled)
	assert_eq(hashes[0], hashes[1], "same run, same hash")
	# replay: build the grid through recorded commands, save, load
	var sim := make_sim(7, true, 24, 24, _defs())
	var hq := sim.buildings.list[0]
	for c: Vector2i in [Vector2i(-4, 3), Vector2i(-6, 3), Vector2i(-8, 3), Vector2i(-8, 6)]:
		var p: Vector2i = hq.cell + c
		if sim.can_place_building("t_pole", p) == "":
			sim.place_building("t_pole", p)
	sim.run_ticks(600)
	var res := SaveGame.load_json(SaveGame.to_json(sim), make_bus(), _defs())
	assert_true(res["ok"], str(res["error"]))
	var sim2: Simulation = res["sim"]
	_sims.append(sim2)
	assert_eq(SaveGame.state_hash(sim2), SaveGame.state_hash(sim))
	assert_eq(sim2.power.enabled, sim.power.enabled)


func test_perf_recompute_and_tick() -> void:
	var sim := make_sim(3, false, 140, 140, _defs())
	var n := 0
	for y in 20:
		for x in 25:
			if n < 500:
				sim.buildings.place("t_pole", Vector2i(2 + x * 5, 2 + y * 6), false)
				n += 1
	for i in 200:
		sim.buildings.place("smelter", Vector2i(3 + (i % 25) * 5, 3 + (i / 25) * 6), false)
	sim.buildings.place("t_burner", Vector2i(100, 130), false)
	sim.power.tick()
	var rebuild_ms := 1e9
	for r in 7:  # best of 7: shared CI boxes are noisy
		var t0 := Time.get_ticks_usec()
		sim.buildings.version += 1
		sim.power.tick()
		rebuild_ms = minf(rebuild_ms, float(Time.get_ticks_usec() - t0) / 1000.0)
	var t1 := Time.get_ticks_usec()
	for i in 100:
		sim.power.tick()
	var tick_ms := float(Time.get_ticks_usec() - t1) / 1000.0 / 100.0
	print("        power: 500 poles + 200 consumers recompute %.2f ms, tick %.3f ms" % [rebuild_ms, tick_ms])
	assert_true(sim.power.nets.size() >= 1)
	if not perf_skip():
		assert_lt(rebuild_ms, 5.0 * 1.5, "recompute (budget 5 ms x perf_budget noise_margin)")
		assert_lt(tick_ms, 0.2 * 1.5, "per tick (budget 0.2 ms x noise_margin)")
