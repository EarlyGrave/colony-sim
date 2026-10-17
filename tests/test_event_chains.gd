extends TestCase
## Storyteller chains + prison events: delayed follow-ups, conditions, choices,
## ledger conservation, determinism, save/load replay, wave complications.


func _defs() -> Defs:
	var d := peaceful_defs()
	d.balance["storyteller"]["chance"] = 0.0  # events are fired by hand
	d.event_chains["random_enabled"] = false
	return d


func _sim(seed_value := 4) -> Simulation:
	var sim := make_sim(seed_value, false, 24, 24, _defs())
	sim.colonists.spawn(Vector2i(4, 4))
	sim.colonists.spawn(Vector2i(5, 4))
	sim.set_zone(Vector2i(6, 6), "stockpile")
	sim.set_zone(Vector2i(6, 7), "stockpile")
	sim.run_ticks(1)  # debts are assigned on the first tick
	return sim


func _stock(sim: Simulation, item: String, n: int) -> void:
	sim.ledger.record_produced(item, n, "test")
	sim.items.drop(Vector2i(6, 6), item, n)


func _says(sim: Simulation, out: Array) -> void:
	sim.listen(sim.bus.story_event, func(id: String, _t: String) -> void: out.append(id))


func test_followup_fires_after_delay() -> void:
	var sim := _sim()
	var said: Array = []
	_says(sim, said)
	assert_true(sim.storyteller.fire("inspection_notice"))
	assert_true(said.has("inspection_notice"))
	assert_false(said.has("inspection_arrive"))
	sim.run_ticks(int(1.5 * sim.ticks_per_day))
	assert_false(said.has("inspection_arrive"), "not before the delay")
	sim.run_ticks(int(0.6 * sim.ticks_per_day))
	assert_true(said.has("inspection_arrive"), "after the delay")
	assert_true(sim.storyteller.chain_queue.is_empty())


func test_inspection_condition_reward_vs_punishment() -> void:
	var rich := _sim()
	_stock(rich, "refined_essence", 30)
	var meals := rich.items.count_world("meal")
	rich.storyteller.run_step("inspection_arrive")
	assert_gt(float(rich.items.count_world("meal")), float(meals), "reward supplies")
	var poor := _sim()
	poor.storyteller.run_step("inspection_arrive")
	assert_eq(poor.items.count_world("meal"), 0, "no reward")
	assert_gt(poor.contracts.anger, 0.0, "anger up")
	assert_gt(poor.contracts.next_raid_mult, 1.0, "sanction")


func test_inspection_uses_contract_quota() -> void:
	var sim := _sim()
	sim.run_ticks(int(sim.defs.contracts["first_offer_day"]) * sim.ticks_per_day)
	var c: Dictionary = sim.contracts.list[0]
	sim.contracts.accept(int(c["id"]))
	assert_gte_int(sim.storyteller.quota_essence(), int(c["essence"]))


func assert_gte_int(a: int, b: int) -> void:
	assert_true(a >= b, "%d >= %d" % [a, b])


func test_smuggler_choice_sell_changes_state_and_ledger() -> void:
	var sim := _sim()
	_stock(sim, "refined_essence", 12)
	sim.storyteller.run_step("smuggler_offer")
	assert_eq(sim.storyteller.pending.size(), 1)
	var uid := int(sim.storyteller.pending[0]["uid"])
	assert_true(sim.answer_event(uid, true))
	assert_eq(sim.items.count_world("refined_essence"), 7)
	assert_eq(sim.items.count_world("machine_parts"), 2)
	assert_gt(sim.contracts.anger, 0.0, "wardens suspicious")
	assert_eq(sim.ledger.balance_of("refined_essence"), sim.items.count_world("refined_essence"))
	assert_eq(sim.ledger.balance_of("meal"), sim.items.count_world("meal"))
	assert_true(sim.storyteller.pending.is_empty())


func test_smuggler_decline_and_timeout_change_nothing() -> void:
	var sim := _sim()
	_stock(sim, "refined_essence", 12)
	sim.storyteller.run_step("smuggler_offer")
	assert_true(sim.answer_event(int(sim.storyteller.pending[0]["uid"]), false))
	assert_eq(sim.items.count_world("refined_essence"), 12)
	assert_eq(sim.contracts.anger, 0.0)
	sim.storyteller.run_step("smuggler_offer")
	sim.run_ticks(int(sim.defs.arrivals["choice_timeout_ticks"]) + 5)
	assert_true(sim.storyteller.pending.is_empty(), "expired")
	assert_eq(sim.items.count_world("refined_essence"), 12)


func test_smuggler_without_stock_fails_gracefully() -> void:
	var sim := _sim()
	sim.storyteller.run_step("smuggler_offer")
	assert_true(sim.answer_event(int(sim.storyteller.pending[0]["uid"]), true))
	assert_eq(sim.items.count_world("machine_parts"), 0)


func test_new_prisoners_get_debts() -> void:
	var sim := _sim()
	var before := sim.colonists.alive_count()
	assert_true(sim.storyteller.fire("new_prisoners"))
	assert_gt(float(sim.colonists.alive_count()), float(before))
	for c in sim.colonists.list:
		if c.id > 2:
			assert_true(sim.debt.state_of(c) != null, "debt assigned")


