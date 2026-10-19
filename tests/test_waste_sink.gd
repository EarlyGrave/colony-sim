extends TestCase
## D2: early waste sink behind balance flag `waste_sink_early`, throughput capped.


func _setup(on: bool) -> Simulation:
	var sim := make_sim(1, false, 24, 24, peaceful_defs())
	sim.defs.balance["waste_sink_early"] = on
	return sim


func test_flag_off_blocks_placement() -> void:
	var sim := _setup(false)
	assert_true(sim.buildings.placement_error("waste_compactor", Vector2i(5, 5), false) != "")


func test_flag_on_consumes_capped() -> void:
	var sim := _setup(true)
	sim.research.done.append("decoys_1")
	var b := sim.buildings.place("waste_compactor", Vector2i(5, 5), false)
	assert_true(b != null)
	sim.set_zone(Vector2i(8, 8), "waste_dump")
	sim.items.drop(Vector2i(8, 8), "waste", 10)
	var before: int = sim.items.count_stored("waste")
	for i in 600:
		sim.step()
	var eaten := before - sim.items.count_stored("waste")
	assert_true(eaten >= 1, "sink works")
	assert_true(eaten <= 6, "capped at 6/day, ate %d" % eaten)


func test_flag_off_eats_nothing() -> void:
	var sim := _setup(true)
	sim.research.done.append("decoys_1")
	var b := sim.buildings.place("waste_compactor", Vector2i(5, 5), false)
	assert_true(b != null)
	sim.defs.balance["waste_sink_early"] = false
	sim.set_zone(Vector2i(8, 8), "waste_dump")
	sim.items.drop(Vector2i(8, 8), "waste", 5)
	for i in 300:
		sim.step()
	assert_eq(int(sim.ledger.consumed.get("waste", 0)), 0)
