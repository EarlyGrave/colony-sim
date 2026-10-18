extends TestCase
## A2a: miner / smelter / assembler machines (no operator needed).


func _sim_with_node(res: String, purity: int) -> Simulation:
	var sim := make_sim(1, false, 24, 24, peaceful_defs())
	var c := Vector2i(8, 8)
	sim.map.set_tile(c, MapGrid.Tile.DEPOSIT, 0)
	var i := sim.map.idx(c)
	sim.map.node_res[i] = NodeData.res_index(res)
	sim.map.node_purity[i] = purity
	return sim


func test_miner_rate_by_purity() -> void:
	for p in range(1, 4):  # 1 impure 0.5x, 2 normal 1x, 3 pure 2x
		var sim := _sim_with_node("copper_ore", p)
		var m := sim.buildings.place("miner", Vector2i(8, 8), false)
		assert_true(m != null, "miner placed on node")
		sim.run_ticks(100)
		var expect := 10.0 * NodeData.purity_mult("copper_ore", p)
		assert_lt(absf(int(m.output.get("copper_ore", 0)) - expect), 2.0, "purity %d" % p)


func test_miner_rate_without_cap() -> void:
	var sim := _sim_with_node("iron_ore", 3)
	var m := sim.buildings.place("miner", Vector2i(8, 8), false)
	sim.run_ticks(100)
	assert_lt(absf(int(m.output.get("iron_ore", 0)) - 20), 2.0, "pure: 20 per 100 ticks")


func test_miner_needs_node() -> void:
	var sim := make_sim(1, false, 24, 24, peaceful_defs())
	assert_true(sim.buildings.place("miner", Vector2i(8, 8), false) == null)


func test_smelter_idle_without_input_and_smelts() -> void:
	var sim := make_sim(1, false, 24, 24, peaceful_defs())
	var s := sim.buildings.place("smelter", Vector2i(8, 8), false)
	sim.run_ticks(200)
	assert_eq(s.output_total(), 0)
	assert_eq(s.progress, 0)
	assert_eq(s.add_input("copper_ore", 4), 4)
	assert_eq(s.add_input("ingot_iron", 4), 0, "not a smelter input")
	sim.run_ticks(138)  # unoperated machines run at 0.6 speed (R3X)
	assert_eq(int(s.output.get("ingot_copper", 0)), 1)
	assert_eq(int(s.output.get("waste", 0)), 1)
	assert_eq(int(s.input.get("copper_ore", 0)), 2)
	sim.run_ticks(138)  # unoperated machines run at 0.6 speed (R3X)
	assert_eq(int(s.output.get("ingot_copper", 0)), 2)
	assert_eq(sim.buildings.refined_batches, 2)


func test_smelter_waste_equals_hand_refinery() -> void:
	var a := make_sim(1, false, 24, 24, peaceful_defs())
	var b := make_sim(1, false, 24, 24, peaceful_defs())
	var s := a.buildings.place("smelter", Vector2i(8, 8), false)
	s.add_input("essence_ore", 10)
	while s.output.is_empty():  # unoperated: 0.6 speed, so wait for the batch tick
		a.run_ticks(1)
	var r := b.buildings.place("refinery", Vector2i(8, 8), false)
	r.add_input("essence_ore", 10)
	while r.progress < 99:
		b.buildings.work(r, 1, null)
	assert_true(b.buildings.work(r, 1, null))
	assert_eq(s.output, r.output, "same batch outputs")
	b.run_ticks(1)  # same waste-in-buffer term as the smelter's batch tick
	assert_eq(a.contamination.level, b.contamination.level, "same per-batch contamination")


func test_assembler_chain_and_wear() -> void:
	var sim := make_sim(1, false, 24, 24, peaceful_defs())
	var m := sim.buildings.place("assembler", Vector2i(8, 8), false)
	m.add_input("ingot_iron", 2)
	m.add_input("ingot_copper", 1)
	sim.run_ticks(105)
	assert_eq(int(m.output.get("plate", 0)), 1)
	sim.run_ticks(5)
	assert_eq(int(m.output.get("parts", 0)), 0, "plate stays in output; needs hauling to input")
	assert_lt(m.condition, 100.0)
	m.condition = 1.0
	m.add_input("ingot_iron", 2)
	sim.run_ticks(120)
	assert_true(m.broken)
	var n := m.output_total()
	sim.run_ticks(200)
	assert_eq(m.output_total(), n, "broken machine stops")
