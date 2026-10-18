extends TestCase
## K2: preset-scaled reviews, outpost step, audit decoy, flag-off parity.


func _sim(on: bool, preset: String) -> Simulation:
	var d := peaceful_defs()
	d.balance["k2_enabled"] = on
	var sim := make_sim(3, false, 24, 24, d)
	sim.milestones.k2_preset = preset
	return sim


func _vals(sim: Simulation) -> Array:
	var out: Array = []
	for r: Dictionary in sim.milestones.review_defs():
		out.append([str(r["kind"]), int(r["value"])])
	return out


func test_flag_default_on_and_parity() -> void:
	assert_true(bool(Defs.get_default().balance["k2_enabled"]))
	var a := _sim(false, "hard_time")
	assert_eq(a.milestones.review_defs().size(), 3)
	assert_eq(a.milestones.review_defs()[1]["value"], 2.0)
	a.milestones.k2_note_day(1)
	assert_eq(a.milestones.k2_outpost_days, 0)


func test_demand_table() -> void:
	assert_eq(_vals(_sim(true, "short_stay")), [["debt_paid_pct", 8], ["waves_repelled", 1], ["debt_paid_pct", 14]])
	assert_eq(_vals(_sim(true, "standard_term")).size(), 4)
	var h := _vals(_sim(true, "hard_time"))
	assert_eq(h[0], ["debt_paid_pct", 10])
	assert_eq(h[1], ["waves_repelled", 3])
	assert_eq(h[3], ["outpost_days", 2])


func test_outpost_step_blocks_then_clears() -> void:
	var sim := _sim(true, "standard_term")
	var m := sim.milestones
	m.reviews_done = ["review_1", "review_2", "review_3"]
	assert_eq(str(m.current_review()["id"]), "review_outpost")
	assert_eq(m.review_progress(m.current_review()), 0.0)
	m.k2_note_day(1)
	m.k2_note_day(1)
	assert_eq(m.review_progress(m.current_review()), 1.0)


func test_decoy_absorbs_one_audit() -> void:
	var sim := _sim(true, "hard_time")
	var m := sim.milestones
	assert_false(m.k2_consume_decoy())
	m.k2_note_day(1)
	m.k2_note_day(1)
	assert_true(m.k2_essence_exempt())
	assert_true(m.k2_consume_decoy())
	assert_false(m.k2_consume_decoy())


func _preset_sim(id: String, threats: bool) -> Simulation:
	var d := peaceful_defs() if not threats else Defs.get_default().duplicate_defs()
	var sim := Simulation.new(3, make_bus(), d, StartOpts.preset_opts(d, id))
	sim.start_empty(24, 24)
	_sims.append(sim)
	return sim


func test_preset_id_wired_from_opts_and_texts() -> void:
	var sim := _preset_sim("hard_time", false)
	assert_eq(sim.milestones.k2_preset_id(), "hard_time")
	assert_true(sim.milestones.outpost_step_text().begins_with("Outpost step"))
	assert_true(sim.milestones.k2_demand_text().contains("3 waves"))


func test_decoy_skips_home_audit() -> void:
	var sim := _preset_sim("standard_term", true)
	sim.milestones.k2_note_day(1)
	sim.tick = sim.threats.next_audit_tick()
	sim.threats._k1_tick(false)
	assert_eq(sim.threats.wave_index, 0)
	assert_eq(sim.milestones.k2_decoys, 0)
	sim.tick = sim.threats.next_audit_tick()
	sim.threats._k1_tick(false)
	assert_eq(sim.threats.wave_index, 1)
