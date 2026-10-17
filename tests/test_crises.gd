extends TestCase
## Contamination crises: thresholds fire once, options apply, timeout default.


func _sim(seed_value := 3, defs: Defs = null) -> Simulation:
	return make_sim(seed_value, true, 24, 24, defs if defs != null else peaceful_defs())


func _set_frac(sim: Simulation, f: float) -> void:
	sim.contamination.level = f * float(sim.defs.balance["contamination"]["max"])


func _early_defs() -> Defs:
	var d := peaceful_defs()
	d.crises["crises"]["siege"]["threshold"] = 0.0
	return d


func test_each_threshold_fires_once() -> void:
	var sim := _sim()
	var started: Array[String] = []
	sim.bus.crisis_started.connect(func(id: String, _t: String) -> void: started.append(id))
	sim.run_ticks(5)
	assert_true(started.is_empty())
	_set_frac(sim, 0.55)
	sim.run_ticks(3)
	assert_eq(started, ["siege"] as Array[String])
	_set_frac(sim, 0.8)
	sim.run_ticks(3)
	_set_frac(sim, 0.95)
	sim.run_ticks(3)
	assert_eq(started, ["siege", "dead_lands", "last_stand"] as Array[String])
	_set_frac(sim, 0.3)
	sim.run_ticks(3)
	_set_frac(sim, 0.95)
	sim.run_ticks(3)
	assert_eq(started.size(), 3, "never again")


func test_siege_endure_boosts_raids() -> void:
	var sim := _sim()
	var base := sim.threats.raid_points(3)
	_set_frac(sim, 0.55)
	sim.run_ticks(2)
	assert_true(sim.resolve_crisis("siege", "endure"))
	assert_gt(sim.threats.raid_points(3), base * 1.3)
	assert_false(sim.resolve_crisis("siege", "endure"), "already resolved")
	sim.run_ticks(5 * sim.ticks_per_day)
	assert_eq(sim.crises.mult("raid_points_mult"), 1.0, "expired")


func test_siege_appease_costs_essence() -> void:
	var sim := _sim()
	_set_frac(sim, 0.55)
	sim.run_ticks(2)
	assert_false(sim.resolve_crisis("siege", "appease"), "cannot afford")
	assert_true(sim.crises.is_pending("siege"))
	var spot := sim.map_center() + Vector2i(5, 1)
	sim.items.drop(spot, "refined_essence", 12)
	var before := sim.items.count_stored("refined_essence")
	var level := sim.contamination.level
	assert_true(sim.resolve_crisis("siege", "appease"))
	assert_eq(sim.items.count_stored("refined_essence"), before - 10)
	assert_lt(sim.contamination.level, level - 5.0)


func test_dead_lands_endure_poisons_edges() -> void:
	var sim := _sim()
	_set_frac(sim, 0.8)
	sim.run_ticks(2)
	assert_true(sim.resolve_crisis("dead_lands", "endure"))
	var c: Colonist = sim.colonists.list[0]
	c.cell = Vector2i(1, 1)
	c.idle_until = sim.tick + 1000000  # keep them on the toxic edge (no idle work)
	assert_true(sim.crises.toxic_cell(c.cell))
	assert_false(sim.crises.toxic_cell(sim.map_center()))
	sim.run_ticks(sim.defs.crises["settings"]["toxic_interval_ticks"])
	var sick := false
	for i in c.health.injuries:
		sick = sick or i.illness_id == "toxic_fallout"
	assert_true(sick, "colonist on toxic edge falls ill")


func test_dead_lands_evacuate_loses_stock() -> void:
	var sim := _sim()
	_set_frac(sim, 0.8)
	sim.run_ticks(2)
	var before := sim.items.count_stored("essence_ore") + sim.items.count_stored("raw_food") * 0
	assert_true(sim.resolve_crisis("dead_lands", "evacuate"))
	assert_false(sim.crises.toxic_cell(Vector2i(0, 0)))
	assert_true(sim.items.count_stored("essence_ore") <= before)


func test_last_stand_halt_locks_refining() -> void:
	var sim := _sim()
	_set_frac(sim, 0.95)
	sim.run_ticks(2)
	assert_true(sim.resolve_crisis("last_stand", "halt"))
	assert_true(sim.crises.flag("refine_lock"))
	var scen := preload("res://tests/scenario.gd")
	var spot := scen.find_spot(sim, "refinery", sim.map_center() + Vector2i(4, 0), 0)
	var b := sim.place_instant("refinery", spot)
	if b != null and b.recipe_id == "refine_essence":
		assert_false(sim.buildings.may_operate(b), "locked")
	sim.run_ticks(4 * sim.ticks_per_day)
	assert_false(sim.crises.flag("refine_lock"), "lock ends")


func test_last_stand_overdrive_mods() -> void:
	var sim := _sim()
	_set_frac(sim, 0.95)
	sim.run_ticks(2)
	assert_true(sim.resolve_crisis("last_stand", "overdrive"))
	assert_eq(sim.crises.mult("refine_output_mult"), 2.0)
	assert_eq(sim.crises.mult("refine_contam_mult"), 3.0)
	var lvl := sim.contamination.level
	sim.bus.batch_refined.emit(0, "refine_essence")
	assert_gt(sim.contamination.level - lvl, 3.0 * float(sim.defs.balance["contamination"]["per_batch"]) * 0.99)


func test_timeout_applies_default() -> void:
	var sim := _sim()
	var res: Array = []
	sim.bus.crisis_resolved.connect(func(id: String, o: String, t: bool) -> void: res.append([id, o, t]))
	_set_frac(sim, 0.55)
	sim.run_ticks(2)
	sim.run_ticks(int(sim.defs.crises["crises"]["siege"]["timeout_ticks"]) + 5)
	assert_eq(res.size(), 1)
	assert_eq(res[0], ["siege", "endure", true])
	assert_true(sim.crises.pending.is_empty())
	assert_gt(sim.crises.mult("raid_points_mult"), 1.0)


func test_unknown_option_rejected() -> void:
	var sim := _sim()
	_set_frac(sim, 0.55)
	sim.run_ticks(2)
	assert_false(sim.resolve_crisis("siege", "nope"))
	assert_false(sim.resolve_crisis("last_stand", "halt"), "not open")


func test_save_load_replay_and_determinism() -> void:
	var run := func(d: Defs) -> Simulation:
		var s := make_sim(21, true, 24, 24, d)
		s.run_ticks(20)
		s.resolve_crisis("siege", "endure")
		s.run_ticks(400)
		return s
	var a: Simulation = run.call(_early_defs())
	var b: Simulation = run.call(_early_defs())
	assert_eq(SaveGame.state_hash(a), SaveGame.state_hash(b), "deterministic")
	assert_gt(a.crises.mult("raid_points_mult"), 1.0)
	var res := SaveGame.load_json(SaveGame.to_json(a), make_bus(), _early_defs())
	assert_true(res["ok"], str(res["error"]))
	var c: Simulation = res["sim"]
	_sims.append(c)
	assert_eq(SaveGame.state_hash(c), SaveGame.state_hash(a))
	assert_eq(c.crises.fired, a.crises.fired)
	assert_eq(c.crises.mult("raid_points_mult"), a.crises.mult("raid_points_mult"))
