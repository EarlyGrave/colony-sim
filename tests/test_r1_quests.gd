extends TestCase
## R1: Q10 Maintenance Window + Q3 Parole Board (data quests).


func _sim(seed_value := 5, refined := 0) -> Simulation:
	var d := peaceful_defs()
	d.balance["q_enabled"] = true
	var sim := make_sim(seed_value, true, 24, 24, d)
	var at := sim.map_center() + Vector2i(3, 3)
	sim.set_zone(at, "stockpile")
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			sim.set_zone(sim.map_center() + Vector2i(dx, dy), "stockpile")
	sim.ledger.record_produced("raw_food", 900, "test")
	sim.items.drop(at, "raw_food", 900)
	if refined > 0:
		sim.ledger.record_produced("refined_essence", refined, "test")
		sim.items.drop(at, "refined_essence", refined)
	sim.run_ticks(1)
	return sim


func _days(sim: Simulation, n: float) -> void:
	sim.run_ticks(int(n * sim.ticks_per_day) + 1)


## Starts the quest and advances until its choice is pending.
func _to_choice(sim: Simulation, qid: String) -> Dictionary:
	assert_true(sim.quests.start(qid))
	var g := 0
	while sim.quests.pending_for(qid).is_empty() and g < 5 * sim.ticks_per_day:
		sim.step()
		g += 1
	return sim.quests.pending_for(qid)


func test_defs_load() -> void:
	var d := Defs.get_default()
	assert_true(d.quests.has("q10_maintenance"))
	assert_true(d.quests.has("q3_parole_board"))


func test_q10_trigger_needs_flag_and_day() -> void:
	var sim := _sim()
	var t: Dictionary = sim.defs.quests["q10_maintenance"]["trigger"]
	assert_false(sim.quests._trigger_ok(t))
	sim.quests.set_flag("installment_missed")
	assert_false(sim.quests._trigger_ok(t), "day < 40")


func test_installment_missed_flag_set_by_debt() -> void:
	var sim := _sim()
	assert_false(sim.quests.flag("installment_missed"))
	var cfg: Dictionary = sim.defs.debt
	_days(sim, float(int(cfg["due_days"]) + int(cfg["grace_days"]) + 3))
	assert_true(sim.quests.flag("installment_missed"))


func test_q10_pa_silent_then_apology() -> void:
	var sim := _sim()
	sim.quests.start("q10_maintenance")
	assert_true(sim.milestones.pa_silent())
	assert_true(sim.quests.pending_for("q10_maintenance").is_empty())
	_days(sim, 0.3)
	assert_false(sim.milestones.pa_silent())
	assert_false(sim.quests.pending_for("q10_maintenance").is_empty())


func test_q10_raid() -> void:
	var sim := _sim()
	var p := _to_choice(sim, "q10_maintenance")
	assert_true(sim.answer_quest(int(p["uid"]), "raid"))
	sim.run_ticks(2)
	assert_true(sim.items.count_stored("refined_essence") >= 30)
	assert_true(sim.items.count_stored("parts") >= 10)
	assert_eq(sim.quests.mod("audit_parts_mult"), 1.2)
	assert_eq(sim.quests.state("q10_maintenance"), "done")


func test_q10_respect() -> void:
	var sim := _sim()
	var p := _to_choice(sim, "q10_maintenance")
	assert_true(sim.answer_quest(int(p["uid"]), "respect"))
	assert_true(sim.quests.flag("clue_warden_quota"))
	assert_eq(sim.quests.state("q10_maintenance"), "done")


func test_q10_sabotage_blocks_audits_and_letters() -> void:
	var sim := _sim()
	var p := _to_choice(sim, "q10_maintenance")
	assert_true(sim.answer_quest(int(p["uid"]), "sabotage"))
	assert_true(sim.milestones.pa_silent())
	assert_eq(sim.quests.mod("petition_fee_mult"), 0.8)
	assert_eq(sim.quests.mod("wave_mult"), 1.1)
	assert_false(sim.milestones.deliver(2), "audits blocked")
	var letters: Array = []
	sim.bus.letter_received.connect(func(t: String, _x: String) -> void: letters.append(t))
	sim.quests._apply_effects("q10_maintenance", [{"verb": "letter", "text": "x"}])
	assert_eq(letters.size(), 0, "letters blocked")
	_days(sim, 3.2)
	assert_false(sim.milestones.pa_silent())
	sim.quests._apply_effects("q10_maintenance", [{"verb": "letter", "text": "x"}])
	assert_eq(letters.size(), 1)


func test_q3_trigger() -> void:
	var sim := _sim()
	var t: Dictionary = sim.defs.quests["q3_parole_board"]["trigger"]
	assert_false(sim.quests._trigger_ok(t))
	sim.milestones.reviews_done.append("x")
	assert_true(sim.quests._trigger_ok(t))


func test_q3_sponsor() -> void:
	var sim := _sim(5, 25)
	var p := _to_choice(sim, "q3_parole_board")
	var before := sim.items.count_stored("refined_essence")
	assert_true(sim.answer_quest(int(p["uid"]), "sponsor"))
	sim.run_ticks(2)
	assert_eq(before - sim.items.count_stored("refined_essence"), 20)
	assert_true(sim.quests.flag("review_sponsored"))
	assert_eq(sim.quests.mod("petition_fee_mult"), 1.1)


func test_q3_decline_when_poor() -> void:
	var sim := _sim(5, 5)
	var p := _to_choice(sim, "q3_parole_board")
	assert_false(sim.answer_quest(int(p["uid"]), "sponsor"), "cannot afford")
	assert_true(sim.answer_quest(int(p["uid"]), "decline"))
	assert_eq(sim.quests.state("q3_parole_board"), "done")
	assert_eq(sim.quests.mod("petition_fee_mult"), 1.0)


func test_q3_bribe() -> void:
	var sim := _sim(5, 12)
	var p := _to_choice(sim, "q3_parole_board")
	assert_true(sim.answer_quest(int(p["uid"]), "bribe"))
	assert_true(sim.quests.flag("audit_dates_known"))
	assert_eq(sim.quests.mod("audit_parts_mult"), 0.8)


func test_q3_hint_shows_cost_vs_installment() -> void:
	var o: Dictionary = Defs.get_default().quests["q3_parole_board"]["beats"]["offer"]["options"]["sponsor"]
	assert_true(String(o["hint"]).contains("installments of 4"))


func _run_hash(seed_value: int) -> int:
	var sim := _sim(seed_value, 25)
	var p := _to_choice(sim, "q3_parole_board")
	sim.answer_quest(int(p["uid"]), "sponsor")
	_days(sim, 2)
	return SaveGame.state_hash(sim)


func test_replay_hash_equal() -> void:
	assert_eq(_run_hash(9), _run_hash(9))
