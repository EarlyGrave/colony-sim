extends TestCase
## Needs (food, rest), day clock, farming and cooking.


func _sim(seed_value := 1) -> Simulation:
	return make_sim(seed_value, false, 24, 24, peaceful_defs())


func _stockpile(sim: Simulation, origin: Vector2i, size: Vector2i, zone := "stockpile") -> void:
	for y in size.y:
		for x in size.x:
			sim.set_zone(origin + Vector2i(x, y), zone)


func _give(sim: Simulation, cell: Vector2i, item: String, n: int) -> void:
	sim.ledger.record_produced(item, n, "test")
	sim.items.add_at(cell, item, n)


func _conserved(sim: Simulation) -> void:
	for item in sim.defs.items:
		assert_eq(sim.items.count_world(item), sim.ledger.balance_of(item), "%s not conserved" % item)


func test_clock_hours_and_daylight() -> void:
	var sim := _sim()
	var tpd := sim.ticks_per_day
	assert_near(sim.clock.hour(0), float(sim.defs.time["start_hour"]), 0.001)
	assert_near(sim.clock.hour(tpd / 2), fposmod(float(sim.defs.time["start_hour"]) + 12.0, 24.0), 0.001)
	assert_eq(sim.clock.hour(tpd), sim.clock.hour(0), "a day wraps around")
	var noon := tpd * 6 / 24  # start 6:00 + 6h = noon
	assert_near(sim.clock.daylight(noon), 1.0, 0.001)
	assert_true(sim.clock.is_night(tpd * 16 / 24), "22:00 is night")
	assert_false(sim.clock.is_night(noon))
	var dawn := tpd * 0  # 6:00, inside the dawn ramp
	assert_true(sim.clock.daylight(dawn) > 0.0 and sim.clock.daylight(dawn) < 1.0)


func test_hungry_colonist_eats_stored_food() -> void:
	var sim := _sim()
	_stockpile(sim, Vector2i(10, 10), Vector2i(2, 2))
	_give(sim, Vector2i(10, 10), "raw_food", 5)
	var c := sim.colonists.spawn(Vector2i(3, 3))
	sim.needs.state_of(c).food = 0.25
	var ate := [0]
	sim.bus.colonist_ate.connect(func(_id: int, _item: String) -> void: ate[0] += 1)
	sim.run_ticks(200)
	assert_gt(ate[0], 0, "ate something")
	assert_gt(c.needs.food, 0.4, "food restored")
	assert_eq(sim.ledger.get_count("eaten:raw_food"), ate[0])
	assert_eq(sim.items.count_stored("raw_food"), 5 - ate[0])
	_conserved(sim)


func test_meal_is_preferred_and_feeds_more() -> void:
	var sim := _sim()
	_stockpile(sim, Vector2i(10, 10), Vector2i(2, 2))
	_give(sim, Vector2i(10, 10), "raw_food", 5)
	_give(sim, Vector2i(11, 11), "meal", 2)
	var c := sim.colonists.spawn(Vector2i(10, 12))
	sim.needs.state_of(c).food = 0.2
	sim.run_ticks(150)
	assert_eq(sim.ledger.get_count("eaten:meal"), 1, "meal beats nearer raw food")
	assert_gt(c.needs.food, 0.8)


func test_colonist_sleeps_in_bed_at_night() -> void:
	var sim := _sim()
	var bed := sim.buildings.place("bed", Vector2i(8, 8), false)
	var c := sim.colonists.spawn(Vector2i(3, 3))
	sim.tick = sim.ticks_per_day * 17 / 24  # 23:00
	assert_true(sim.clock.is_night())
	sim.needs.state_of(c).rest = 0.5
	sim.run_ticks(60)
	assert_true(c.job != null and c.job.type == "sleep", "went to sleep")
	sim.run_ticks(80)
	assert_eq(c.cell, bed.cell, "sleeps in the bed")
	var r1 := c.needs.rest
	sim.run_ticks(40)
	assert_near(c.needs.rest - r1, 40 * float(sim.defs.needs["rest"]["gain_bed"]), 0.001)
	var guard := 0
	while c.job != null and c.job.type == "sleep" and guard < 300:
		sim.step()
		guard += 1
	assert_true(c.job == null or c.job.type != "sleep", "woke up")
	assert_gt(c.needs.rest, 0.95)


