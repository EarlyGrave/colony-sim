extends TestCase
## Save/load by command-log replay.


func _play(sim: Simulation) -> void:
	var scen := preload("res://tests/scenario.gd")
	var center := sim.map_center()
	sim.set_zone(center + Vector2i(-6, 2), "stockpile")
	sim.designate_mine(center + Vector2i(3, 3), true)
	var spot := scen.find_spot(sim, "turret", center + Vector2i(4, 0), 0)
	sim.place_building("turret", spot)
	sim.run_ticks(300)
	sim.set_rule("engineer_repairs", true)
	sim.set_alarm(true)
	sim.set_work_priority(sim.colonists.list[0].id, "mining", 0)
	sim.run_ticks(200)
	sim.set_alarm(false)
	sim.deconstruct(spot)
	sim.set_zone(center + Vector2i(-6, 2), "")
	sim.run_ticks(250)


func test_roundtrip_identical_state() -> void:
	var sim := make_sim(11, true, 24, 24, peaceful_defs())
	_play(sim)
	assert_gt(sim.command_log.size(), 6.0)
	var text := SaveGame.to_json(sim)
	var res := SaveGame.load_json(text, make_bus(), peaceful_defs())
	assert_true(res["ok"], str(res["error"]))
	var sim2: Simulation = res["sim"]
	_sims.append(sim2)
	assert_eq(sim2.tick, sim.tick)
	assert_eq(SaveGame.state_hash(sim2), SaveGame.state_hash(sim))
	# Both continue identically.
	sim.run_ticks(100)
	sim2.run_ticks(100)
	assert_eq(SaveGame.state_hash(sim2), SaveGame.state_hash(sim))


func test_version_mismatch_and_corrupt() -> void:
	var sim := make_sim(12, true, 24, 24, peaceful_defs())
	sim.run_ticks(10)
	var d := SaveGame.to_dict(sim)
	d["version"] = 999
	var res := SaveGame.load_dict(d, make_bus(), peaceful_defs())
	assert_false(res["ok"])
	assert_eq(res["error"], "version")
	assert_eq(SaveGame.load_json("not json", make_bus())["error"], "corrupt")
	assert_eq(SaveGame.load_dict({"version": 1}, make_bus())["error"], "corrupt")
	var d2 := SaveGame.to_dict(sim)
	d2["defs_hash"] = 1
	assert_eq(SaveGame.load_dict(d2, make_bus(), peaceful_defs())["error"], "defs_changed")


func test_replay_speed() -> void:
	var sim := make_sim(13, true, 24, 24, peaceful_defs())
	sim.run_ticks(2000)
	var t0 := Time.get_ticks_msec()
	var res := SaveGame.load_dict(SaveGame.to_dict(sim), make_bus(), peaceful_defs())
	var ms := Time.get_ticks_msec() - t0
	_sims.append(res["sim"])
	print("replay 2000 ticks: %d ms" % ms)
	assert_true(res["ok"])


func test_multi_item_crate_order_survives_save() -> void:
	var opts := {"crate": {"refined_essence": 30, "essence_ore": 40, "raw_food": 20}}  # unsorted on purpose
	var sim := Simulation.new(13, make_bus(), peaceful_defs(), opts)
	_sims.append(sim)
	sim.start_new_game()
	sim.run_ticks(50)
	var res := SaveGame.load_json(SaveGame.to_json(sim), make_bus(), peaceful_defs())
	assert_true(res["ok"], str(res["error"]))
	var sim2: Simulation = res["sim"]
	_sims.append(sim2)
	assert_eq(SaveGame.state_hash(sim2), SaveGame.state_hash(sim), "crate drop order identical after load")
