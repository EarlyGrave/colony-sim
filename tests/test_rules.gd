extends TestCase
## E10: "if-then" rule — during a raid the engineer repairs turrets.


func _setup(rule_on: bool) -> Simulation:
	var sim := make_sim(51, false, 24, 24, peaceful_defs())
	sim.buildings.place("hq", Vector2i(10, 10), false)
	sim.buildings.place("turret", Vector2i(16, 10), false)
	for i in 3:
		var c := sim.colonists.spawn(Vector2i(4 + i, 4))
		c.engineer = i == 0
	sim.set_rule("raid_engineer", rule_on)
	sim.set_alarm(true)
	sim.run_ticks(80)
	for c in sim.colonists.list:
		assert_true(c.hidden, "everyone hides first")
	return sim


func _turret(sim: Simulation) -> Building:
	for b in sim.buildings.list:
		if b.def_id == "turret":
			return b
	return null


func test_rule_is_off_by_default() -> void:
	var sim := make_sim(50, false, 10, 10)
	assert_false(sim.is_rule_on("raid_engineer"))


func test_without_rule_nobody_repairs_during_raid() -> void:
	var sim := _setup(false)
	var t := _turret(sim)
	sim.buildings.wear(t, 1000.0)
	sim.run_ticks(300)
	assert_true(t.broken, "nobody leaves the shelter without the rule")


func test_engineer_repairs_turret_and_hides_again() -> void:
	var sim := _setup(true)
	var t := _turret(sim)
	sim.buildings.wear(t, 1000.0)
	sim.run_ticks(5)
	var eng := sim.colonists.list[0]
	assert_false(eng.hidden, "engineer goes out")
	assert_true(eng.job is RepairJob)
	for i in [1, 2]:
		assert_true(sim.colonists.list[i].hidden, "others stay hidden")
	sim.run_ticks(300)
	assert_false(t.broken, "engineer repaired the turret")
	assert_true(eng.hidden, "engineer returns to the shelter")


func test_engineer_ignores_scratches() -> void:
	var sim := _setup(true)
	var t := _turret(sim)
	sim.buildings.damage(t, 5.0)
	sim.run_ticks(20)
	assert_true(sim.colonists.list[0].hidden, "minor damage is not worth the risk")


func test_sick_engineer_stays_hidden() -> void:
	var sim := _setup(true)
	sim.colonists.list[0].sick_until = sim.tick + 1000
	sim.buildings.wear(_turret(sim), 1000.0)
	sim.run_ticks(50)
	assert_true(sim.colonists.list[0].hidden)
