extends TestCase
## T4: AI chip operator (install/remove, speed, threat, waste, upkeep, calibration, tech gate).

const TECH := "hand_tools"


func _defs() -> Defs:
	var d := peaceful_defs()
	d.research[TECH]["cost"]["bench_ticks"] = 100000  # never finishes during a test
	d.skills["xp_per_work_tick"] = 0.0
	d.events.erase("lightning")  # machine breakdowns are not under test
	return d


func _stock(sim: Simulation, item: String, n: int) -> void:
	for x in 4:
		sim.set_zone(Vector2i(2 + x, 2), "stockpile")
	sim.ledger.record_produced(item, n, "test")
	sim.items.drop(Vector2i(2, 2), item, n)


func _chips(sim: Simulation) -> int:
	return sim.items.count_stored("ai_chip") + sim.items.count_on_ground("ai_chip")


func _bench_sim(chips := 1, essence := 20) -> Array:
	var sim := make_sim(3, false, 24, 20, _defs())
	sim.research.done.erase(TECH)
	sim.queue_research(TECH, true)
	var b := sim.buildings.place("research_bench", Vector2i(10, 8), false)
	_stock(sim, "ai_chip", chips)
	if essence > 0:
		_stock(sim, "refined_essence", essence)
	return [sim, b]


func test_install_remove_and_ledger() -> void:
	var r := _bench_sim()
	var sim: Simulation = r[0]
	var b: Building = r[1]
	assert_true(sim.install_chip(b.id), "installed")
	assert_false(sim.install_chip(b.id), "one chip per building")
	assert_eq(sim.items.count_stored("ai_chip"), 0)
	assert_true(sim.remove_chip(b.id), "removed")
	assert_eq(_chips(sim), 1, "chip returns to the ground")
	assert_false(sim.remove_chip(b.id))
	assert_eq(sim.ledger.balance_of("ai_chip"), 1)
	var kinds := sim.command_log.map(func(e: Array) -> String: return str(e[1]))
	assert_true("install_chip" in kinds and "remove_chip" in kinds, "commands recorded")


func test_no_chip_on_miner_or_without_item() -> void:
	var sim := make_sim(1, false, 24, 24, _defs())
	var c := Vector2i(8, 8)
	sim.map.set_tile(c, MapGrid.Tile.DEPOSIT, 0)
	sim.map.node_res[sim.map.idx(c)] = NodeData.res_index("copper_ore")
	sim.map.node_purity[sim.map.idx(c)] = 2
	var m := sim.buildings.place("miner", c, false)
	_stock(sim, "ai_chip", 1)
	assert_true(m != null)
	assert_false(sim.install_chip(m.id), "miners take no chip")
	assert_eq(m.chip_slots(), 0)
	var s := sim.buildings.place("smelter", Vector2i(14, 14), false)
	assert_true(sim.install_chip(s.id), "smelter takes one")
	var s2 := sim.buildings.place("smelter", Vector2i(18, 14), false)
	assert_false(sim.install_chip(s2.id), "no chip left in storage")


func test_tech_gate() -> void:
	var d := _defs()
	var sim := make_sim(3, false, 24, 20, d)
	sim.research.gating = true
	var b := sim.buildings.place("research_bench", Vector2i(10, 8), false)
	_stock(sim, "ai_chip", 1)
	assert_false(sim.install_chip(b.id), "locked before ai_chips")
	assert_false(sim.chips.recipe_ok("make_ai_chip"))
	sim.research.done.append("ai_chips")
	assert_true(sim.install_chip(b.id), "unlocked after ai_chips")
	assert_true(sim.chips.recipe_ok("make_ai_chip"))
	assert_true(sim.defs.research.has("ai_chips") and sim.defs.recipes.has("make_ai_chip"))


func test_chip_bench_speed_without_colonists() -> void:
	var r := _bench_sim()
	var sim: Simulation = r[0]
	assert_true(sim.install_chip(r[1].id))
	sim.run_ticks(500)
	assert_eq(sim.colonists.list.size(), 0)
	assert_near(sim.research.progress_of(TECH), 400.0, 8.0, "0.8 x bench_rate x 500 ticks")


func test_chip_vs_colonist_ratio() -> void:
	var a := _bench_sim(0, 0)
	var sa: Simulation = a[0]
	var c := sa.colonists.spawn(Vector2i(9, 8))
	c.skills.levels["crafting"] = 5  # 0.5 + 5/10 = 1.0
	var rate := ResearchOperator.speed(sa, a[1], c)
	assert_near(rate, 1.0, 0.001)
	var b := _bench_sim()
	assert_true(b[0].install_chip(b[1].id))
	assert_near(ResearchOperator.speed(b[0], b[1], null) / rate, 0.8, 0.02)


func test_threat_multiplier_only_while_working() -> void:
	var r := _bench_sim()
	var sim: Simulation = r[0]
	var b: Building = r[1]
	assert_near(sim.chips.threat_mult(b), 1.0, 0.0001, "no chip")
	sim.install_chip(b.id)
	assert_near(sim.chips.threat_mult(b), 2.0, 0.0001, "active tech, chip working")
	assert_near(sim.chips.colony_threat_mult(), 2.0, 0.0001)
	sim.queue_research(TECH, false)
	assert_near(sim.chips.threat_mult(b), 1.0, 0.0001, "idle bench")


