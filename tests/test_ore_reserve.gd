extends TestCase
## Rule "ore_reserve": haulers keep a minimum of stored ore out of refineries.


func _setup(rule_on: bool, ore := 40) -> Simulation:
	var defs := peaceful_defs()
	defs.balance["threat"]["enabled"] = false
	var sim := make_sim(7, false, 20, 20, defs)
	sim.colonists.spawn(Vector2i(2, 2))
	for y in 2:
		for x in 3:
			sim.set_zone(Vector2i(2 + x, 10 + y), "stockpile")
			sim.set_zone(Vector2i(14 + x, 10 + y), "waste_dump")
	sim.ledger.record_produced("essence_ore", ore, "test")
	sim.items.drop(Vector2i(2, 10), "essence_ore", ore)
	sim.buildings.place("refinery", Vector2i(9, 5), false)
	sim.set_rule("ore_reserve", rule_on)
	return sim


func test_rule_defaults_and_data() -> void:
	var sim := make_sim(1, false, 10, 10)
	assert_false(sim.is_rule_on("ore_reserve"))
	assert_eq(int(sim.defs.rules["ore_reserve"]["amount"]), 20)


func test_rule_off_refinery_drains_stock() -> void:
	var sim := _setup(false)
	sim.run_ticks(3000)
	assert_lt(sim.items.count_stored("essence_ore"), 20, "stock should be drained")


func test_rule_on_keeps_reserve_and_refining_continues() -> void:
	var sim := _setup(true)
	var amount := int(sim.defs.rules["ore_reserve"]["amount"])
	for i in 60:
		sim.run_ticks(50)
		assert_true(sim.items.count_stored("essence_ore") >= amount, "stock fell below reserve")
	assert_gt(sim.buildings.refined_batches, 0, "surplus should still be refined")


func test_rule_on_without_surplus_no_refining() -> void:
	var sim := _setup(true, 20)
	sim.run_ticks(2000)
	assert_eq(sim.items.count_stored("essence_ore"), 20)
	assert_eq(sim.buildings.refined_batches, 0)