func test_rumors_raise_despair_and_letter_raises_mood() -> void:
	var sim := _sim()
	var c := sim.colonists.list[0]
	var st := sim.debt.state_of(c)
	var d0 := st.despair
	assert_true(sim.storyteller.fire("escape_rumors"))
	assert_gt(st.despair, d0)
	assert_true(sim.storyteller.fire("letter_home"))
	var any := false
	for col in sim.colonists.list:
		if sim.mood.state_of(col).find("letter_home") >= 0:
			any = true
	assert_true(any)


func test_decree_amnesty_or_quota() -> void:
	var amnesty := 0
	var quota := 0
	for seed_value in range(1, 13):
		var sim := _sim(seed_value)
		sim.run_ticks(int(sim.defs.contracts["first_offer_day"]) * sim.ticks_per_day)
		var ess := int(sim.contracts.list[0]["essence"])
		var paid := 0
		for c in sim.colonists.list:
			paid += sim.debt.state_of(c).paid
		sim.storyteller.run_step("decree_effect")
		var paid2 := 0
		for c in sim.colonists.list:
			paid2 += sim.debt.state_of(c).paid
		if paid2 > paid:
			amnesty += 1
		if int(sim.contracts.list[0]["essence"]) > ess:
			quota += 1
	assert_gt(float(amnesty), 0.0, "amnesty happens")
	assert_gt(float(quota), 0.0, "quota rise happens")


func test_save_load_replay_matches() -> void:
	var d := peaceful_defs()
	d.balance["storyteller"]["chance"] = 1.0
	var make := func() -> Defs:
		var dd := peaceful_defs()
		dd.balance["storyteller"]["chance"] = 1.0
		dd.event_chains["random_enabled"] = true
		dd.event_chains["chance"] = 1.0
		return dd
	var sim := make_sim(12, true, 24, 24, make.call())
	for step in 60:
		sim.run_ticks(100)
		for p in sim.storyteller.pending.duplicate():
			sim.answer_event(int(p["uid"]), step % 2 == 0)
	assert_gt(float(sim.storyteller.fired.size()), 2.0, "events happened")
	var res := SaveGame.load_json(SaveGame.to_json(sim), make_bus(), make.call())
	assert_true(res["ok"], str(res["error"]))
	var sim2: Simulation = res["sim"]
	_sims.append(sim2)
	assert_eq(SaveGame.state_hash(sim2), SaveGame.state_hash(sim))
	assert_eq(sim2.storyteller.fired, sim.storyteller.fired)
	assert_eq(sim2.contracts.anger, sim.contracts.anger)
	assert_eq(sim2.storyteller.chain_queue, sim.storyteller.chain_queue)


func test_first_kill_hint_once() -> void:
	var sim := _sim()
	var said: Array = []
	_says(sim, said)
	sim.bus.enemy_killed.emit(1)
	sim.bus.enemy_killed.emit(2)
	assert_eq(said.count("secret_hint"), 1)


func test_complication_max_one_per_wave() -> void:
	var d := _defs()
	d.event_chains["complication"]["chance"] = 1.0
	d.event_chains["random_enabled"] = true
	var sim := make_sim(6, true, 24, 24, d)
	sim.colonists.spawn(Vector2i(4, 4))
	sim.colonists.spawn(Vector2i(5, 4))
	var said: Array = []
	_says(sim, said)
	sim.bus.wave_started.emit(2, 1.0)
	assert_eq(said.filter(func(s: String) -> bool: return s.begins_with("complication")).size(), 0, "wave 2 none")
	sim.bus.wave_started.emit(3, 1.0)
	sim.bus.wave_started.emit(3, 1.0)
	assert_eq(said.filter(func(s: String) -> bool: return s.begins_with("complication")).size(), 1, "one per wave")


func _run_script(sim: Simulation) -> void:
	_stock(sim, "refined_essence", 12)
	sim.storyteller.fire("letter_home")
	sim.storyteller.run_step("smuggler_offer")
	sim.answer_event(int(sim.storyteller.pending[0]["uid"]), true)
	sim.storyteller.fire("metropolis_decree")
	sim.run_ticks(300)


func test_determinism() -> void:
	var a := _sim(9)
	var b := _sim(9)
	_run_script(a)
	_run_script(b)
	assert_eq(SaveGame.state_hash(a), SaveGame.state_hash(b))
	assert_eq(a.storyteller.chain_queue, b.storyteller.chain_queue)
	assert_eq(a.contracts.anger, b.contracts.anger)


func test_random_storyteller_picks_prison_events_deterministically() -> void:
	var seen := {}
	for s in 3:
		var d := peaceful_defs()
		d.balance["storyteller"]["chance"] = 0.0
		d.event_chains["random_enabled"] = true
		d.event_chains["chance"] = 1.0
		var sim := make_sim(20 + s, false, 24, 24, d)
		sim.colonists.spawn(Vector2i(4, 4))
		sim.run_ticks(8 * sim.ticks_per_day)
		for id in sim.storyteller.fired:
			seen[id] = true
	var any_prison := false
	for id in ["inspection_notice", "escape_rumors", "smuggler_signal", "new_prisoners", "metropolis_decree", "letter_home"]:
		any_prison = any_prison or seen.has(id)
	assert_true(any_prison, "prison events join the pool")
