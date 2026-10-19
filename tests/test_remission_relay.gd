extends TestCase
## EN4: Collector relay (Fight win) and Remission ending, end to end.


func _sim(path: String) -> Simulation:
	var d := peaceful_defs()
	d.balance["e1_enabled"] = true
	d.balance["q_enabled"] = true
	var sim := make_sim(5, false, 30, 30, d)
	sim.colonists.spawn(Vector2i(4, 4))
	sim.run_ticks(1)
	sim.set_path(path)
	return sim


func test_relay_burned_down_by_uplink_wins_fight() -> void:
	var sim := _sim("fight")
	var won: Array = []
	sim.bus.ending_won.connect(func(id: String) -> void: won.append(id))
	sim.fight_escape.on_collector_assault()
	assert_true(sim.fight_escape.relay() != null, "relay landed")
	sim.run_ticks(sim.ticks_per_day)
	assert_false(sim.endings.won("fight"), "no Uplink: relay survives")
	sim.buildings.place("uplink_array", Vector2i(2, 20), false)
	sim.run_ticks(sim.ticks_per_day * 2)
	assert_true(sim.endings.won("fight"))
	assert_eq(won, ["fight"])


func test_relay_only_on_fight_path() -> void:
	var sim := _sim("escape")
	sim.fight_escape.on_collector_assault()
	assert_true(sim.fight_escape.relay() == null)


func test_remission_disabled_by_default() -> void:
	var sim := _sim("remission")
	assert_false(sim.remission.enabled())
	sim.contamination.level = 0.0
	sim.run_ticks(sim.ticks_per_day * 20)
	assert_false(sim.endings.won("remission"))


func test_remission_end_to_end() -> void:
	var sim := _sim("remission")
	sim.defs.endings["remission"]["enabled"] = true
	sim.defs.endings["remission"]["quiet_days"] = 1
	sim.contamination.level = 12.0
	sim.buildings.place("decon_pylon", Vector2i(2, 20), false)
	sim.run_ticks(sim.ticks_per_day * 2)
	assert_false(sim.endings.won("remission"), "no cure, no remission")
	sim.set_zone(Vector2i(10, 10), "stockpile")
	sim.items.drop(Vector2i(10, 10), "cure", 20)
	sim.run_ticks(sim.ticks_per_day * 2)
	assert_gt(sim.remission.cures_used, 0)
	assert_lt(sim.remission.frac(), 0.1)
	sim.run_ticks(sim.ticks_per_day * 1)
	assert_true(sim.endings.won("remission"))


func test_metro_final_assault_drops_relay() -> void:
	var d := Defs.get_default().duplicate_defs()
	d.balance["metro"]["enabled"] = true
	d.balance["metro"]["first_raid_day"] = 0.0
	d.balance["e1_enabled"] = true
	d.balance["q_enabled"] = true
	d.balance["threat"]["first_wave_max_points"] = 1000.0
	var sim := make_sim(31, false, 40, 40, d)
	sim.buildings.place("hq", Vector2i(19, 19), false)
	sim.colonists.spawn(Vector2i(10, 10))
	sim.run_ticks(1)
	sim.set_path("fight")
	sim.threats.awakened = true
	sim.threats.next_wave_tick = sim.tick + sim.ticks_per_day * 50
	var m := sim.threats.metro()
	m.add_defiance(100.0)
	m.raids_started = 4
	sim.run_ticks(sim.ticks_per_day * 2)
	assert_true(m.final_done, "final assault started")
	assert_true(sim.fight_escape.relay() != null, "relay dropped by the assault")
