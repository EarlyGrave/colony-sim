extends TestCase
## Blueprints (build by frame), walls blocking paths, creatures vs walls.


func _sim() -> Simulation:
	var sim := make_sim(41, false, 20, 20, peaceful_defs())
	sim.ledger.record_produced("essence_ore", 50, "test")
	for y in 2:
		for x in 3:
			sim.set_zone(Vector2i(2 + x, 10 + y), "stockpile")
	sim.items.drop(Vector2i(2, 10), "essence_ore", 50)
	return sim


func _check_conservation(sim: Simulation) -> void:
	for item: String in sim.defs.items:
		assert_eq(sim.items.count_world(item), sim.ledger.balance_of(item), "conservation " + item)


func test_place_building_creates_blueprint() -> void:
	var sim := _sim()
	var bp := sim.place_building("wall", Vector2i(8, 5))
	assert_true(bp != null)
	assert_false(sim.buildings.at(Vector2i(8, 5)) != null, "no building yet")
	assert_true(sim.buildings.occupied(Vector2i(8, 5)), "cell is reserved")
	assert_ne(sim.can_place_building("wall", Vector2i(8, 5)), "")
	assert_true(sim.pathfinder.is_walkable(Vector2i(8, 5)), "a plan does not block")


func test_stays_unbuilt_without_materials() -> void:
	var sim := make_sim(42, false, 20, 20, peaceful_defs())
	sim.colonists.spawn(Vector2i(3, 3))
	sim.place_building("wall", Vector2i(8, 5))
	sim.run_ticks(600)
	assert_eq(sim.buildings.list.size(), 0)
	assert_eq(sim.buildings.blueprints.size(), 1)


func test_built_after_hauling_and_work() -> void:
	var sim := _sim()
	sim.colonists.spawn(Vector2i(3, 3))
	sim.place_building("wall", Vector2i(8, 5))
	sim.run_ticks(40)
	assert_eq(sim.buildings.list.size(), 0, "work takes time")
	sim.run_ticks(600)
	assert_eq(sim.buildings.blueprints.size(), 0)
	var b := sim.buildings.at(Vector2i(8, 5))
	assert_true(b != null and b.def_id == "wall")
	assert_eq(sim.ledger.get_count("construction:essence_ore"), 2)
	assert_false(sim.pathfinder.is_walkable(Vector2i(8, 5)))
	_check_conservation(sim)


func test_progress_needs_all_materials() -> void:
	var sim := make_sim(49, false, 20, 20, peaceful_defs())
	var bp := sim.place_building("refinery", Vector2i(8, 5))
	bp.delivered["essence_ore"] = int(sim.defs.buildings["refinery"]["cost"]["essence_ore"]) - 1
	assert_false(bp.has_all_materials())
	sim.colonists.spawn(Vector2i(8, 6))
	sim.run_ticks(300)
	assert_eq(sim.buildings.list.size(), 0, "one ore short: not built")
	assert_eq(bp.work_done, 0.0)


func test_cancel_returns_materials() -> void:
	var sim := _sim()
	sim.colonists.spawn(Vector2i(3, 3))
	var bp := sim.place_building("refinery", Vector2i(8, 5))
	sim.run_ticks(150)
	assert_gt(bp.delivered_total(), 0, "materials arrived")
	_check_conservation(sim)
	var delivered := bp.delivered_total()
	var ground := sim.items.count_on_ground("essence_ore")
	assert_true(sim.deconstruct(Vector2i(8, 5)))
	assert_eq(sim.buildings.blueprints.size(), 0)
	assert_false(sim.buildings.occupied(Vector2i(8, 5)))
	assert_eq(sim.items.count_on_ground("essence_ore"), ground + delivered)
	assert_eq(sim.ledger.get_count("construction:essence_ore"), 0, "nothing consumed")
	sim.run_ticks(100)
	_check_conservation(sim)


