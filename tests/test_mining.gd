extends TestCase
## E3: mining, stockpiles, conservation of items.


## Designates the `n` nodes of `res` nearest to the map centre (mining a node
## clears its designation, so callers re-designate to keep mining).
func _designate_nodes(sim: Simulation, n: int, res := "essence_ore") -> int:
	var center := sim.map_center()
	var cells: Array[Vector2i] = []
	for c in sim.map.node_cells():
		if sim.map.node_resource(c) == res and sim.map.is_adjacent_to_passable(c):
			cells.append(c)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_squared_to(center) < b.distance_squared_to(center))
	for i in mini(n, cells.size()):
		sim.designate_mine(cells[i], true)
	return mini(n, cells.size())


func _mine_for(sim: Simulation, n: int, ticks: int, step := 100, res := "essence_ore") -> void:
	for i in ticks / step:
		_designate_nodes(sim, n, res)
		sim.run_ticks(step)


func test_mined_ore_reaches_stockpile() -> void:
	var sim := make_sim(11)
	var start_stored := sim.items.count_stored("essence_ore")
	assert_gt(_designate_nodes(sim, 4), 0, "no essence node reachable")
	_mine_for(sim, 4, 3000)
	assert_gt(sim.ledger.get_count("mining:essence_ore"), 20, "too little mined")
	assert_gt(sim.items.count_stored("essence_ore"), start_stored + 20, "ore not delivered to stockpile")


func test_nodes_never_deplete_and_ore_is_conserved() -> void:
	for seed_value in [11, 12, 13]:
		var sim := make_sim(seed_value)
		var nodes_before := sim.map.node_cells().size()
		var lost_before := sim.map.deposit_lost
		for i in 8:
			_mine_for(sim, 6, 500)
			var ore_world := sim.items.count_world("essence_ore")
			assert_eq(ore_world, sim.ledger.balance_of("essence_ore"), "seed %d: ore appeared/vanished at tick %d" % [seed_value, sim.tick])
		assert_gt(sim.ledger.get_count("mining:essence_ore"), 0, "seed %d: nothing mined" % seed_value)
		assert_eq(sim.map.node_cells().size(), nodes_before, "seed %d: nodes are infinite" % seed_value)
		assert_eq(sim.map.deposit_lost, lost_before, "seed %d: nothing is lost from nodes" % seed_value)
		assert_eq(sim.map.total_deposit_amount(), 0, "seed %d: nodes carry no finite amount" % seed_value)


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
	_mine_for(a, 5, 1500)
	_mine_for(b, 5, 1500)
	for i in a.colonists.list.size():
		assert_eq(a.colonists.list[i].cell, b.colonists.list[i].cell)
	assert_eq(a.items.stacks, b.items.stacks)
