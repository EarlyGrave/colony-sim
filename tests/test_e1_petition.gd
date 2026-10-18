extends TestCase
## E1: Sentence Commutation Petition (gated by balance "e1_enabled").


func _sim(on: bool = true, seed_value: int = 5) -> Simulation:
	var d := peaceful_defs()
	d.balance["e1_enabled"] = on
	var sim := make_sim(seed_value, false, 24, 24, d)
	sim.colonists.spawn(Vector2i(4, 4))
	for x in 8:
		sim.set_zone(Vector2i(6 + x, 6), "stockpile")
		sim.set_zone(Vector2i(6 + x, 7), "stockpile")
	sim.buildings.place("warden_terminal", Vector2i(10, 10), false)
	sim.run_ticks(1)  # debt states are assigned on the first tick
	sim.milestones.done_tiers = [0, 1, 2]
	return sim


func _stock(sim: Simulation, item: String, n: int) -> void:
	sim.ledger.record_produced(item, n, "test")
	sim.items.drop(Vector2i(6 + (item.length() % 8), 6 + (item.length() % 2)), item, n)


func test_off_by_default_and_tier3_wall_stays() -> void:
	assert_false(bool(Defs.get_default().balance["e1_enabled"]))
	var sim := _sim(false)
	assert_eq(sim.milestones.next_tier(), 3)
	assert_false(sim.deliver_petition(1))


func test_tier3_wall_gone_when_on() -> void:
	var sim := _sim()
	assert_eq(sim.milestones.next_tier(), -1)
	assert_false(sim.deliver_audit(3))


func test_locked_before_tier2() -> void:
	var sim := _sim()
	sim.milestones.done_tiers = [0, 1]
	_stock(sim, "plate", 60)
	_stock(sim, "parts", 20)
	assert_false(sim.deliver_petition(1))


func test_staged_and_partial() -> void:
	var sim := _sim()
	assert_false(sim.deliver_petition(2), "phases are sequential")
	_stock(sim, "plate", 40)
	assert_false(sim.deliver_petition(1))
	assert_eq(sim.petition.remaining(1)["plate"], 20)
	assert_eq(sim.petition.remaining(1)["parts"], 20)
	assert_eq(sim.items.count_stored("plate"), 0)
	_stock(sim, "plate", 30)
	_stock(sim, "parts", 25)
	var phases: Array = []
	sim.bus.petition_phase_done.connect(func(p: int) -> void: phases.append(p))
	assert_true(sim.deliver_petition(1))
	assert_eq(phases, [1])
	assert_eq(sim.items.count_stored("plate"), 10, "exact consumption")
	assert_eq(sim.items.count_stored("parts"), 5)
	assert_eq(sim.petition.next_phase(), 2)


func test_rewards_and_tier3_via_p3() -> void:
	var sim := _sim()
	var st: DebtState = sim.debt.state_of(sim.colonists.list[0])
	var before := st.remaining()
	_stock(sim, "plate", 60)
	_stock(sim, "parts", 20)
	assert_true(sim.deliver_petition(1))
	assert_lt(st.remaining(), before)
	_stock(sim, "ingot_iron", 20)
	_stock(sim, "ingot_copper", 20)
	assert_true(sim.deliver_petition(2))
	assert_false(sim.milestones.is_tier_done(3))
	_stock(sim, "coal", 30)
	_stock(sim, "nitrogen", 20)
	assert_true(sim.deliver_petition(3))
	assert_true(sim.milestones.is_tier_done(3))
	assert_eq(sim.petition.state()["done"], 3)


func test_preset_scaling() -> void:
	var sim := _sim()
	sim.opts["preset_id"] = "hard_time"
	assert_eq(sim.petition.required(1)["plate"], 78)
	sim.opts["preset_id"] = "short_stay"
	assert_eq(sim.petition.required(1)["plate"], 36)


func _run(seed_value: int) -> Simulation:
	var sim := _sim(true, seed_value)
	_stock(sim, "plate", 40)
	sim.deliver_petition(1)
	sim.run_ticks(10)
	return sim


func test_save_load_replay_and_determinism() -> void:
	var a := _run(7)
	var b := _run(7)
	assert_eq(SaveGame.state_hash(a), SaveGame.state_hash(b))
	assert_true(a.petition.has_state())
	assert_eq(a.petition.delivered[1]["plate"], 40)