func test_walls_block_pathing_and_update() -> void:
	var sim := make_sim(43, false, 20, 20, peaceful_defs())
	var a := Vector2i(2, 10)
	var b := Vector2i(17, 10)
	assert_true(sim.pathfinder.reachable(a, b))
	for y in 20:
		if y != 10:
			sim.buildings.place("wall", Vector2i(10, y), false)
	var path := sim.pathfinder.find_path(a, b)
	assert_false(path.is_empty())
	assert_true(path.has(Vector2i(10, 10)), "must squeeze through the gap")
	sim.buildings.place("wall", Vector2i(10, 10), false)
	assert_false(sim.pathfinder.reachable(a, b))
	assert_true(sim.pathfinder.find_path(a, b).is_empty())
	assert_true(sim.pathfinder.reachable_terrain(a, b), "bare terrain ignores walls")
	sim.deconstruct(Vector2i(10, 10))
	assert_true(sim.pathfinder.reachable(a, b), "removing a wall reopens the way")


func test_door_is_passable() -> void:
	var sim := make_sim(44, false, 20, 20, peaceful_defs())
	for y in 20:
		sim.buildings.place("door" if y == 10 else "wall", Vector2i(10, y), false)
	assert_true(sim.pathfinder.reachable(Vector2i(2, 10), Vector2i(17, 10)))


func test_builder_standing_on_wall_is_moved_out() -> void:
	var sim := make_sim(45, false, 20, 20, peaceful_defs())
	var c := sim.colonists.spawn(Vector2i(5, 5))
	sim.buildings.place("wall", Vector2i(5, 5), false)
	assert_ne(c.cell, Vector2i(5, 5))
	assert_true(sim.pathfinder.is_walkable(c.cell))


func test_enemy_goes_around_wall() -> void:
	var sim := make_sim(46, false, 20, 20, peaceful_defs())
	var hq := sim.buildings.place("hq", Vector2i(12, 9), false)
	for y in range(0, 15):
		sim.buildings.place("wall", Vector2i(6, y), false)
	var e := sim.threats._spawn("crawler", Vector2i(1, 10))
	sim.run_ticks(900)
	assert_lt(hq.hp, hq.max_hp, "creature walked around the wall and reached the capsule")
	for y in range(0, 15):
		assert_eq(sim.buildings.at(Vector2i(6, y)).hp, 150.0, "walls untouched")
	assert_true(e != null)


func test_sealed_capsule_makes_enemy_attack_wall() -> void:
	var sim := make_sim(47, false, 20, 20, peaceful_defs())
	var hq := sim.buildings.place("hq", Vector2i(9, 9), false)
	for i in range(6, 13):
		for p: Vector2i in [Vector2i(i, 6), Vector2i(i, 12), Vector2i(6, i), Vector2i(12, i)]:
			if sim.buildings.at(p) == null:
				sim.buildings.place("wall", p, false)
	sim.threats._spawn("crawler", Vector2i(1, 9))
	sim.run_ticks(150)
	var hurt := 0
	for b in sim.buildings.list:
		if b.def_id == "wall" and b.hp < b.max_hp:
			hurt += 1
	var destroyed := 28 - sim.buildings.count_of("wall")
	assert_gt(hurt + destroyed, 0, "sapper attacks the wall")
	assert_eq(hq.hp, hq.max_hp, "capsule was never reached")
	# Once a breach exists the creature continues to the capsule.
	sim.run_ticks(4000)
	assert_lt(hq.hp, hq.max_hp)


func test_sealed_colony_still_gets_waves() -> void:
	var sim := make_sim(48, false, 20, 20, peaceful_defs())
	sim.buildings.place("hq", Vector2i(9, 9), false)
	for i in range(6, 13):
		for p: Vector2i in [Vector2i(i, 6), Vector2i(i, 12), Vector2i(6, i), Vector2i(12, i)]:
			if sim.buildings.at(p) == null:
				sim.buildings.place("wall", p, false)
	assert_true(sim.threats._pick_spawn_origin().x >= 0)
