extends TestCase
## Meta-progression: legacy, start options, next batch, opts in saves.


func _dead_sim(seed_value := 3) -> Simulation:
	var sim := make_sim(seed_value, true, 24, 24, peaceful_defs())
	sim.run_ticks(sim.ticks_per_day * 2)
	return sim


func test_legacy_computed_and_signalled() -> void:
	var sim := _dead_sim()
	var got: Array = []
	sim.bus.run_ended.connect(func(s: Dictionary) -> void: got.append(s))
	sim.debt.legacy_points = 2
	sim.end_game("colonists_dead")
	assert_eq(got.size(), 1)
	var s: Dictionary = got[0]
	assert_eq(s["days"], sim.day())
	# days * 1 + 2 debt points, no contracts/perks
	assert_eq(s["legacy"], sim.day() + 2)
	assert_eq(sim.run_summary["legacy"], s["legacy"])


func test_unlocks_change_start_deterministically() -> void:
	var opts := {"start_rules": ["raid_engineer"], "start_xp": 40.0, "scout": 5,
		"crate": {"raw_food": 30}, "reveal_forecast": true}
	var a := Simulation.new(9, make_bus(), peaceful_defs(), opts)
	a.start_new_game()
	var b := Simulation.new(9, make_bus(), peaceful_defs(), opts)
	b.start_new_game()
	var plain := make_sim(9, true, 24, 24, peaceful_defs())
	assert_true(a.is_rule_on("raid_engineer"))
	assert_false(plain.is_rule_on("raid_engineer"))
	assert_true(a.contamination.revealed)
	assert_eq(SaveGame.state_hash(a), SaveGame.state_hash(b))
	assert_ne(SaveGame.state_hash(a), SaveGame.state_hash(plain))
	var designated := 0
	for y in a.map.height:
		for x in a.map.width:
			if a.map.is_mine_designated(Vector2i(x, y)):
				designated += 1
	assert_eq(designated, 5)
	a.dispose()
	b.dispose()


func test_meta_state_shop_and_opts() -> void:
	var m := MetaState.new()
	assert_eq(m.can_buy("scout"), "poor")
	m.record_run({"legacy": 20, "days": 5, "seed": 4, "contamination": 40.0})
	assert_true(m.buy("scout"))
	assert_true(m.buy("crate_food"))
	assert_false(m.buy("scout"))
	var o := m.make_opts()
	assert_eq(o["scout"], 12)
	assert_eq(int(o["crate"]["raw_food"]), 30)
	var m2 := MetaState.new()
	m2.load_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	assert_eq(m2.balance, m.balance)
	assert_eq(m2.owned, m.owned)


func test_next_batch_keeps_planet_reduces_contamination() -> void:
	var m := MetaState.new()
	m.record_run({"legacy": 3, "days": 5, "seed": 11, "contamination": 60.0})
	assert_true(m.can_next_batch())
	var nb := m.make_next_batch()
	assert_eq(nb["seed"], 11)
	assert_near(float(nb["opts"]["contamination"]), 30.0, 0.001)
	var a := Simulation.new(11, make_bus(), peaceful_defs(), nb["opts"])
	a.start_new_game()
	var base := make_sim(11, true, 24, 24, peaceful_defs())
	assert_eq(a.map.checksum(), base.map.checksum())
	assert_near(a.contamination.level, 30.0, 0.001)
	assert_lt(a.contamination.level, 60.0)
	a.dispose()


func test_opts_survive_save_load() -> void:
	var opts := {"start_rules": ["ore_reserve"], "scout": 4, "crate": {"raw_food": 10},
		"contamination": 12.5, "site": 2, "start_xp": 40.0}
	var sim := Simulation.new(5, make_bus(), peaceful_defs(), opts)
	sim.start_new_game()
	sim.run_ticks(50)
	var json := SaveGame.to_json(sim)
	var res := SaveGame.load_json(json, make_bus(), peaceful_defs())
	assert_true(res["ok"], str(res["error"]))
	var loaded: Simulation = res["sim"]
	assert_eq(SaveGame.state_hash(loaded), SaveGame.state_hash(sim))
	assert_eq(loaded.opts["site"], 2)
	assert_true(loaded.is_rule_on("ore_reserve"))
	sim.dispose()
	loaded.dispose()
