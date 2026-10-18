extends TestCase
## S1: Release Shuttle (gated by balance "s1_enabled").


func _sim(on: bool = true, seed_value: int = 5) -> Simulation:
	var d := peaceful_defs()
	d.balance["s1_enabled"] = on
	d.balance["e1_enabled"] = true
	var sim := make_sim(seed_value, false, 30, 30, d)
	sim.colonists.spawn(Vector2i(4, 4))
	for x in 12:
		for y in 3:
			sim.set_zone(Vector2i(2 + x, 20 + y), "stockpile")
	sim.run_ticks(1)
	return sim


func _unlock(sim: Simulation) -> void:
	sim.petition.done_phases = [1, 2, 3, 4]


func _stock(sim: Simulation, item: String, n: int) -> void:
	sim.ledger.record_produced(item, n, "test")
	var left := n
	for x in 12:
		for y in 3:
			var c := Vector2i(2 + x, 20 + y)
			if left <= 0 or sim.map.get_zone(c) == "" or sim.items.stacks.has(c) and sim.items.stacks[c]["item"] != item:
				continue
			left -= sim.items.add_at(c, item, left)
	assert_eq(left, 0, "room to stock " + item)


func _fill(sim: Simulation) -> void:
	var need: int = sim.shuttle.parts_need()
	_stock(sim, "plate", 2 * need)
	_stock(sim, "refined_essence", need)
	_stock(sim, "fuel_cell", need)


func test_off_by_default_and_locked() -> void:
	var sim := _sim(false)
	_unlock(sim)
	assert_eq(sim.get_shuttle_state()["phase"], "locked")
	assert_eq(sim.deliver_shuttle_parts(), 0)
	var on := _sim()
	assert_eq(on.get_shuttle_state()["phase"], "locked", "P4 not done")
	_unlock(on)
	assert_eq(on.get_shuttle_state()["phase"], "building")


func test_parts_accounting() -> void:
	var sim := _sim()
	_unlock(sim)
	assert_eq(sim.deliver_shuttle_parts(), 0, "needs a gantry")
	sim.buildings.place("release_gantry", Vector2i(10, 6), false)
	_stock(sim, "plate", 7)
	_stock(sim, "refined_essence", 3)
	_stock(sim, "fuel_cell", 3)
	assert_eq(sim.deliver_shuttle_parts(), 3, "limited by essence/cells")
	assert_eq(sim.items.count_stored("plate"), 1)
	assert_eq(sim.items.count_stored("fuel_cell"), 0)
	assert_eq(sim.get_shuttle_state()["parts"], 3)


func test_launch_win() -> void:
	var sim := _sim()
	_unlock(sim)
	sim.buildings.place("release_gantry", Vector2i(10, 6), false)
	assert_false(sim.launch_shuttle())
	_fill(sim)
	sim.deliver_shuttle_parts()
	assert_eq(sim.get_shuttle_state()["phase"], "ready")
	var won: Array = []
	sim.bus.shuttle_won.connect(func() -> void: won.append(1))
	assert_true(sim.launch_shuttle())
	assert_eq(sim.get_shuttle_state()["phase"], "countdown")
	assert_false(sim.launch_shuttle(), "already counting")
	sim.run_ticks(int(sim.get_shuttle_state()["t_left"]) + 2)
	assert_eq(sim.get_shuttle_state()["phase"], "won")
	assert_eq(won.size(), 1)


func test_siege_starts_wave_and_fail_retry() -> void:
	var sim := _sim()
	_unlock(sim)
	var g := sim.buildings.place("release_gantry", Vector2i(10, 6), false)
	_fill(sim)
	sim.deliver_shuttle_parts()
	sim.launch_shuttle()
	var waves := sim.threats.wave_index
	sim.run_ticks(300)
	assert_gt(sim.threats.wave_index, waves, "siege wave called")
	sim.buildings.damage(g, 99999.0)
	sim.run_ticks(2)
	var st := sim.get_shuttle_state()
	assert_eq(st["phase"], "building")
	assert_eq(st["failures"], 1)
	assert_eq(st["parts"], sim.shuttle.parts_need() / 2)
	sim.buildings.place("release_gantry", Vector2i(10, 6), false)
	_fill(sim)
	sim.deliver_shuttle_parts()
	assert_true(sim.launch_shuttle(), "retry allowed")


func test_repair() -> void:
	var sim := _sim()
	_unlock(sim)
	var g := sim.buildings.place("release_gantry", Vector2i(10, 6), false)
	g.hp = 100.0
	assert_false(sim.repair_gantry(), "needs plates")
	_stock(sim, "plate", 10)
	assert_true(sim.repair_gantry())
	assert_eq(g.hp, g.max_hp)


func _trace(seed_value: int) -> Array:
	var sim := _sim(true, seed_value)
	_unlock(sim)
	sim.buildings.place("release_gantry", Vector2i(10, 6), false)
	_fill(sim)
	sim.deliver_shuttle_parts()
	sim.launch_shuttle()
	sim.run_ticks(900)
	return [sim.shuttle.state_parts(), sim.threats.wave_index, SaveGame.state_hash(sim)]


func test_determinism() -> void:
	assert_eq(_trace(3), _trace(3))


func test_commands_recorded_and_midcountdown_state() -> void:
	var sim := _sim()
	_unlock(sim)
	sim.buildings.place("release_gantry", Vector2i(10, 6), false)
	_fill(sim)
	sim.deliver_shuttle_parts()
	sim.launch_shuttle()
	sim.run_ticks(400)
	var st := sim.get_shuttle_state()
	assert_eq(st["phase"], "countdown")
	assert_lt(int(st["t_left"]), int(sim.ticks_per_day * 2.0))
	var names: Array = []
	for c in sim.command_log:
		names.append(c[1] if c is Array and c.size() > 1 else str(c))
	var txt := var_to_str(sim.command_log)
	assert_true("deliver_shuttle_parts" in txt and "launch_shuttle" in txt, "commands go through _record")
	assert_true(sim.shuttle.has_state())
	assert_eq(sim.shuttle.state_parts()[0], "s1")
