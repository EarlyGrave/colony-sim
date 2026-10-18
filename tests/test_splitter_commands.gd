extends TestCase
## L2: place_belt_node / set_splitter_filter commands and replay. Needs L1's BeltGrid node
## kinds for the positive cases; those parts skip (pass) until L1 is merged.


func _l1(sim: Simulation) -> bool:
	return sim.logistics.belts.has_method("place_node") and sim.logistics.belts.has_method("set_filter")


func _free_row(sim: Simulation, n: int) -> Array:
	for y in sim.map.height:
		for x in range(0, sim.map.width - n):
			var ok := true
			for i in n:
				if sim.can_belt_cell_error(Vector2i(x + i, y)) != "":
					ok = false
					break
			if ok:
				var out: Array = []
				for i in n:
					out.append(Vector2i(x + i, y))
				return out
	return []


func test_invalid_arguments_rejected_and_recorded() -> void:
	var sim := make_sim(5, true, 24, 24, peaceful_defs())
	var n := sim.command_log.size()
	assert_false(sim.place_belt_node(0, Vector2i(3, 3), 0))
	assert_false(sim.place_belt_node(9, Vector2i(3, 3), 0))
	assert_false(sim.place_belt_node(1, Vector2i(3, 3), 7))
	assert_false(sim.place_belt_node(1, Vector2i(-1, 3), 0))
	assert_false(sim.set_splitter_filter(Vector2i(3, 3), 5, "any"))
	assert_false(sim.set_splitter_filter(Vector2i(3, 3), 0, "no_such_item"))
	assert_false(sim.set_splitter_filter(Vector2i(3, 3), 0, "any"))  # no smart node there
	assert_eq(sim.command_log.size(), n + 7)


func test_nodes_and_filters_replay_equal_hash() -> void:
	var sim := make_sim(7, true, 40, 40, peaceful_defs())
	if not _l1(sim):
		return
	var row := _free_row(sim, 12)
	assert_eq(row.size(), 12)
	assert_true(sim.place_belt(row, 1))
	assert_true(sim.place_belt_node(1, row[2], 1))
	assert_true(sim.place_belt_node(2, row[4], 1))  # replaces a plain belt in place
	assert_true(sim.place_belt_node(3, row[6], 1))
	assert_true(sim.place_belt_node(4, row[8], 1))
	assert_eq(sim.get_belt_node_kind(row[4]), 2)
	assert_false(sim.set_splitter_filter(row[2], 0, "iron_ore"))  # basic: no filters
	var ids: Array = sim.defs.items.keys()
	ids.sort()
	var vals: Array = ["any", "overflow", str(ids[0]), str(ids[1]), "any", str(ids[0])]
	for i in vals.size():
		assert_true(sim.set_splitter_filter(row[4], i % 3, vals[i]))
	assert_eq(sim.get_splitter_filter(row[4], 2), str(ids[0]))
	sim.run_ticks(200)
	var r := SaveGame.load_json(SaveGame.to_json(sim), make_bus(), peaceful_defs())
	assert_true(r["ok"], str(r["error"]))
	var sim2: Simulation = r["sim"]
	_sims.append(sim2)
	assert_eq(SaveGame.state_hash(sim2), SaveGame.state_hash(sim))
	assert_eq(sim2.get_splitter_filter(row[4], 2), str(ids[0]))
