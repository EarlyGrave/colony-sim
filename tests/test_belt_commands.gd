extends TestCase
## Belt commands: atomic paths, 1 command per drag, save/load round trip.


func _row(x0: int, y: int, n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append(Vector2i(x0 + i, y))
	return out


## Finds a row of n free ground cells starting at (x, y); y is returned in .y.
func _free_row(sim: Simulation, n: int, skip := 0) -> Array:
	var found := 0
	for y in sim.map.height:
		for x in range(0, sim.map.width - n):
			var row := _row(x, y, n)
			var ok := true
			for c: Vector2i in row:
				if sim.can_belt_cell_error(c) != "":
					ok = false
					break
			if ok:
				if found == skip:
					return row
				found += 1
	return []


func test_path_is_one_command_and_sets_dirs() -> void:
	var sim := make_sim(5, true, 24, 24, peaceful_defs())
	var before := sim.command_log.size()
	var row := _free_row(sim, 20)
	assert_eq(row.size(), 20)
	assert_true(sim.place_belt(row, 0))
	assert_eq(sim.command_log.size(), before + 1)
	assert_eq(sim.logistics.dir_at(row[0]), 1)  # east
	assert_true(sim.set_belt_dir(row[19], 1))
	assert_eq(sim.logistics.dir_at(row[19]), 1)
	assert_true(sim.remove_belt([row[0]]))
	assert_false(sim.logistics.has_belt(row[0]))


func test_invalid_cell_rejects_whole_path() -> void:
	var sim := make_sim(5, true, 24, 24, peaceful_defs())
	var row := _free_row(sim, 10)
	sim.map.set_tile(row[7], MapGrid.Tile.ROCK)
	assert_false(sim.place_belt(row, 0))
	for c: Vector2i in row:
		assert_false(sim.logistics.has_belt(c))
	var hq := sim.buildings.list[0]
	assert_false(sim.place_belt([hq.cell + Vector2i(-1, 0), hq.cell], 0))
	assert_false(sim.place_belt([Vector2i(1, 1), Vector2i(3, 1)], 0), "gap")
	assert_false(sim.place_belt([Vector2i(-1, 1)], 0), "out of bounds")


func test_save_load_round_trip_50_belts() -> void:
	var sim := make_sim(7, true, 24, 24, peaceful_defs())
	var a := _free_row(sim, 30)
	assert_eq(a.size(), 30)
	assert_true(sim.place_belt(a, 0))
	var b := _free_row(sim, 20)
	assert_true(sim.place_belt(b, 2))
	sim.run_ticks(50)
	var res := SaveGame.load_json(SaveGame.to_json(sim), make_bus(), peaceful_defs())
	assert_true(res["ok"], str(res["error"]))
	var sim2: Simulation = res["sim"]
	assert_eq(SaveGame.state_hash(sim2), SaveGame.state_hash(sim))
	assert_true(sim2.logistics.has_belt(a[29]))
	_sims.append(sim2)


func test_old_version_incompatible() -> void:
	var sim := make_sim(7, false, 20, 20, peaceful_defs())
	var d := SaveGame.to_dict(sim)
	d["version"] = 1
	var res := SaveGame.load_dict(d, make_bus(), peaceful_defs())
	assert_false(res["ok"])
	assert_eq(res["error"], "version")