func test_floor_sleep_is_slower_than_bed() -> void:
	var sim := _sim()
	var c := sim.colonists.spawn(Vector2i(3, 3))
	sim.tick = sim.ticks_per_day * 17 / 24
	sim.needs.state_of(c).rest = 0.3
	sim.run_ticks(5)
	assert_true(c.job != null and c.job.type == "sleep")
	assert_eq(c.cell, Vector2i(3, 3), "sleeps where it stands")
	var r1 := c.needs.rest
	sim.run_ticks(40)
	assert_near(c.needs.rest - r1, 40 * float(sim.defs.needs["rest"]["gain_floor"]), 0.001)
	assert_lt(float(sim.defs.needs["rest"]["gain_floor"]), float(sim.defs.needs["rest"]["gain_bed"]))


func test_day_schedule_eat_and_sleep() -> void:
	var sim := _sim()
	_stockpile(sim, Vector2i(10, 10), Vector2i(2, 2))
	_give(sim, Vector2i(10, 10), "raw_food", 40)
	sim.buildings.place("bed", Vector2i(6, 6), false)
	sim.buildings.place("bed", Vector2i(7, 6), false)
	var a := sim.colonists.spawn(Vector2i(3, 3))
	var b := sim.colonists.spawn(Vector2i(4, 3))
	var slept_at_night := [0]
	var slept_by_day := [0]
	var ate := [0]
	sim.bus.colonist_ate.connect(func(_id: int, _item: String) -> void: ate[0] += 1)
	for i in sim.ticks_per_day * 2:
		sim.step()
		for c in [a, b]:
			if c.job != null and c.job.type == "sleep":
				if sim.clock.is_night():
					slept_at_night[0] += 1
				else:
					slept_by_day[0] += 1
	assert_gt(slept_at_night[0], 100, "sleeps at night")
	assert_gt(slept_at_night[0], slept_by_day[0] * 2, "mostly at night")
	assert_gt(ate[0], 2, "eats during two days")
	assert_true(a.alive and b.alive)
	assert_gt(a.needs.food, 0.0)
	_conserved(sim)


func test_starvation_injures_then_kills() -> void:
	var sim := _sim()
	var c := sim.colonists.spawn(Vector2i(3, 3))
	sim.needs.state_of(c).food = 0.0
	var starving := [0]
	sim.bus.colonist_starving.connect(func(_id: int) -> void: starving[0] += 1)
	sim.run_ticks(200)
	assert_gt(starving[0], 0, "starvation signal")
	assert_true(c.health != null and not c.health.injuries.is_empty(), "has injuries")
	assert_eq(c.health.injuries[0].kind, "starvation")
	assert_true(c.alive, "not dead yet")
	sim.run_ticks(5000)
	assert_false(c.alive, "starved to death")


func test_eating_stops_starvation() -> void:
	var sim := _sim()
	_stockpile(sim, Vector2i(10, 10), Vector2i(2, 2))
	var c := sim.colonists.spawn(Vector2i(3, 3))
	sim.needs.state_of(c).food = 0.0
	sim.run_ticks(120)
	var injuries := c.health.injuries.size()
	assert_gt(injuries, 0)
	_give(sim, Vector2i(10, 10), "meal", 3)
	sim.run_ticks(150)
	assert_gt(c.needs.food, 0.5)
	var after_fed := c.health.injuries.size()
	sim.run_ticks(300)
	assert_true(c.health.injuries.size() <= after_fed, "no new starvation injuries once fed")


func test_farming_loop_produces_food() -> void:
	var sim := _sim()
	_stockpile(sim, Vector2i(10, 10), Vector2i(2, 2))
	_stockpile(sim, Vector2i(3, 12), Vector2i(2, 2), "growing")
	sim.colonists.spawn(Vector2i(5, 5))
	var sown := [0]
	var harvested := [0]
	sim.bus.plant_sown.connect(func(_c: Vector2i, _p: String) -> void: sown[0] += 1)
	sim.bus.plant_harvested.connect(func(_c: Vector2i, _i: String, n: int) -> void: harvested[0] += n)
	sim.run_ticks(sim.ticks_per_day * 3)
	assert_gt(sown[0], 3, "sowed the field (and resowed)")
	assert_gt(harvested[0], 0, "harvested")
	assert_eq(sim.ledger.get_count("farming:raw_food"), harvested[0])
	assert_gt(sim.items.count_stored("raw_food") + sim.ledger.get_count("eaten:raw_food"), 0, "food reached storage")
	_conserved(sim)


