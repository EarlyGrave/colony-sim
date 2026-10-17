extends TestCase
## Rule "refine_cap": no new refinery batch starts at/above the contamination cap.


func _setup(rule_on: bool) -> Simulation:
	var defs := peaceful_defs()
	var sim := make_sim(7, false, 20, 20, defs)
	sim.colonists.spawn(Vector2i(2, 2))
	for y in 2:
		for x in 3:
			sim.set_zone(Vector2i(2 + x, 10 + y), "stockpile")
			sim.set_zone(Vector2i(14 + x, 10 + y), "waste_dump")
	sim.ledger.record_produced("essence_ore", 40, "test")
	sim.items.drop(Vector2i(2, 10), "essence_ore", 40)
	sim.buildings.place("refinery", Vector2i(9, 5), false)
	sim.set_rule("refine_cap", rule_on)
	return sim


func _cap_level(sim: Simulation) -> float:
	var limit := float(sim.defs.rules["refine_cap"]["max_contamination_percent"])
	return sim.contamination.level * 0.0 + limit / 100.0 * _full(sim)


func _full(sim: Simulation) -> float:
	# level at which fraction() == 1.0
	sim.contamination.level = 1.0
	var f := sim.contamination.fraction()
	sim.contamination.level = 0.0
	return 1.0 / f


func _over(sim: Simulation) -> void:
	sim.contamination.level = _cap_level(sim) * 1.05


func test_rule_defaults_off_with_param() -> void:
	var sim := make_sim(1, false, 10, 10, peaceful_defs())
	assert_false(sim.is_rule_on("refine_cap"))
	assert_eq(int(sim.defs.rules["refine_cap"]["max_contamination_percent"]), 50)


func test_rule_off_keeps_refining_past_cap() -> void:
	var sim := _setup(false)
	_over(sim)
	sim.run_ticks(600)
	assert_gt(sim.buildings.refined_batches, 0)


func test_rule_on_blocks_new_batches_at_cap() -> void:
	var sim := _setup(true)
	_over(sim)
	assert_true(sim.buildings.refining_capped())
	sim.run_ticks(600)
	assert_eq(sim.buildings.refined_batches, 0)


func test_rule_on_resumes_when_level_drops() -> void:
	var sim := _setup(true)
	_over(sim)
	sim.run_ticks(100)
	assert_eq(sim.buildings.refined_batches, 0)
	sim.contamination.level = 0.0
	sim.run_ticks(600)
	assert_gt(sim.buildings.refined_batches, 0)


func test_batch_in_progress_is_finished() -> void:
	var sim := _setup(true)
	var b: Building
	for x in sim.buildings.list:
		if x.def_id == "refinery":
			b = x
	var n := 0
	while b.progress == 0 and n < 2000:
		sim.step()
		n += 1
	assert_gt(b.progress, 0, "batch should have started")
	_over(sim)
	sim.run_ticks(600)
	assert_eq(sim.buildings.refined_batches, 1, "in-progress batch finishes, no new one")
