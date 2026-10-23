extends TestCase
## F11W5: bot passive_pick (tools/factory_bot.gd region F11W5), env knobs default OFF, combat_model passive rows.
const FactoryBot := preload("res://tools/factory_bot.gd")
const CombatModel := preload("res://tools/combat_model.gd")


func _on_defs(passives: bool) -> Defs:
	var d := Defs.new()
	d.load_from(Defs.DATA_DIR)
	d.balance["passives_v2_enabled"] = passives
	return d


func _grant(sim: Simulation, c: Colonist, n: int) -> void:
	if sim.has_method("grant_passive_marks"):
		sim.call("grant_passive_marks", c.id, n, "test")
	else:
		sim.passives.tree.earn(sim.passives.state_of(c), n)


func _sim(passives: bool, seed_value := 5) -> Simulation:
	var sim := Simulation.new(seed_value, make_bus(), _on_defs(passives))
	sim.start_new_game()
	_sims.append(sim)
	return sim


func test_env_knobs_default_off() -> void:
	var d := _on_defs(false)
	d.balance["traits_v3_enabled"] = false
	FactoryBot.f11_apply_env(d)
	assert_false(bool(d.balance["passives_v2_enabled"]), "no env -> passives flag unchanged")
	assert_false(bool(d.balance["traits_v3_enabled"]), "no env -> traits flag unchanged")
	assert_false(bool(Defs.get_default().balance.get("passives_v2_enabled", false)), "shipped flag stays false")
	assert_false(bool(Defs.get_default().balance.get("traits_v3_enabled", false)), "shipped flag stays false")


func test_pick_noop_when_flag_off() -> void:
	var sim := _sim(false)
	assert_eq(FactoryBot.f11_pick(sim), 0, "flag off: nothing allocated")
	var st: Dictionary = FactoryBot.f11_stats(sim)
	assert_eq(int(st["earned"]), 0)
	assert_eq(int(st["inmates"]), 0)


func test_pick_spends_marks_through_commands() -> void:
	var sim := _sim(true)
	var c: Colonist = sim.colonists.list[0]
	c.skills.levels["mining"] = 6
	_grant(sim, c, 8)
	var n := FactoryBot.f11_pick(sim)
	assert_gt(float(n), 0.0, "bot allocated something")
	var st = sim.passives.state_of(c)
	assert_true(st.marks_free() >= 0, "never overspends")
	assert_true(st.marks_spent >= 6, "spends most of 8 marks (gate permitting): %d" % st.marks_spent)


func test_pick_keystones_respect_cap_and_excludes() -> void:
	var sim := _sim(true)
	var c: Colonist = sim.colonists.list[0]
	for sk: String in c.skills.levels:
		c.skills.levels[sk] = 3
	c.skills.levels["shooting"] = 9
	_grant(sim, c, 60)
	FactoryBot.f11_pick(sim)
	var tree := PassiveTreeV2.new(PassiveTreeV2.load_default())
	var st = sim.passives.state_of(c)
	var ks := tree.keystones_of(st)
	assert_true(ks.size() <= 2, "at most 2 keystones")
	for k in ks:
		for x in tree.excludes_of(k):
			assert_false(st.allocated.has(x), "no excluded pair %s/%s" % [k, x])


func test_pick_is_deterministic() -> void:
	var hashes: Array[String] = []
	for i in 2:
		var sim := _sim(true, 7)
		var c: Colonist = sim.colonists.list[0]
		c.skills.levels["crafting"] = 7
		_grant(sim, c, 12)
		FactoryBot.f11_pick(sim)
		hashes.append(",".join(sim.passives.state_of(c).allocated))
	assert_eq(hashes[0], hashes[1], "same seed, same picks")
	assert_true(hashes[0] != "", "picked something")


func test_combat_model_rows() -> void:
	assert_near(CombatModel.short_fuse_mult(20.0), 1.30, 0.001)
	assert_near(CombatModel.short_fuse_mult(50.0), 1.00, 0.001)
	assert_near(CombatModel.short_fuse_mult(80.0), 0.75, 0.001)
	assert_near(CombatModel.short_fuse_mult(0.0), 1.50, 0.001)
	var defs := Defs.get_default()
	var dm := CombatModel.dead_man_row(defs, 3, 5.0)
	assert_near(float(dm["survive"]), 1.0 / 0.7, 0.001)
	assert_gt(float(dm["dps"]), 1.0)
	var fa := CombatModel.full_auto_row(8)
	assert_near(float(fa["dps"]), 1.25, 0.001)
	assert_gt(float(fa["taken"]), 1.0)
	var ap := CombatModel.armourers_row(defs, "burrower", 3, 5.0)
	assert_gt(float(ap["survive"]), 1.0, "doubled armour lasts longer")


func test_passive_rows_cover_all_and_flag_outliers() -> void:
	var rows := CombatModel.passive_rows()
	assert_eq(rows.size(), 90, "all 90 passives valued")
	var flagged := 0
	for r: Dictionary in rows:
		if r["outlier"]:
			flagged += 1
			assert_true(float(r["per_mark"]) > 1.5 * float(r["median"]))
	assert_gt(float(flagged), 0.0, "table has outliers to report")