func test_waste_multiplier() -> void:
	var sim := make_sim(7, false, 24, 24, _defs())
	var base := make_sim(7, false, 24, 24, _defs())
	var s := sim.buildings.place("smelter", Vector2i(8, 8), false)
	var s0 := base.buildings.place("smelter", Vector2i(8, 8), false)
	_stock(sim, "ai_chip", 1)
	assert_true(sim.install_chip(s.id))
	_stock(sim, "refined_essence", 10)
	for i in 15:
		s.add_input("essence_ore", 10)
		s0.add_input("essence_ore", 10)
		sim.run_ticks(102)  # 100 work ticks at chip speed 1.0
		base.run_ticks(170)  # unoperated runs at 0.6
		s.output.clear()
		s0.output.clear()
		sim.buildings.repair(s)  # wear is not under test
		base.buildings.repair(s0)
	var w := float(sim.ledger.produced.get("waste", 0))
	var w0 := float(base.ledger.produced.get("waste", 0))
	assert_true(w0 > 0.0)
	assert_near(w / w0, 1.3, 0.05, "waste x1.3 (%f / %f)" % [w, w0])


func test_processor_speed_chip_beats_unoperated() -> void:
	# decided without owner (R3X): unoperated processors run at 0.6, a chip restores 1.0
	var sim := make_sim(7, false, 24, 24, _defs())
	var s := sim.buildings.place("smelter", Vector2i(8, 8), false)
	_stock(sim, "ai_chip", 1)
	_stock(sim, "refined_essence", 5)
	var plain := make_sim(7, false, 24, 24, _defs())
	var p := plain.buildings.place("smelter", Vector2i(8, 8), false)
	sim.install_chip(s.id)
	s.add_input("copper_ore", 60)
	p.add_input("copper_ore", 60)
	sim.run_ticks(640)
	plain.run_ticks(640)
	assert_near(float(sim.buildings.refined_batches), 8.0, 1.0, "chip: 640 * 1.0 / 80")
	assert_near(float(plain.buildings.refined_batches), 4.8, 1.0, "unoperated: 640 * 0.6 / 80")


func test_upkeep_once_per_day_and_starvation() -> void:
	var r := _bench_sim(1, 5)
	var sim: Simulation = r[0]
	sim.install_chip(r[1].id)
	sim.run_ticks(sim.ticks_per_day * 2 + 10)
	assert_eq(sim.ledger.get_count("chip_upkeep:refined_essence"), 2, "paid at each day start, exactly once")
	assert_true(sim.chips.working(r[1]))
	sim.items.consume_stored("refined_essence", sim.items.count_stored("refined_essence"), Vector2i(2, 2))
	sim.run_ticks(sim.ticks_per_day)
	assert_true(sim.chips.is_starved(r[1]), "no essence: chip stops")
	assert_eq(sim.chips.bench_speed(r[1]), 0.0)


func test_calibration_stops_then_colonist_resumes() -> void:
	var r := _bench_sim(1, 30)
	var sim: Simulation = r[0]
	var b: Building = r[1]
	sim.install_chip(b.id)
	var due := sim.ticks_per_day * 3
	sim.run_ticks(due - 5)
	assert_true(sim.chips.working(b), "still calibrated before day 3")
	var p1 := sim.research.progress_of(TECH)
	sim.run_ticks(60)
	assert_false(sim.chips.working(b), "uncalibrated: stopped")
	assert_true(sim.chips.needs_calibration(b))
	var p2 := sim.research.progress_of(TECH)
	sim.run_ticks(100)
	assert_eq(sim.research.progress_of(TECH), p2, "no progress while stopped")
	assert_true(p2 > p1)
	var c := sim.colonists.spawn(Vector2i(9, 8))
	c.skills.levels["operating"] = 2
	var t0 := sim.tick
	var n := 0
	while n < 400 and not sim.chips.working(b):
		sim.step()
		n += 1
	assert_true(sim.chips.working(b), "calibrated by a colonist")
	var need := int(sim.defs.chips["calibrate_ticks"])
	assert_true(sim.tick - t0 >= need and sim.tick - t0 <= need + 40, "took %d ticks (job %d)" % [sim.tick - t0, need])


func test_skill_gate_for_calibration() -> void:
	var r := _bench_sim(1, 30)
	var sim: Simulation = r[0]
	sim.install_chip(r[1].id)
	sim.run_ticks(sim.ticks_per_day * 3 + 5)
	var c := sim.colonists.spawn(Vector2i(9, 8))
	c.skills.levels["operating"] = 0
	sim.run_ticks(300)
	assert_true(sim.chips.needs_calibration(r[1]), "unskilled colonist does not calibrate")


func test_broken_or_destroyed_building_drops_chip() -> void:
	var r := _bench_sim()
	var sim: Simulation = r[0]
	var b: Building = r[1]
	sim.install_chip(b.id)
	sim.buildings.destroy(b)
	assert_false(sim.chips.has_chip(b))
	assert_eq(_chips(sim), 1, "chip dropped")
	var r2 := _bench_sim()
	var s2: Simulation = r2[0]
	s2.install_chip(r2[1].id)
	r2[1].broken = true
	s2.run_ticks(2)
	assert_false(s2.chips.has_chip(r2[1]))
	assert_eq(_chips(s2), 1)


func test_description_line() -> void:
	var r := _bench_sim()
	var sim: Simulation = r[0]
	assert_eq(sim.chips.describe(r[1]), "")
	sim.install_chip(r[1].id)
	assert_true(sim.chips.describe(r[1]).begins_with("AI chip: running"))


func test_deterministic_replay() -> void:
	var out: Array = []
	for k in 2:
		var r := _bench_sim(1, 30)
		var sim: Simulation = r[0]
		sim.install_chip(r[1].id)
		var c := sim.colonists.spawn(Vector2i(9, 8))
		c.skills.levels["operating"] = 2
		sim.run_ticks(sim.ticks_per_day * 4)
		out.append([sim.research.progress_of(TECH), sim.ledger.by_source.duplicate(), sim.chips.slots.duplicate(true)])
	assert_eq(out[0], out[1], "same inputs, same state")
