extends TestCase
## Deconstruct tool: refund, conservation, protected capsule, busy operator.


func _sim() -> Simulation:
	var sim := make_sim(31, false, 20, 20, peaceful_defs())
	sim.ledger.record_produced("essence_ore", 100, "test")
	sim.items.drop(Vector2i(2, 10), "essence_ore", 100)
	return sim


func _check_conservation(sim: Simulation) -> void:
	for item: String in sim.defs.items:
		assert_eq(sim.items.count_world(item), sim.ledger.balance_of(item), "conservation " + item)


func test_refund_and_conservation() -> void:
	var sim := _sim()
	var b := sim.buildings.place("refinery", Vector2i(9, 5), false)
	b.input["essence_ore"] = 4
	sim.ledger.record_produced("essence_ore", 4, "test")
	var before := sim.items.count_on_ground("essence_ore")
	assert_true(sim.deconstruct(Vector2i(9, 5)))
	assert_false(sim.buildings.occupied(Vector2i(9, 5)))
	assert_eq(sim.ledger.get_count("refund:essence_ore"), 7)
	assert_eq(sim.items.count_on_ground("essence_ore"), before + 7 + 4)
	_check_conservation(sim)
	assert_false(sim.deconstruct(Vector2i(9, 5)))


func test_capsule_refused() -> void:
	var sim := _sim()
	var hq := sim.buildings.place("hq", Vector2i(5, 5), false)
	assert_eq(hq.def_id, "hq")
	assert_false(sim.deconstruct(hq.cell))
	assert_true(sim.buildings.occupied(hq.cell))
	assert_eq(sim.game_over_reason, "")


func test_operating_colonist_survives() -> void:
	var sim := _sim()
	sim.colonists.spawn(Vector2i(2, 2))
	for y in 2:
		for x in 3:
			sim.set_zone(Vector2i(2 + x, 10 + y), "stockpile")
	sim.buildings.place("refinery", Vector2i(9, 5), false)
	sim.run_ticks(150)
	assert_true(sim.deconstruct(Vector2i(9, 5)))
	sim.run_ticks(200)
	assert_false(sim.jobs.reserved.has("op:1"))
	_check_conservation(sim)
