extends TestCase
## S3 Whisper Network: data quest after q13 + tier 2 (informant_alive cond stubbed until W1 merges) + informant PA line.

const ID := "s3_whisper_network"
const Q13 := "q13_informant"
const STORE := Vector2i(2, 2)


func _sim(seed_value: int, clerk := true, alive := true) -> Simulation:
	var d := TestCase.peaceful_defs()
	d.balance["q_enabled"] = true
	var sim := make_sim(seed_value, true, 24, 24, d)
	var inf_id: int = sim.colonists.list[0].id
	var m: InformantMod = sim.quests._modules[Q13]
	m.informant_fn = func() -> int: return inf_id
	sim.colonists.list[0].bio["tag"] = "Informant"
	if clerk and sim.colonists.list.size() > 1:
		sim.colonists.list[1].bio["tag"] = "Clerk"
	# stub of the W1 cond (W1's registration overwrites it once merged)
	sim.quests.register_cond("informant_alive", func(_v: Variant) -> bool: return alive and sim.colonists.get_by_id(inf_id).alive)
	sim.set_zone(STORE, "stockpile")
	return sim


func _fire(sim: Simulation) -> void:
	sim.tick = sim.ticks_per_day * 10
	sim.quests.quests[Q13] = {"state": "done", "beat": "", "refs": {}}
	sim.quests._modules[Q13].state = "done"
	sim.milestones.done_tiers.append(2)
	sim.run_ticks(sim.ticks_per_day * 2)


func test_data_loaded() -> void:
	var sim := _sim(1)
	assert_true(sim.defs.quests.has(ID))


func test_not_without_tier_or_informant() -> void:
	var sim := _sim(2)
	sim.tick = sim.ticks_per_day * 10
	sim.quests.quests[Q13] = {"state": "done", "beat": "", "refs": {}}
	sim.run_ticks(sim.ticks_per_day * 2)
	assert_eq(sim.quests.state(ID), "idle")
	var sim2 := _sim(2, true, false)
	_fire(sim2)
	assert_eq(sim2.quests.state(ID), "idle")


func test_fires_in_at_least_7_of_10_seeds() -> void:
	var fired := 0
	for s in range(1, 11):
		var sim := _sim(s)
		_fire(sim)
		if sim.quests.state(ID) == "active" and not sim.quests.pending_for(ID).is_empty():
			fired += 1
	assert_true(fired >= 7, "fired %d/10" % fired)


func _answer(sim: Simulation, opt: String) -> bool:
	return sim.quests.answer(int(sim.quests.pending_for(ID)["uid"]), opt)


func test_decoy_needs_clerk_and_parts() -> void:
	var sim := _sim(3, false)
	_fire(sim)
	var p := sim.quests.pending_for(ID)
	for o: Dictionary in p["options"]:
		if o["id"] == "decoy":
			assert_false(bool(o["enabled"]))
	assert_false(_answer(sim, "decoy"), "no clerk: fails")
	var sim2 := _sim(3, true)
	_fire(sim2)
	assert_false(_answer(sim2, "decoy"), "no parts: fails")
	var sim3 := _sim(3, true)
	sim3.items.drop(STORE, "parts", 6)
	sim3.run_ticks(120)
	assert_true(sim3.items.count_stored("parts") >= 5, "parts stored")
	_fire(sim3)
	assert_true(_answer(sim3, "decoy"))
	assert_eq(sim3.quests.mod("petition_fee_mult"), 0.9)


func test_bait_gamble() -> void:
	var wins := 0
	var losses := 0
	for s in range(1, 9):
		var sim := _sim(s)
		_fire(sim)
		assert_true(_answer(sim, "bait"))
		if sim.quests.flag("audit_dates_known"):
			wins += 1
			assert_eq(sim.quests.mod("audit_parts_mult"), 0.8)
		else:
			losses += 1
			assert_eq(sim.quests.mod("petition_fee_mult"), 1.3)
	assert_eq(wins + losses, 8)
	assert_true(wins > 0 and losses > 0, "both outcomes reachable")


func test_cut_off_resets_fee_and_removes_informant() -> void:
	var sim := _sim(4)
	_fire(sim)
	var inf_id: int = sim.colonists.list[0].id
	assert_true(_answer(sim, "cut"))
	assert_true(sim.debt.gone.has(inf_id), "transferred")
	assert_eq(sim.quests.mod("petition_fee_mult"), 1.0)
	assert_eq(sim.quests.state(ID), "done")


func _letters(sim: Simulation, out: Array) -> void:
	sim.bus.letter_received.connect(func(t: String, x: String) -> void: out.append([t, x]))


func test_pa_line_emitted_and_silenced() -> void:
	var got: Array = []
	var sim := _sim(5)
	_letters(sim, got)
	sim.tick = sim.ticks_per_day * 12
	sim.run_ticks(sim.ticks_per_day * 7)
	var n := 0
	for l: Array in got:
		if l[0] == "Warden":
			n += 1
	assert_true(n >= 1 and n <= 3, "PA lines %d" % n)
	var quiet: Array = []
	var sim2 := _sim(5)
	_letters(sim2, quiet)
	sim2.quests.add_mod("pa_silent", 1.0, 0.0)
	sim2.tick = sim2.ticks_per_day * 12
	sim2.run_ticks(sim2.ticks_per_day * 7)
	for l: Array in quiet:
		assert_ne(l[0], "Warden")


func test_determinism() -> void:
	var a := _sim(6)
	var b := _sim(6)
	_fire(a)
	_fire(b)
	_answer(a, "bait")
	_answer(b, "bait")
	assert_eq(SaveGame.state_hash(a), SaveGame.state_hash(b))
