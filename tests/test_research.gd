extends TestCase
## Research core: tech data, gating, progress, queue, cost/refund, save/replay.


func _locked_sim(seed_value := 3) -> Simulation:
	var sim := make_sim(seed_value, true, 24, 24, peaceful_defs())
	sim.research.gating = true
	return sim


func _give_essence(sim: Simulation, n: int) -> void:
	var item := "refined_essence"
	sim.ledger.record_produced(item, n, "test")
	var left := n
	for y in range(0, 3):  # empty cells of the 4x4 start stockpile
		for x in range(3, 7):
			var c := sim.map_center() + Vector2i(x, y)
			if left > 0 and not sim.items.stacks.has(c):
				var put := mini(left, sim.items.space_for(c, item))
				left -= sim.items.add_at(c, item, put)
	assert_eq(left, 0, "stockpile room for test essence")


func _spot(sim: Simulation, def_id: String) -> Vector2i:
	var scen := preload("res://tests/scenario.gd")
	return scen.find_spot(sim, def_id, sim.map_center() + Vector2i(5, 5), 0)


func test_data_valid_and_counts() -> void:
	var d := Defs.get_default()
	assert_eq(d.research.size(), 15)
	assert_eq(Tech.validate(d.research, d).size(), 0, str(Tech.validate(d.research, d)))
	var per_tier := [0, 0, 0, 0]
	for id: String in d.research:
		per_tier[int(d.research[id]["tier"])] += 1
	assert_eq(per_tier, [4, 4, 3, 4])


func test_cycle_and_bad_ids_rejected() -> void:
	var d := Defs.get_default().duplicate_defs()
	d.research["hand_tools"]["prereqs"] = ["drilling"]  # drilling needs hand_tools
	assert_true(Tech.has_cycle(d.research))
	assert_gt(float(Tech.validate(d.research, d).size()), 0.0)
	var d2 := Defs.get_default().duplicate_defs()
	d2.research["assembly"]["unlocks"]["buildings"] = ["nope"]
	assert_gt(float(Tech.validate(d2.research, d2).size()), 0.0)


func test_default_sim_everything_unlocked() -> void:
	var sim := make_sim(1, true, 24, 24, peaceful_defs())
	assert_true(sim.research.building_unlocked("assembler"))
	assert_false(sim.research.gating)


func test_locked_assembler_then_unlocked() -> void:
	var sim := make_sim(3, true, 24, 24, peaceful_defs())
	var c := _spot(sim, "assembler")
	sim.research.gating = true
	assert_eq(sim.buildings.placement_error("assembler", c, false), "locked: assembly")
	assert_eq(sim.buildings.placement_error("smelter", c, false).begins_with("locked"), false, "T1 starts unlocked")
	assert_true(sim.research.tier_unlocked(1))
	assert_false(sim.research.tier_unlocked(2))
	# T2 needs the tier audit, essence, then bench work.
	assert_eq(sim.research.lock_reason("assembly"), "tier audit T2")
	sim.research.unlock_tier(2)
	assert_eq(sim.research.lock_reason("assembly"), "")
	_give_essence(sim, 20)
	assert_true(sim.set_research("assembly"))
	assert_eq(sim.research.add_progress(2999.0), "")
	assert_eq(sim.buildings.placement_error("assembler", c, false), "locked: assembly")
	assert_eq(sim.research.add_progress(1.0), "assembly")
	assert_eq(sim.buildings.placement_error("assembler", c, false), "")
	assert_true(sim.research.recipe_unlocked("make_plate"))


func test_exact_completion_ticks() -> void:
	var sim := _locked_sim()
	assert_false(sim.set_research("hand_tools"), "start tech already done")
	sim.research.unlock_tier(2)
	_give_essence(sim, 10)
	assert_true(sim.set_research("filters"))
	var cost := sim.research.bench_ticks("filters")
	var finished_at := -1
	for i in cost + 5:
		if sim.research.add_progress(1.0) != "":
			finished_at = i + 1
			break
	assert_eq(finished_at, cost)
	assert_true(sim.research.is_done("filters"))
	assert_true(sim.research.rule_unlocked("refine_cap"))
	assert_eq(sim.research.active(), "")


func test_rule_gated() -> void:
	var sim := _locked_sim()
	sim.set_rule("refine_cap", true)
	assert_false(sim.is_rule_on("refine_cap"))


func test_queue_order_and_prereq_active() -> void:
	var sim := _locked_sim()
	sim.research.unlock_tier(2)
	sim.research.unlock_tier(3)
	_give_essence(sim, 200)
	assert_true(sim.queue_research("mass_assembly", true))  # prereqs missing: queued, not active
	assert_true(sim.queue_research("filters", true))
	assert_true(sim.queue_research("assembly", true))
	assert_eq(sim.research.queue, ["mass_assembly", "filters", "assembly"] as Array[String])
	assert_eq(sim.research.active(), "filters")
	assert_true(sim.set_research("assembly"))
	assert_eq(sim.research.queue, ["assembly", "mass_assembly", "filters"] as Array[String])
	assert_false(sim.queue_research("hand_tools", true), "already done")
	assert_false(sim.queue_research("nope", true))


