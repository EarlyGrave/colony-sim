extends TestCase
## E2: colonists, pathfinding, job priorities, hauling.


func _zone_rect(sim: Simulation, origin: Vector2i, size: Vector2i, zone := "stockpile") -> void:
	for y in size.y:
		for x in size.x:
			sim.set_zone(origin + Vector2i(x, y), zone)


func _wall(sim: Simulation, x: int, from_y: int, to_y: int) -> void:
	for y in range(from_y, to_y + 1):
		sim.map.set_tile(Vector2i(x, y), MapGrid.Tile.ROCK)


func test_colonist_hauls_item_around_wall() -> void:
	var sim := make_sim(1, false, 24, 24)
	_wall(sim, 12, 0, 20)  # gap at the bottom
	var c := sim.colonists.spawn(Vector2i(2, 2))
	sim.ledger.record_produced("essence_ore", 7, "test")
	sim.items.add_at(Vector2i(3, 10), "essence_ore", 7)
	_zone_rect(sim, Vector2i(20, 2), Vector2i(2, 2))
	sim.run_ticks(1000)
	assert_eq(sim.items.count_stored("essence_ore"), 7, "ore not stored")
	assert_eq(sim.items.count_on_ground("essence_ore"), 7)
	assert_true(c.job == null or c.job.type == "sleep", "colonist still busy: " + (c.job.describe() if c.job else ""))  # needs: may be asleep
	assert_eq(c.carry_count, 0)


func test_three_colonists_never_stuck_1000_ticks() -> void:
	var sim := make_sim(2024)
	var center := sim.map_center()
	# Scatter loose ore around the landing site.
	var placed := 0
	for i in 12:
		var p := center + Vector2i(sim.rng.randi_range(-5, 5), sim.rng.randi_range(-5, 5))
		if sim.cell_free_for_items(p) and sim.map.get_zone(p) == "":
			placed += sim.items.add_at(p, "essence_ore", 5)
	sim.ledger.record_produced("essence_ore", placed, "test")
	var max_stuck := [0]
	sim.bus.tick_advanced.connect(func(_t: int) -> void:
		for c in sim.colonists.list:
			max_stuck[0] = maxi(max_stuck[0], c.stuck_ticks))
	sim.run_ticks(1000)
	assert_eq(sim.colonists.list.size(), 3)
	assert_lt(max_stuck[0], 20, "a colonist stood still on a path")
	assert_eq(sim.items.count_stored("essence_ore"), sim.items.count_on_ground("essence_ore"), "loose ore left")
	assert_eq(sim.items.count_world("essence_ore"), sim.ledger.balance_of("essence_ore"))


func test_haul_has_priority_over_mining() -> void:
	var sim := make_sim(3, false, 16, 16)
	var c := sim.colonists.spawn(Vector2i(5, 5))
	sim.map.set_tile(Vector2i(6, 5), MapGrid.Tile.DEPOSIT, 20)
	sim.designate_mine(Vector2i(6, 5), true)
	sim.items.add_at(Vector2i(12, 12), "essence_ore", 3)
	_zone_rect(sim, Vector2i(1, 1), Vector2i(2, 2))
	var j := sim.jobs.assign(c)
	assert_true(j is HaulJob, "expected haul, got " + (j.type if j else "null"))


func test_reservation_prevents_double_assignment() -> void:
	var sim := make_sim(4, false, 16, 16)
	var a := sim.colonists.spawn(Vector2i(2, 2))
	var b := sim.colonists.spawn(Vector2i(3, 2))
	sim.items.add_at(Vector2i(8, 8), "essence_ore", 3)
	_zone_rect(sim, Vector2i(12, 12), Vector2i(2, 2))
	sim.step()
	assert_true(a.job is HaulJob)
	assert_true(b.job == null, "second colonist took the same stack")


func test_unreachable_item_does_not_trap_colonist() -> void:
	var sim := make_sim(5, false, 16, 16)
	var c := sim.colonists.spawn(Vector2i(1, 1))
	# Item sealed in a rock box.
	for d in MapGrid.NEIGHBORS_8:
		sim.map.set_tile(Vector2i(10, 10) + d, MapGrid.Tile.ROCK)
	sim.items.add_at(Vector2i(10, 10), "essence_ore", 3)
	sim.items.add_at(Vector2i(4, 4), "essence_ore", 2)
	_zone_rect(sim, Vector2i(1, 12), Vector2i(2, 2))
	sim.run_ticks(600)
	assert_eq(sim.items.count_stored("essence_ore"), 2, "reachable ore should still be hauled")
	assert_true(c.job == null or c.job.type == "sleep")  # needs: may be asleep


func test_partial_carry_is_delivered_after_dst_fills() -> void:
	var defs := peaceful_defs()
	defs.balance["storyteller"]["enabled"] = false
	var sim := make_sim(6, false, 16, 16, defs)
	sim.colonists.spawn(Vector2i(1, 1))
	# 60 ore but storage cells hold 50 each: needs two cells and several trips.
	sim.items.add_at(Vector2i(8, 8), "essence_ore", 50)
	sim.items.add_at(Vector2i(8, 9), "essence_ore", 10)
	_zone_rect(sim, Vector2i(1, 12), Vector2i(2, 1))
	sim.run_ticks(2500)
	assert_eq(sim.items.count_stored("essence_ore"), 60)
