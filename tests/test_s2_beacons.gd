extends TestCase
## S2: Penance Beacons (gated by balance "s2_enabled").


func _sim(on: bool = true, seed_value: int = 5) -> Simulation:
	var d := peaceful_defs()
	d.balance["s2_enabled"] = on
	d.beacons["build_ticks"] = 20
	var sim := make_sim(seed_value, false, 24, 24, d)
	sim.colonists.spawn(Vector2i(4, 4))
	for x in 8:
		sim.set_zone(Vector2i(6 + x, 6), "stockpile")
		sim.set_zone(Vector2i(6 + x, 7), "stockpile")
	sim.buildings.place("beacon_launcher", Vector2i(10, 10), false)
	sim.run_ticks(1)
	return sim


func _stock(sim: Simulation, item: String, n: int) -> void:
	sim.ledger.record_produced(item, n, "test")
	sim.items.drop(Vector2i(6 + (item.length() % 8), 6 + (item.length() % 2)), item, n)


func _debt(sim: Simulation) -> DebtState:
	return sim.debt.state_of(sim.colonists.list[0])


func test_off_by_default() -> void:
	var sim := _sim(false)
	_stock(sim, "plate", 5)
	_stock(sim, "refined_essence", 5)
	sim.run_ticks(100)
	assert_eq(sim.get_beacon_state()["alive"], 0)
	assert_false(sim.beacons.has_state())


func test_launch_consumes_and_ledger_balances() -> void:
	var sim := _sim()
	_stock(sim, "plate", 2)
	_stock(sim, "refined_essence", 2)
	sim.run_ticks(60)
	assert_eq(sim.get_beacon_state()["alive"], 2)
	assert_eq(sim.items.count_stored("plate"), 0)
	assert_eq(sim.ledger.get_count("beacon:plate"), 2)
	assert_eq(sim.ledger.balance_of("plate"), sim.items.count_stored("plate"))


func test_power_off_pauses() -> void:
	var sim := _sim()
	_stock(sim, "plate", 2)
	_stock(sim, "refined_essence", 2)
	sim.buildings.list[0].broken = true
	sim.run_ticks(60)
	assert_eq(sim.get_beacon_state()["alive"], 0)
	sim.buildings.list[0].broken = false
	sim.run_ticks(30)
	assert_eq(sim.get_beacon_state()["alive"], 1)


func test_decay_and_debt_cut() -> void:
	var sim := _sim()
	_stock(sim, "plate", 1)
	_stock(sim, "refined_essence", 1)
	sim.run_ticks(30)
	assert_eq(sim.get_beacon_state()["alive"], 1)
	var before := _debt(sim).paid
	sim.run_ticks(sim.ticks_per_day)
	assert_gt(_debt(sim).paid, before)
	assert_gt(sim.get_beacon_state()["debt_rate_cut"], 0.0)
	sim.run_ticks(sim.ticks_per_day * 4)
	assert_eq(sim.get_beacon_state()["alive"], 0)
	assert_gt(_debt(sim).remaining(), 0)


func test_cap_and_diminishing() -> void:
	var sim := _sim()
	var cfg := sim.beacons.cfg
	for i in 8:
		sim.beacons.expiry.append(99999)
	assert_lt(sim.beacons.rate_pct(), float(cfg["cap_pct"]) + 0.001)
	sim.beacons.expiry.clear()
	sim.beacons.expiry.append(99999)
	var one := sim.beacons.rate_pct()
	sim.beacons.expiry.append(99999)
	assert_lt(sim.beacons.rate_pct(), one * 2.0)


func _run(seed_value: int) -> Simulation:
	var sim := _sim(true, seed_value)
	_stock(sim, "plate", 3)
	_stock(sim, "refined_essence", 3)
	sim.run_ticks(sim.ticks_per_day + 100)
	return sim


func test_determinism_and_replay() -> void:
	var a := _run(7)
	var b := _run(7)
	assert_eq(SaveGame.state_hash(a), SaveGame.state_hash(b))
	assert_true(a.beacons.has_state())
	assert_eq(a.beacons.launched, b.beacons.launched)
