extends TestCase
## Beacon of Penance decoys (T2): research gate, fuel/lit threat, wall hp, bell burst, replay.


func _sim() -> Simulation:
	return make_sim(4, false, 28, 28, peaceful_defs())


func _spot(sim: Simulation, def_id: String) -> Vector2i:
	var scen := preload("res://tests/scenario.gd")
	return scen.find_spot(sim, def_id, sim.map_center() + Vector2i(6, 6), 0)


func _place(sim: Simulation, def_id: String) -> Building:
	var b := sim.buildings.place(def_id, _spot(sim, def_id), false)
	assert_true(b != null, "placed " + def_id)
	return b


func test_research_gate() -> void:
	var sim := _sim()
	sim.research.gating = true
	var c := _spot(sim, "ash_beacon")
	assert_eq(sim.buildings.placement_error("ash_beacon", c, false), "locked: decoys_1")
	assert_eq(sim.buildings.placement_error("mourning_bell", c, false), "locked: decoys_2")
	sim.research.done.append("decoys_1")
	assert_eq(sim.buildings.placement_error("ash_beacon", c, false), "")


func test_beacon_fuel_and_threat() -> void:
	var sim := _sim()
	var b := _place(sim, "ash_beacon")
	assert_near(Decoy.threat_now(b), 5.0, 0.1)  # unlit = 25%
	assert_eq(b.add_input("waste", 2), 2)
	assert_eq(b.add_input("essence_ore", 1), 0)
	sim.step()
	assert_near(Decoy.threat_now(b), 20.0, 0.1)
	sim.run_ticks(299)
	assert_eq(int(b.input.get("waste", 0)), 1, "second unit not yet burnt")
	sim.run_ticks(2)
	assert_eq(int(b.input.get("waste", 0)), 0)
	sim.run_ticks(300)
	assert_near(Decoy.threat_now(b), 5.0, 0.1)


func test_wall_absorbs_hp() -> void:
	var sim := _sim()
	var b := _place(sim, "penitent_wall")
	assert_near(Decoy.threat_now(b), 8.0, 0.01)
	sim.buildings.damage(b, 799.0)
	assert_false(b.destroyed)
	sim.buildings.damage(b, 1.0)
	assert_true(b.destroyed)


func test_bell_burst_and_cooldown() -> void:
	var sim := _sim()
	var b := _place(sim, "mourning_bell")
	var before := sim.items.count_stored("refined_essence")
	assert_near(Decoy.threat_now(b), 6.0, 0.01)
	assert_true(sim.trigger_bell(b.id))
	assert_near(Decoy.threat_now(b), 18.0, 0.01)
	assert_false(sim.trigger_bell(b.id), "no double trigger")
	var paid := before - sim.items.count_stored("refined_essence")
	assert_eq(paid + sim.ledger.get_count("decoy_essence_debt"), 4, "essence debited once (stock or debt)")
	sim.run_ticks(599)
	assert_near(Decoy.threat_now(b), 18.0, 0.01)
	sim.step()
	assert_near(Decoy.threat_now(b), 6.0, 0.01)
	assert_false(sim.trigger_bell(b.id), "cooldown")
	sim.run_ticks(1799)
	assert_false(sim.trigger_bell(b.id), "cooldown 1799")
	sim.step()
	assert_true(sim.trigger_bell(b.id))


func test_bell_debt_when_no_essence() -> void:
	var sim := _sim()
	var b := _place(sim, "mourning_bell")
	while sim.items.count_stored("refined_essence") > 0:
		sim.items.consume_stored("refined_essence", 1, b.cell)
	assert_true(sim.trigger_bell(b.id))
	assert_eq(sim.ledger.get_count("decoy_essence_debt"), 4)


func test_replay_equal_and_recorded() -> void:
	# Buildings are placed directly (no builders in an empty map), so compare two identical runs
	# and check that the bell goes through the command log (save/load replays that log).
	var hashes: Array[int] = []
	for i in 2:
		var sim := _sim()
		var b := _place(sim, "mourning_bell")
		sim.run_ticks(10)
		sim.trigger_bell(b.id)
		sim.run_ticks(300)
		assert_eq(sim.command_log.back()[1], "trigger_bell")
		hashes.append(SaveGame.state_hash(sim))
	assert_eq(hashes[0], hashes[1])


func test_data_models_and_defs() -> void:
	var d := Defs.get_default()
	for id in ["ash_beacon", "penitent_wall", "mourning_bell"]:
		assert_true(d.buildings.has(id) and d.buildings[id].has("threat") and d.buildings[id].has("repair_cost"))
