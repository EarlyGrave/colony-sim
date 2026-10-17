extends TestCase
## E3: mining, stockpiles, conservation of items.


func _designate_near(sim: Simulation, n: int) -> int:
	var center := sim.map_center()
	var cells: Array[Vector2i] = []
	for y in sim.map.height:
		for x in sim.map.width:
			var c := Vector2i(x, y)
			if sim.map.is_deposit(c) and sim.map.is_adjacent_to_passable(c):
				cells.append(c)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_squared_to(center) < b.distance_squared_to(center))
	var total := 0
	for i in mini(n, cells.size()):
		sim.designate_mine(cells[i], true)
		total += sim.map.get_deposit_amount(cells[i])
	return total


func test_mined_ore_reaches_stockpile() -> void:
	var sim := make_sim(11)
	var start_stored := sim.items.count_stored("essence_ore")
	_designate_near(sim, 4)
	sim.run_ticks(3000)
	assert_gt(sim.ledger.get_count("mining:essence_ore"), 20, "too little mined")
	assert_gt(sim.items.count_stored("essence_ore"), start_stored + 20, "ore not delivered to stockpile")


func test_resources_are_conserved() -> void:
	for seed_value in [11, 12, 13]:
		var sim := make_sim(seed_value)
		var deposits_before := sim.map.total_deposit_amount()
		_designate_near(sim, 6)
		for i in 8:
			sim.run_ticks(500)
			var ore_world := sim.items.count_world("essence_ore")
			assert_eq(ore_world, sim.ledger.balance_of("essence_ore"), "seed %d: ore appeared/vanished at tick %d" % [seed_value, sim.tick])
			var mined := sim.ledger.get_count("mining:essence_ore")
			assert_eq(deposits_before - sim.map.total_deposit_amount(), mined + sim.map.deposit_lost, "seed %d: deposit accounting" % seed_value)


func test_mining_stops_when_designation_removed() -> void:
	var sim := make_sim(3, false, 16, 16)
	sim.colonists.spawn(Vector2i(2, 2))
	sim.map.set_tile(Vector2i(8, 8), MapGrid.Tile.DEPOSIT, 100)
	sim.designate_mine(Vector2i(8, 8), true)
	sim.run_ticks(200)
	sim.designate_mine(Vector2i(8, 8), false)
	sim.run_ticks(50)  # finish the current swing
	var mined := sim.ledger.get_count("mining:essence_ore")
	assert_gt(mined, 0)
	sim.run_ticks(500)
	assert_eq(sim.ledger.get_count("mining:essence_ore"), mined)


func test_same_seed_same_game() -> void:
	var a := make_sim(99)
	var b := make_sim(99)
	_designate_near(a, 5)
	_designate_near(b, 5)
	a.run_ticks(1500)
	b.run_ticks(1500)
	for i in a.colonists.list.size():
		assert_eq(a.colonists.list[i].cell, b.colonists.list[i].cell)
	assert_eq(a.items.stacks, b.items.stacks)
