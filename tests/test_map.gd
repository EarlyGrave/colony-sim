extends TestCase


func _gen(seed_value: int) -> Simulation:
	var sim := Simulation.new(seed_value, make_bus())
	sim.start_new_game()
	return sim


func test_same_seed_same_map() -> void:
	var a := _gen(12345)
	var b := _gen(12345)
	assert_eq(a.map.tiles, b.map.tiles, "tiles differ")
	assert_eq(a.map.deposit_amount, b.map.deposit_amount, "deposits differ")
	assert_eq(a.map.checksum(), b.map.checksum())


func test_different_seed_different_map() -> void:
	assert_ne(_gen(1).map.checksum(), _gen(2).map.checksum())


func test_map_has_terrain_mix_and_reachable_deposits() -> void:
	for s in [1, 7, 42, 999, 31337]:
		var sim := _gen(s)
		var counts := {0: 0, 1: 0, 2: 0}
		for t in sim.map.tiles:
			counts[t] += 1
		assert_gt(counts[MapGrid.Tile.ROCK], 50, "seed %d: too little rock" % s)
		assert_gt(counts[MapGrid.Tile.DEPOSIT], 10, "seed %d: too few deposits" % s)
		# At least one deposit can be mined from the landing site.
		var center := sim.map_center()
		var minable := 0
		for y in sim.map.height:
			for x in sim.map.width:
				var c := Vector2i(x, y)
				if sim.map.is_deposit(c) and sim.pathfinder.best_adjacent(center, c) != Vector2i(-1, -1):
					minable += 1
		assert_gt(minable, 5, "seed %d: deposits unreachable" % s)


func test_landing_area_is_clear() -> void:
	var sim := _gen(5)
	var c := sim.map_center()
	for d in [Vector2i(0, 0), Vector2i(3, 0), Vector2i(-3, 2), Vector2i(0, -4)]:
		assert_true(sim.map.is_passable(c + d), "landing cell %s blocked" % str(c + d))


func test_every_ground_tile_reachable_from_center() -> void:
	var sim := _gen(77)
	var center := sim.map_center()
	for y in sim.map.height:
		for x in sim.map.width:
			var c := Vector2i(x, y)
			if sim.map.is_passable(c):
				assert_true(sim.pathfinder.reachable(center, c), "pocket at %s" % str(c))
				if not sim.pathfinder.reachable(center, c):
					return


func test_depleting_deposit_opens_tile() -> void:
	var sim := Simulation.new(1, make_bus())
	sim.start_empty(8, 8)
	sim.map.set_tile(Vector2i(4, 4), MapGrid.Tile.DEPOSIT, 7)
	sim.pathfinder.refresh_cell(Vector2i(4, 4))
	assert_false(sim.map.is_passable(Vector2i(4, 4)))
	assert_eq(sim.map.take_from_deposit(Vector2i(4, 4), 5), 5)
	assert_eq(sim.map.take_from_deposit(Vector2i(4, 4), 5), 2)
	assert_true(sim.map.is_passable(Vector2i(4, 4)))
	assert_eq(sim.pathfinder.find_path(Vector2i(3, 4), Vector2i(5, 4)).size(), 2)
