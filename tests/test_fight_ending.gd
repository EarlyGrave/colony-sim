extends TestCase
## EN3: Fight ending (Uplink Array + Collector assault) and Escape ending (bandit fee, extraction).


func _sim(path: String) -> Simulation:
	var d := peaceful_defs()
	d.balance["e1_enabled"] = true
	d.balance["q_enabled"] = true
	var sim := make_sim(5, false, 30, 30, d)
	sim.colonists.spawn(Vector2i(4, 4))
	sim.run_ticks(1)
	sim.set_path(path)
	# harmless waves: this test is about the ending flow, not combat (balance is tuned elsewhere)
	sim.defs.endings["escape"]["pursuit_mult"] = 0.0
	for r: Dictionary in sim.defs.endings["fight"]["raids"]:
		r["mult"] = 0.0
	return sim


func test_assault_needs_path_and_uplink() -> void:
	var sim := _sim("escape")
	assert_false(sim.start_assault(), "wrong path")
	var f := _sim("fight")
	assert_false(f.start_assault(), "no uplink")


func test_fight_ending_end_to_end() -> void:
	var sim := _sim("fight")
	var won: Array = []
	sim.bus.ending_won.connect(func(id: String) -> void: won.append(id))
	sim.buildings.place("uplink_array", Vector2i(10, 6), false)
	assert_true(sim.start_assault())
	assert_true(sim.quests.flag("ponr_fight"))
	assert_false(sim.start_assault(), "already running")
	var w := sim.threats.wave_index
	sim.run_ticks(sim.ticks_per_day * 3)
	assert_gt(sim.threats.wave_index, w + 1, "scripted raids launched")
	assert_eq(sim.fight_escape.assault_step, 2)
	for i in 40:
		if sim.fight_escape.assault_done:
			break
		sim.run_ticks(sim.ticks_per_day)
	assert_true(sim.endings.won("fight"))
	assert_eq(won, ["fight"])


func test_assault_fails_when_uplink_destroyed() -> void:
	var sim := _sim("fight")
	var u := sim.buildings.place("uplink_array", Vector2i(10, 6), false)
	assert_true(sim.start_assault())
	sim.buildings.damage(u, 99999.0)
	sim.run_ticks(3)
	assert_false(sim.fight_escape.assault_active())
	assert_eq(sim.fight_escape.assault_failed, 1)
	assert_false(sim.endings.won("fight"))


func test_escape_gates_and_fee() -> void:
	var sim := _sim("escape")
	assert_false(sim.contact_bandits(), "needs sales")
	sim.contraband.sales = 3
	assert_true(sim.contact_bandits())
	assert_true(sim.quests.flag("ponr_escape"))
	assert_false(sim.pay_bandit_fee(), "no credit")
	sim.contraband.escape_credit = 70
	assert_true(sim.pay_bandit_fee())
	assert_eq(sim.contraband.escape_credit, 10, "fee 60 from credit")
	assert_false(sim.pay_bandit_fee(), "once")


func test_escape_ending_and_missed_pickup() -> void:
	var sim := _sim("escape")
	sim.contraband.sales = 3
	sim.contraband.escape_credit = 60
	sim.contact_bandits()
	sim.pay_bandit_fee()
	var w := sim.threats.wave_index
	assert_true(sim.start_extraction())
	assert_eq(sim.threats.wave_index, w + 1, "pursuit wave")
	sim.run_ticks(sim.ticks_per_day + 2)
	assert_false(sim.endings.won("escape"), "nobody at the point")
	assert_eq(sim.fight_escape.extract_failed, 1)
	var c: Colonist = sim.colonists.list[0]
	assert_true(sim.start_extraction())
	sim.run_ticks(sim.ticks_per_day - 2)  # colonists wander meanwhile; the player walks them to the point
	c.cell = sim.fight_escape.extract_cell
	c.clear_path()
	c.job = null
	c.idle_until = sim.tick + 100

	sim.run_ticks(4)
	assert_true(sim.endings.won("escape"))
	assert_eq(sim.fight_escape.extracted, 1)


func test_deterministic_replay() -> void:
	var h: Array = []
	for i in 2:
		var sim := _sim("fight")
		sim.buildings.place("uplink_array", Vector2i(10, 6), false)
		sim.start_assault()
		sim.run_ticks(sim.ticks_per_day * 2)
		h.append(SaveGame.state_hash(sim))
	assert_eq(h[0], h[1])