func test_essence_spend_and_exact_refund() -> void:
	var sim := _locked_sim()
	sim.research.unlock_tier(2)
	assert_false(sim.queue_research("assembly", true), "no essence")
	_give_essence(sim, 25)
	var before := sim.items.count_stored("refined_essence")
	assert_true(sim.queue_research("assembly", true))
	assert_eq(sim.items.count_stored("refined_essence"), before - 20)
	assert_true(sim.queue_research("assembly", false))
	assert_eq(sim.items.count_stored("refined_essence"), before, "refund exact")
	assert_eq(sim.ledger.balance_of("refined_essence"), sim.items.count_world("refined_essence"))
	# After progress, cancelling does not refund and re-queue does not re-pay.
	assert_true(sim.queue_research("assembly", true))
	sim.research.add_progress(10.0)
	assert_true(sim.queue_research("assembly", false))
	assert_eq(sim.items.count_stored("refined_essence"), before - 20)
	assert_true(sim.queue_research("assembly", true))
	assert_eq(sim.items.count_stored("refined_essence"), before - 20)
	assert_near(sim.research.progress_of("assembly"), 10.0, 0.001)


func test_waste_multiplier() -> void:
	var sim := _locked_sim()
	assert_near(sim.research.waste_multiplier(), 1.0, 0.0001)
	sim.research.unlock_tier(2)
	sim.research.unlock_tier(3)
	sim.research.done.append("bulk_refining")
	assert_near(sim.research.waste_multiplier(), 1.5, 0.0001)


func test_save_load_mid_research_and_replay() -> void:
	var defs := peaceful_defs()
	defs.research["filters"]["cost"]["essence"] = 0
	var opts := {"research_locked": true, "research_audit_tiers": [2]}
	var sim := Simulation.new(5, make_bus(), defs, opts)
	_sims.append(sim)
	sim.start_new_game()
	sim.run_ticks(20)
	assert_true(sim.set_research("filters"))
	assert_true(sim.queue_research("assembly", true) == false, "needs essence")
	sim.run_ticks(30)
	sim.research.add_progress(123.5)
	sim.run_ticks(10)
	var res := SaveGame.load_json(SaveGame.to_json(sim), make_bus(), defs)
	assert_true(res["ok"], str(res["error"]))
	var sim2: Simulation = res["sim"]
	_sims.append(sim2)
	assert_true(sim2.research.gating, "opts survive save")
	assert_true(sim2.research.tier_unlocked(2))
	assert_eq(sim2.research.queue, sim.research.queue)
	# Operator progress is not a command: re-apply it, then states must match.
	sim2.research.add_progress(123.5)
	assert_eq(SaveGame.state_hash(sim2), SaveGame.state_hash(sim))
	sim.run_ticks(40)
	sim2.run_ticks(40)
	assert_eq(SaveGame.state_hash(sim2), SaveGame.state_hash(sim))


func test_state_hash_includes_research() -> void:
	var a := _locked_sim(7)
	var b := _locked_sim(7)
	assert_eq(SaveGame.state_hash(a), SaveGame.state_hash(b))
	a.research.unlock_tier(2)
	_give_essence(a, 20)
	_give_essence(b, 20)
	a.set_research("assembly")
	assert_ne(SaveGame.state_hash(a), SaveGame.state_hash(b))


func test_waste_multiplier_applies_to_batches() -> void:
	# Hand refinery: 4 waste/batch * 1.25 (high_throughput) = 5 exactly.
	var base := make_sim(1, false, 24, 24, peaceful_defs())
	var tech := make_sim(1, false, 24, 24, peaceful_defs())
	tech.research.done.append("high_throughput")
	var outs: Array = []
	for s: Simulation in [base, tech]:
		var m := s.buildings.place("refinery", Vector2i(8, 8), false)
		m.add_input("essence_ore", 10)
		m.progress = 99
		assert_true(s.buildings.work(m, 1, null))
		outs.append(int(m.output.get("waste", 0)))
	assert_eq(outs[0], 4, "base waste")
	assert_eq(outs[1], 5, "waste with high_throughput")
	# Smelter: 1 waste/batch * 1.5 (bulk_refining) averages 1.5 over many batches, deterministically.
	var totals: Array = []
	for t in 2:
		var s := make_sim(1, false, 24, 24, peaceful_defs())
		if t == 1:
			s.research.done.append("bulk_refining")
		var m := s.buildings.place("smelter", Vector2i(8, 8), false)
		var waste := 0
		for i in 60:
			m.add_input("copper_ore", 2)
			s.run_ticks(int(s.defs.recipes["smelt_copper"]["work_ticks"]) + 5)
			waste += int(m.output.get("waste", 0))
			m.output.clear()
		totals.append([waste, s.buildings.refined_batches])
	var b0: int = totals[0][1]
	var b1: int = totals[1][1]
	assert_true(b0 > 30 and b1 > 30, "enough batches ran")
	assert_eq(totals[0][0], b0, "smelter base waste = 1/batch")
	var ratio := float(totals[1][0]) / float(b1)
	assert_true(ratio > 1.3 and ratio < 1.7, "smelter waste ~1.5x per batch, got %f" % ratio)


func test_fresh_locked_game_has_t0_t1_content() -> void:
	var sim := Simulation.new(5, make_bus(), peaceful_defs(), {"research_locked": true})
	_sims.append(sim)
	sim.start_new_game()
	for b in ["research_bench", "workbench", "refinery", "miner", "belt", "smelter", "storage_in", "wall", "turret"]:
		assert_true(sim.research.building_unlocked(b), b + " buildable at start")
	assert_false(sim.research.building_unlocked("assembler"), "T2 stays locked")
