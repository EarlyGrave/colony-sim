extends TestCase
## Audit Deliveries: exact consumption, partial accumulation, letter once, replay.


func _sim() -> Simulation:
	var sim := make_sim(5, false, 24, 24, peaceful_defs())
	sim.colonists.spawn(Vector2i(4, 4))
	for x in 8:
		sim.set_zone(Vector2i(6 + x, 6), "stockpile")
	sim.buildings.place("warden_terminal", Vector2i(10, 10), false)
	return sim


func _stock(sim: Simulation, item: String, n: int) -> void:
	sim.ledger.record_produced(item, n, "test")
	sim.items.drop(Vector2i(6, 6), item, n)  # spills over the zone cells


func test_item_ids_exist() -> void:
	var d := Defs.get_default()
	for t: String in d.milestones["tiers"]:
		for item: String in d.milestones["tiers"][t]["parts"]:
			assert_true(d.items.has(item), "item " + item)


func test_start_state() -> void:
	var sim := _sim()
	assert_eq(sim.milestones.tier(), 1)
	assert_false(sim.deliver_audit(3), "tier 3 needs tier 2 first")


func test_exact_consumption_and_unlock_once() -> void:
	var sim := _sim()
	var letters: Array = []
	sim.bus.letter_received.connect(func(t: String, _x: String) -> void: letters.append(t))
	_stock(sim, "plate", 50)
	_stock(sim, "parts", 15)
	assert_true(sim.deliver_audit(2))
	assert_eq(sim.items.count_stored("plate"), 10)
	assert_eq(sim.items.count_stored("parts"), 5)
	assert_eq(sim.milestones.tier(), 2)
	assert_eq(letters.size(), 1)
	assert_eq(letters[0], "Audit passed: Tier 2")
	assert_false(sim.deliver_audit(2), "already done")
	assert_eq(letters.size(), 1)
	assert_eq(sim.items.count_stored("plate"), 10)


func test_partial_accumulates_and_replays() -> void:
	var sim := _sim()
	_stock(sim, "plate", 30)
	assert_false(sim.deliver_audit(2))
	assert_eq(sim.milestones.tier(), 1)
	assert_eq(int(sim.milestones.delivered[2]["plate"]), 30)
	assert_eq(sim.items.count_stored("plate"), 0)
	_stock(sim, "plate", 10)
	_stock(sim, "parts", 10)
	assert_true(sim.deliver_audit(2))
	var b := _sim()
	_stock(b, "plate", 30)
	b.deliver_audit(2)
	_stock(b, "plate", 10)
	_stock(b, "parts", 10)
	b.deliver_audit(2)
	assert_eq(SaveGame.state_hash(b), SaveGame.state_hash(sim))
	var n := 0
	for e: Array in sim.command_log:
		if e[1] == "deliver_audit":
			n += 1
	assert_eq(n, 2, "audit commands recorded")


func test_needs_terminal() -> void:
	var sim := make_sim(5, false, 24, 24, peaceful_defs())
	for x in 4:
		sim.set_zone(Vector2i(6 + x, 6), "stockpile")
	_stock(sim, "plate", 40)
	_stock(sim, "parts", 10)
	assert_false(sim.deliver_audit(2))
	assert_eq(sim.items.count_stored("plate"), 40)


func test_terminal_unique() -> void:
	var sim := _sim()
	assert_true(sim.buildings.placement_error("warden_terminal", Vector2i(14, 14), false) != "")
