extends TestCase
## A1a: infinite resource nodes with purity.


func test_nodes_exist_near_hq_on_each_seed() -> void:
	for s in range(1, 6):
		var sim := make_sim(s)
		var nodes := sim.map.node_cells()
		assert_gt(nodes.size(), 7, "seed %d: too few nodes" % s)
		var near := 0
		for c in nodes:
			if Vector2(c - sim.map_center()).length() <= 20.0:
				near += 1
		assert_gt(near, 2, "seed %d: too few nodes near HQ" % s)


func test_purity_mix_matches_weights() -> void:
	var counts := [0, 0, 0, 0]
	var total := 0
	for s in range(1, 6):
		var sim := make_sim(s)
		for c in sim.map.node_cells():
			counts[sim.map.node_purity[sim.map.idx(c)]] += 1
			total += 1
	var w: Dictionary = NodeData.biome("start")["purity_weights"]
	var wsum := 0.0
	for k in w:
		wsum += float(w[k])
	for p in range(1, 4):
		var expect := float(w[NodeData.PURITY_IDS[p]]) / wsum
		assert_lt(absf(float(counts[p]) / total - expect), 0.15, "purity %d share off" % p)


func test_node_never_depletes_and_yield_ratio() -> void:
	var sim := make_sim(3)
	var cells := sim.map.node_cells()
	var got := {}
	for p in range(1, 4):
		var c := cells[p]
		sim.map.node_purity[sim.map.idx(c)] = p
		sim.map.node_carry[sim.map.idx(c)] = 0.0
		var sum := 0
		for i in 1000:
			sum += sim.map.mine_node(c, 5.0)
		got[p] = sum
		assert_true(sim.map.is_node(c), "node depleted")
		assert_eq(sim.map.take_from_deposit(c, 5), 5)
	assert_eq(got[2], 2 * got[1])
	assert_eq(got[3], 2 * got[2])


func test_same_seed_identical_node_arrays() -> void:
	var a := make_sim(7)
	var b := make_sim(7)
	assert_eq(a.map.node_res, b.map.node_res)
	assert_eq(a.map.node_purity, b.map.node_purity)


func test_hand_mining_yields_node_resource() -> void:
	var sim := make_sim(11)
	var center := sim.map_center()
	var best := Vector2i(-1, -1)
	for c in sim.map.node_cells():
		if sim.map.is_adjacent_to_passable(c) and (best.x < 0 or c.distance_squared_to(center) < best.distance_squared_to(center)):
			best = c
	sim.designate_mine(best, true)
	var cycles := [0]
	sim.bus.item_mined.connect(func(c: Vector2i, _i: String, _n: int) -> void:
		if c == best:
			cycles[0] += 1)
	sim.run_ticks(2000)
	assert_true(sim.map.is_node(best), "node must survive mining")
	assert_true(sim.map.is_mine_designated(best), "designation stays on an infinite node")
	assert_true(cycles[0] >= 2, "node is mined repeatedly")
	sim.designate_mine(best, false)
	assert_false(sim.map.is_mine_designated(best))
