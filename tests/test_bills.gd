extends TestCase
## Bills on workbenches, storage filters and priorities.


func _setup(ore := 60, refined := 30) -> Simulation:
	var defs := peaceful_defs()
	var sim := make_sim(7, false, 24, 20, defs)
	sim.colonists.spawn(Vector2i(2, 2))
	for y in 2:
		for x in 3:
			sim.set_zone(Vector2i(2 + x, 10 + y), "stockpile")
	sim.ledger.record_produced("essence_ore", ore, "test")
	sim.items.drop(Vector2i(2, 10), "essence_ore", ore)
	sim.ledger.record_produced("refined_essence", refined, "test")
	sim.items.drop(Vector2i(3, 10), "refined_essence", refined)
	return sim


func _bench(sim: Simulation) -> Building:
	var b := sim.buildings.place("workbench", Vector2i(10, 5), false)
	assert_true(b != null, "workbench not placed")
	return b


func _parts(sim: Simulation) -> int:
	return sim.items.count_world("machine_parts")


func test_do_x_times_stops() -> void:
	var sim := _setup()
	var b := _bench(sim)
	assert_gt(sim.add_bill(b.id, "machine_parts", "count", 3), 0)
	sim.run_ticks(3000)
	assert_eq(_parts(sim), 3, "exactly 3 parts")
	assert_eq(sim.ledger.get_count("recipe:machine_parts"), 3)
	assert_eq(sim.crafting.bills_of(b)[0].done, 3)


func test_until_maintains_stock() -> void:
	var sim := _setup()
	var b := _bench(sim)
	sim.add_bill(b.id, "machine_parts", "until", 2)
	sim.run_ticks(2500)
	assert_eq(_parts(sim), 2, "stock held at 2")
	# Consume one; the bill refills it.
	var cell := Vector2i(-1, -1)
	for c in sim.items.stacks:
		if sim.items.item_at(c) == "machine_parts":
			cell = c
	if cell.x < 0:
		fail("parts not on the ground")
		return
	sim.items.take_at(cell, 1)
	sim.ledger.record_consumed("machine_parts", 1, "test")
	sim.run_ticks(2500)
	assert_eq(_parts(sim), 2, "refilled to 2")


func test_paused_and_invalid_bills() -> void:
	var sim := _setup()
	var b := _bench(sim)
	assert_eq(sim.add_bill(b.id, "refine_essence", "count", 1), -1, "recipe not for this bench")
	var id := sim.add_bill(b.id, "machine_parts", "forever", 0)
	sim.update_bill(b.id, id, "forever", 0, true)
	sim.run_ticks(1000)
	assert_eq(_parts(sim), 0, "paused bill does nothing")
	assert_true(sim.remove_bill(b.id, id))
	assert_eq(sim.crafting.bills_of(b).size(), 0)


func test_filter_blocks_items() -> void:
	var sim := _setup(0, 0)
	var spare := Vector2i(8, 14)
	sim.set_zone(spare, "stockpile")
	sim.set_zone(Vector2i(2, 10), "stockpile")
	assert_true(sim.set_zone_filter(Vector2i(2, 10), "essence_ore", false))
	assert_false(sim.items.cell_accepts(Vector2i(2, 10), "essence_ore"))
	sim.ledger.record_produced("essence_ore", 10, "test")
	sim.items.drop(Vector2i(12, 14), "essence_ore", 10)
	sim.run_ticks(1500)
	assert_eq(sim.items.count_stored("essence_ore"), 10, "ore stored")
	for c in sim.storage.group_of(Vector2i(2, 10)):
		assert_ne(sim.items.item_at(c), "essence_ore", "filtered group holds no ore")
	assert_false(sim.set_zone_filter(Vector2i(2, 10), "waste", false), "waste not in stockpile type")


func test_high_priority_zone_pulls_items() -> void:
	var sim := _setup(20, 0)
	var far := Vector2i(14, 15)
	sim.set_zone(far, "stockpile")
	assert_true(sim.set_zone_priority(far, 2))
	assert_eq(sim.storage.priority(Vector2i(2, 10)), 1)
	sim.run_ticks(1500)
	assert_eq(sim.items.count_at(far), 20, "ore moved to high-priority zone")
	assert_eq(sim.items.count_stored("essence_ore"), 20)


func test_conserved_with_bills_and_zones() -> void:
	var sim := _setup()
	var b := _bench(sim)
	sim.add_bill(b.id, "machine_parts", "count", 4)
	sim.set_zone(Vector2i(14, 15), "stockpile")
	sim.set_zone_priority(Vector2i(14, 15), 2)
	sim.run_ticks(3000)
	for item: String in ["essence_ore", "refined_essence", "machine_parts"]:
		assert_eq(sim.items.count_world(item), sim.ledger.balance_of(item), "conservation " + item)
