extends TestCase


func _free_row(sim: Simulation, n: int) -> Vector2i:
	for y in range(2, sim.map.height - 2):
		for x in range(2, sim.map.width - n - 2):
			var ok := true
			for i in n:
				if sim.can_belt_cell_error(Vector2i(x + i, y)) != "" or sim.can_belt_cell_error(Vector2i(x + i, y + 1)) != "":
					ok = false
			if ok:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _belts(sim: Simulation, from: int, to: int, y: int, d: int) -> void:
	for x in range(from, to + 1):
		sim.logistics.place_belt_cell(Vector2i(x, y), d)


func _free_sim() -> Simulation:
	return make_sim(3, true, 40, 40, peaceful_defs())


func test_storage_out_feeds_belt_into_storage_in() -> void:
	var sim := _free_sim()
	var o := _free_row(sim, 12)
	assert_true(o.x >= 0)
	var so := sim.buildings.place("storage_out", o, false)
	var si := sim.buildings.place("storage_in", o + Vector2i(10, 0), false)
	assert_true(so != null and si != null)
	_belts(sim, o.x + 1, o.x + 9, o.y, 1)
	so.input["copper_ore"] = 5
	for t in 400:
		sim.step()
	assert_eq(int(si.output.get("copper_ore", 0)), 5)
	assert_false(so.input.has("copper_ore"))


func test_belt_facing_away_does_not_feed() -> void:
	var sim := _free_sim()
	var o := _free_row(sim, 6)
	var si := sim.buildings.place("storage_in", o + Vector2i(5, 0), false)
	_belts(sim, o.x, o.x + 3, o.y, 3)  # west-facing, ends next to nothing
	sim.logistics.place_belt_cell(o + Vector2i(4, 0), 3)  # next to storage_in, pointing away
	sim.logistics.insert_item(o + Vector2i(4, 0), "iron_ore")
	for t in 50:
		sim.step()
	assert_eq(si.output.size(), 0)


func test_full_buffer_stalls_without_loss() -> void:
	var sim := _free_sim()
	var o := _free_row(sim, 6)
	var si := sim.buildings.place("storage_in", o + Vector2i(5, 0), false)
	si.output["x"] = 200
	_belts(sim, o.x, o.x + 4, o.y, 1)
	sim.logistics.insert_item(o, "iron_ore")
	for t in 100:
		sim.step()
	assert_eq(sim.logistics.belts.item_count, 1)
	assert_eq(sim.logistics.belts.peek_ready(o + Vector2i(4, 0)), sim.logistics.item_id("iron_ore"))


func test_out_port_blocked_by_occupied_belt_keeps_items() -> void:
	var sim := _free_sim()
	var o := _free_row(sim, 4)
	var so := sim.buildings.place("storage_out", o, false)
	so.input["iron_ore"] = 3
	# no belt: nothing leaves
	for t in 10:
		sim.step()
	assert_eq(int(so.input["iron_ore"]), 3)


func test_colonist_hauls_into_storage_out_and_out_of_storage_in() -> void:
	var sim := _free_sim()
	var o := _free_row(sim, 4)
	var so := sim.buildings.place("storage_out", o, false)
	assert_gt(so.input_space("iron_ore"), 199)
	so.add_input("iron_ore", 200)
	assert_eq(so.input_space("iron_ore"), 0)
	var si := sim.buildings.place("storage_in", o + Vector2i(2, 0), false)
	assert_eq(si.input_space("iron_ore"), 0)  # hand input not accepted
