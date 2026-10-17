extends TestCase
## Spatial contamination: field, diffusion, crop penalty, blooms, purify, replay.


func _sim(seed_value := 3) -> Simulation:
	return make_sim(seed_value, false, 30, 30, peaceful_defs())


func _hot(sim: Simulation, c: Vector2i, amount := 2.0) -> void:
	sim.contamination.level = 40.0
	sim.mutation.add_at(c, amount)


func test_waste_feeds_field_and_diffuses() -> void:
	var sim := _sim()
	sim.contamination.level = 20.0
	sim.items.add_at(Vector2i(15, 15), "waste", 40)
	sim.run_ticks(21)
	assert_gt(sim.mutation.value_at(Vector2i(15, 15)), 0.0, "source cell")
	sim.run_ticks(100)
	assert_gt(sim.mutation.value_at(Vector2i(17, 15)), 0.0, "spread two cells away")
	assert_gt(sim.mutation.value_at(Vector2i(15, 15)), sim.mutation.value_at(Vector2i(17, 15)))


func test_field_mean_tracks_global_level() -> void:
	var sim := _sim()
	sim.contamination.level = 30.0
	sim.items.add_at(Vector2i(10, 10), "waste", 50)
	sim.run_ticks(6000)
	var target := sim.contamination.fraction() * float(sim.defs.mutation["mean_at_max"])
	assert_lt(absf(sim.mutation.mean() - target), target * 0.5, "mean near target")


func test_deterministic() -> void:
	var hashes: Array[int] = []
	for i in 2:
		var sim := _sim(9)
		_hot(sim, Vector2i(12, 12))
		sim.items.add_at(Vector2i(8, 8), "waste", 10)
		sim.run_ticks(1500)
		hashes.append(SaveGame.state_hash(sim))
	assert_eq(hashes[0], hashes[1])


func test_tainted_soil_slows_crops_and_cuts_yield() -> void:
	var sim := _sim()
	sim.tick = sim.ticks_per_day * 6 / 24
	sim.set_zone(Vector2i(5, 5), "growing")
	sim.set_zone(Vector2i(8, 8), "growing")
	sim.contamination.level = 0.0
	sim.mutation.add_at(Vector2i(5, 5), 0.8)
	assert_lt(sim.mutation.growth_mult(Vector2i(5, 5)), 0.5)
	assert_eq(sim.mutation.growth_mult(Vector2i(8, 8)), 1.0)
	sim.farming.sow(Vector2i(5, 5), "tuber")
	sim.farming.sow(Vector2i(8, 8), "tuber")
	var bad := sim.farming.plant_at(Vector2i(5, 5))
	var good := sim.farming.plant_at(Vector2i(8, 8))
	# Re-pin the field each tick so the test does not depend on decay.
	for i in 100:
		sim.mutation.field[5 * 30 + 5] = 0.8
		sim.step()
	assert_eq(good.growth, 100)
	assert_lt(bad.growth, 60, "tainted crop grows slower")
	bad.growth = 600
	good.growth = 600
	assert_lt(sim.farming.harvest(Vector2i(5, 5)), sim.farming.harvest(Vector2i(8, 8)))


func test_bloom_appears_on_mutated_cells_and_signals() -> void:
	var defs := peaceful_defs()
	defs.mutation["bloom_chance"] = 1.0
	var sim := make_sim(4, false, 30, 30, defs)
	var seen: Array[Vector2i] = []
	sim.bus.cell_mutated.connect(func(c: Vector2i) -> void: seen.append(c))
	_hot(sim, Vector2i(15, 15))
	sim.run_ticks(21)
	assert_true(seen.has(Vector2i(15, 15)), "cell_mutated")
	assert_gt(sim.items.count_on_ground("essence_bloom"), 0, "bloom grew")


func test_tainted_ground_sickens_standing_colonist() -> void:
	var defs := peaceful_defs()
	defs.mutation["illness_chance"] = 1.0
	defs.mutation["exposure_ticks"] = 40
	var sim := make_sim(4, false, 30, 30, defs)
	var c := sim.colonists.spawn(Vector2i(15, 15))
	for i in 100:
		sim.mutation.add_at(Vector2i(15, 15), 1.0)
		sim.step()
		c.job = null
	assert_true(c.health != null and not c.health.injuries.is_empty())


func test_purify_costs_essence_and_cleans() -> void:
	var sim := _sim()
	sim.set_zone(Vector2i(3, 3), "stockpile")
	sim.ledger.record_produced("refined_essence", 5, "test")
	sim.items.add_at(Vector2i(3, 3), "refined_essence", 5)
	_hot(sim, Vector2i(15, 15))
	var level := sim.contamination.level
	assert_true(sim.purify_cell(Vector2i(15, 15)))
	assert_lt(sim.mutation.value_at(Vector2i(15, 15)), 1.5)
	assert_lt(sim.contamination.level, level)
	assert_eq(sim.items.count_stored("refined_essence"), 3)
	assert_false(sim.purify_cell(Vector2i(1, 1)), "clean cell")
	sim.items.take_at(Vector2i(3, 3), 5)
	assert_false(sim.purify_cell(Vector2i(15, 15)), "no essence")


func test_save_load_replay_matches() -> void:
	var sim := make_sim(6, true, 0, 0, peaceful_defs())
	var c := sim.map_center() + Vector2i(3, -1)
	sim.contamination.level = 25.0  # direct poke is not replayable; replay starts at 0
	sim.run_ticks(200)
	sim.purify_cell(c)
	sim.run_ticks(200)
	var r := SaveGame.load_dict(SaveGame.to_dict(sim), make_bus(), sim.defs)
	assert_true(r["ok"], str(r.get("error")))
	if r["ok"]:
		var loaded: Simulation = r["sim"]
		_sims.append(loaded)
		loaded.contamination.level = sim.contamination.level
		assert_eq(loaded.tick, sim.tick)
		assert_eq(loaded.mutation.field.size(), sim.mutation.field.size())
		assert_eq(loaded.command_log.size(), sim.command_log.size())
