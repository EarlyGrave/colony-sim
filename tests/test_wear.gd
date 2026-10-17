extends TestCase
## E7: machines wear out and break; colonists repair them as a job.


func _refinery_sim(colonists := 1) -> Simulation:
	var sim := make_sim(21, false, 20, 20, peaceful_defs())
	for i in colonists:
		sim.colonists.spawn(Vector2i(2 + i, 2))
	for y in 2:
		for x in 3:
			sim.set_zone(Vector2i(2 + x, 10 + y), "stockpile")
	for y in 3:
		for x in 3:
			sim.set_zone(Vector2i(14 + x, 10 + y), "waste_dump")
	sim.ledger.record_produced("essence_ore", 150, "test")
	sim.items.drop(Vector2i(2, 10), "essence_ore", 150)
	sim.buildings.place("refinery", Vector2i(9, 5), false)
	return sim


func test_refinery_wears_with_each_batch() -> void:
	var sim := _refinery_sim()
	var b: Building = sim.buildings.list[0]
	sim.run_ticks(400)
	assert_gt(sim.buildings.refined_batches, 0)
	assert_lt(b.condition, 100.0, "condition should drop after batches")


func test_broken_refinery_stops_and_resumes_after_repair() -> void:
	var sim := _refinery_sim()
	var b: Building = sim.buildings.list[0]
	b.add_input("essence_ore", 20)
	sim.buildings.wear(b, 100.0)
	assert_true(b.broken)
	assert_false(b.can_run_recipe(), "broken machine cannot run")
	assert_false(sim.buildings.work(b), "work on a broken machine does nothing")
	var batches := sim.buildings.refined_batches
	var repaired := [0]
	sim.bus.building_repaired.connect(func(_id: int) -> void: repaired[0] += 1)
	# The colonist should prefer repairing over everything else.
	sim.step()
	assert_true(sim.colonists.list[0].job is RepairJob, "repair should be picked first")
	sim.run_ticks(60)
	assert_eq(sim.buildings.refined_batches, batches, "no production while broken")
	sim.run_ticks(1000)
	assert_gt(repaired[0], 0, "colonist should have repaired it")
	assert_false(b.broken)
	assert_gt(sim.buildings.refined_batches, batches, "production resumes after repair")


func test_unrepaired_refinery_stays_broken() -> void:
	var sim := _refinery_sim(0)
	var b: Building = sim.buildings.list[0]
	b.add_input("essence_ore", 20)
	sim.buildings.wear(b, 100.0)
	var c := sim.colonists.spawn(Vector2i(2, 2))
	# Someone stands at the machine but nobody is allowed to repair it.
	sim.jobs.reserved["rep:%d" % b.id] = -99
	sim.run_ticks(800)
	assert_true(b.broken)
	assert_eq(sim.buildings.refined_batches, 0)
	assert_true(c.alive)


func test_machines_break_under_heavy_use() -> void:
	var sim := _refinery_sim(1)
	var broke := [0]
	sim.bus.building_broken.connect(func(_id: int) -> void: broke[0] += 1)
	# Nobody repairs proactively: the threshold is 0 here, so it runs to failure.
	sim.defs.balance["repair"]["threshold"] = 0.0
	sim.run_ticks(3000)
	assert_gt(broke[0], 0, "refinery should eventually break (wear %s per batch)" % str(sim.defs.buildings["refinery"]["wear_per_batch"]))


func test_broken_turret_does_not_fire() -> void:
	var sim := make_sim(22, false, 20, 20, peaceful_defs())
	var t := sim.buildings.place("turret", Vector2i(10, 10), false)
	sim.buildings.wear(t, 100.0)
	var e := sim.threats._spawn("crawler", Vector2i(13, 10))
	e.move_ticks = 1000000
	sim.run_ticks(100)
	assert_true(sim.threats.enemies.has(e), "broken turret must not shoot")
	sim.buildings.repair(t)
	sim.run_ticks(100)
	assert_false(sim.threats.enemies.has(e), "repaired turret shoots again")
