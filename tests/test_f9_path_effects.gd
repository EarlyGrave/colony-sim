extends TestCase
## F9W2: promised path effects (data/endings.json path_effects) are read by petition, threats and debt.


func _sim() -> Simulation:
	var d := peaceful_defs()
	d.balance["e1_enabled"] = true
	var sim := make_sim(5, false, 24, 24, d)
	sim.colonists.spawn(Vector2i(4, 4))
	sim.run_ticks(1)
	return sim


func test_no_path_is_identity() -> void:
	var sim := _sim()
	assert_eq(sim.endings.effect("wave_mult", 1.0), 1.0)
	assert_eq(sim.endings.effect("grace_days", 0.0), 0.0)
	assert_eq(sim.endings.effect("petition_fee_mult", 1.0), 1.0)


func test_submit_wave_and_grace() -> void:
	var sim := _sim()
	var base := sim.threats.raid_points(1)
	assert_true(sim.set_path("submit"))
	assert_eq(sim.endings.effect("grace_days", 0.0), 5.0)
	assert_near(sim.threats.raid_points(1), base * 1.2, 0.001)
	assert_eq(sim.endings.effect("petition_fee_mult", 1.0), 1.0)


func test_escape_halves_fee_to_80_percent() -> void:
	var sim := _sim()
	var before := sim.petition.required(1)
	assert_true(sim.set_path("escape"))
	var after := sim.petition.required(1)
	for item: String in before:
		assert_eq(int(after[item]), maxi(1, roundi(float(before[item]) * 0.8)), item)


func test_fight_and_remission_unchanged() -> void:
	var sim := _sim()
	var base := sim.threats.raid_points(1)
	var req := sim.petition.required(1)
	for p: String in ["fight", "remission"]:
		assert_true(sim.set_path(p))
		assert_near(sim.threats.raid_points(1), base, 0.0001)
		assert_eq(sim.petition.required(1), req)
		assert_eq(sim.endings.effect("grace_days", 0.0), 0.0)


func test_effect_survives_flag_roundtrip() -> void:
	var sim := _sim()
	sim.set_path("submit")
	var sim2 := _sim()
	sim2.quests.flags = sim.quests.flags.duplicate()
	assert_eq(sim2.endings.effect("wave_mult", 1.0), 1.2)