func test_plants_grow_only_in_daylight() -> void:
	var sim := _sim()
	sim.set_zone(Vector2i(5, 5), "growing")
	assert_true(sim.farming.sow(Vector2i(5, 5), "tuber"))
	sim.tick = sim.ticks_per_day * 17 / 24  # night
	var p := sim.farming.plant_at(Vector2i(5, 5))
	sim.run_ticks(50)
	assert_eq(p.growth, 0, "no growth at night")
	sim.tick = sim.ticks_per_day * 6 / 24  # noon
	sim.run_ticks(50)
	assert_eq(p.growth, 50)
	sim.set_zone(Vector2i(5, 5), "")
	sim.run_ticks(1)
	assert_eq(sim.farming.plants.size(), 0, "clearing the zone removes the crop")


func test_stove_cooks_meals_from_raw_food() -> void:
	var sim := _sim()
	_stockpile(sim, Vector2i(10, 10), Vector2i(3, 2))
	_give(sim, Vector2i(10, 10), "raw_food", 8)
	var stove := sim.buildings.place("stove", Vector2i(6, 6), false)
	sim.colonists.spawn(Vector2i(5, 5))
	sim.run_ticks(600)
	assert_true(sim.ledger.get_count("eaten:raw_food") + sim.ledger.get_count("eaten:meal") >= 0)
	assert_gt(sim.items.count_world("meal") + sim.ledger.get_count("eaten:meal"), 0, "meals were cooked")
	assert_true(sim.buildings.refined_batches > 0 and stove.recipe_id == "cook_meal")
	assert_gt(sim.ledger.get_count("recipe:meal"), 0)
	_conserved(sim)


func test_cooking_respects_work_type_priority() -> void:
	var sim := _sim()
	_stockpile(sim, Vector2i(10, 10), Vector2i(3, 2))
	_give(sim, Vector2i(10, 10), "raw_food", 8)
	sim.buildings.place("stove", Vector2i(6, 6), false)
	var c := sim.colonists.spawn(Vector2i(5, 5))
	sim.set_work_priority(c.id, "cooking", 0)
	sim.run_ticks(600)
	assert_eq(sim.ledger.get_count("recipe:meal"), 0, "cooking disabled: no meals")


func test_refinery_is_not_operated_as_cooking() -> void:
	var sim := _sim()
	var g: WorkGiver = sim.jobs.givers["cook"]
	sim.buildings.place("refinery", Vector2i(6, 6), false)
	var c := sim.colonists.spawn(Vector2i(5, 5))
	assert_true(g.find(c) == null, "cook giver ignores the refinery")


func test_needs_are_deterministic() -> void:
	var snaps: Array = []
	for run in 2:
		var sim := _sim(7)
		_stockpile(sim, Vector2i(10, 10), Vector2i(2, 2))
		_stockpile(sim, Vector2i(3, 12), Vector2i(2, 2), "growing")
		_give(sim, Vector2i(10, 10), "raw_food", 10)
		sim.buildings.place("stove", Vector2i(6, 6), false)
		sim.buildings.place("bed", Vector2i(7, 6), false)
		sim.colonists.spawn(Vector2i(5, 5))
		sim.colonists.spawn(Vector2i(4, 5))
		sim.run_ticks(sim.ticks_per_day * 2)
		var s := [sim.items.count_world("raw_food"), sim.items.count_world("meal"), sim.farming.plants.size()]
		for c in sim.colonists.list:
			s.append_array([c.cell, snappedf(c.needs.food, 0.0001), snappedf(c.needs.rest, 0.0001)])
		snaps.append(s)
	assert_eq(str(snaps[0]), str(snaps[1]), "same seed, same game")
