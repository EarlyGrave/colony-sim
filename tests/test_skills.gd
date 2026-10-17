extends TestCase
## Skills: speed, xp, levels, passion, deterministic init.


func _ticks_to_first_ore(level: int) -> int:
	var sim := make_sim(8, false, 20, 20, peaceful_defs())
	var c := sim.colonists.spawn(Vector2i(2, 2))
	c.skills.levels["mining"] = level
	sim.map.set_tile(Vector2i(8, 2), MapGrid.Tile.DEPOSIT, 100)
	sim.designate_mine(Vector2i(8, 2), true)
	for i in 600:
		sim.step()
		if sim.ledger.get_count("mining:essence_ore") > 0:
			return sim.tick
	return 600


func test_higher_skill_finishes_faster() -> void:
	var slow := _ticks_to_first_ore(0)
	var fast := _ticks_to_first_ore(20)
	assert_lt(fast, slow, "level 20 (%d) should beat level 0 (%d)" % [fast, slow])
	assert_lt(slow, 600)


func test_xp_raises_levels_and_emits_signal() -> void:
	var sim := make_sim(8, false, 20, 20, peaceful_defs())
	var c := sim.colonists.spawn(Vector2i(2, 2))
	c.skills.levels["mining"] = 0
	c.skills.passions["mining"] = Skills.Passion.NONE
	var got: Array = []
	sim.bus.skill_leveled.connect(func(id: int, skill: String, lvl: int) -> void: got.append([id, skill, lvl]))
	sim.map.set_tile(Vector2i(8, 2), MapGrid.Tile.DEPOSIT, 5000)
	sim.designate_mine(Vector2i(8, 2), true)
	sim.run_ticks(1500)
	assert_gt(c.skills.level("mining"), 0, "no level gained")
	assert_false(got.is_empty(), "no skill_leveled signal")
	assert_eq(got[0], [c.id, "mining", 1])


func test_passion_multiplies_xp() -> void:
	var defs := Defs.get_default()
	var a := Skills.new()
	var b := Skills.new()
	for s in [a, b]:
		s.levels["mining"] = 0
		s.xp["mining"] = 0.0
	a.passions["mining"] = Skills.Passion.NONE
	b.passions["mining"] = Skills.Passion.MAJOR
	a.add_xp(defs, "mining", 30.0)
	b.add_xp(defs, "mining", 30.0)
	assert_gt(float(b.xp["mining"]), float(a.xp["mining"]))


func test_level_capped() -> void:
	var defs := Defs.get_default()
	var s := Skills.new()
	s.levels["mining"] = 19
	s.xp["mining"] = 0.0
	s.passions["mining"] = Skills.Passion.NONE
	s.add_xp(defs, "mining", 1.0e6)
	assert_eq(s.level("mining"), 20)


func test_speed_multiplier_grows_with_level() -> void:
	var defs := Defs.get_default()
	var s := Skills.new()
	s.levels["mining"] = 0
	assert_near(s.speed_mult(defs, "mining"), 1.0, 0.0001)
	s.levels["mining"] = 20
	assert_gt(s.speed_mult(defs, "mining"), 1.5)
	assert_near(s.speed_mult(defs, ""), 1.0, 0.0001)


func _fingerprint(sim: Simulation) -> Array:
	var out: Array = [sim.tick, sim.rng.randi()]
	for c in sim.colonists.list:
		out.append([c.cell, c.skills.levels.duplicate(), c.skills.priorities.duplicate(), int(c.skills.xp["mining"] * 100.0)])
	for id in sim.defs.items.keys():
		out.append(sim.items.count_world(id))
	return out


func test_long_sim_deterministic_with_skills() -> void:
	var fps: Array = []
	for i in 2:
		var sim := make_sim(31, true, 24, 24, peaceful_defs())
		var center := sim.map_center()
		var n := 0
		for y in sim.map.height:
			for x in sim.map.width:
				var cell := Vector2i(x, y)
				if n < 6 and sim.map.is_deposit(cell) and sim.map.is_adjacent_to_passable(cell) and cell.distance_squared_to(center) < 400:
					sim.designate_mine(cell, true)
					n += 1
		sim.run_ticks(6000)
		fps.append(_fingerprint(sim))
	assert_eq(fps[0], fps[1], "same seed must give same game incl. skills")


func test_spawn_skills_depend_on_seed_only() -> void:
	var a := make_sim(4, false, 10, 10).colonists.spawn(Vector2i(1, 1))
	var b := make_sim(4, false, 10, 10).colonists.spawn(Vector2i(1, 1))
	assert_eq(a.skills.levels, b.skills.levels)
	assert_eq(a.skills.passions, b.skills.passions)
