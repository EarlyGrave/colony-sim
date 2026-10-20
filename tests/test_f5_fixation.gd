extends TestCase
const Scen := preload("res://tests/scenario.gd")
## F5 W3 Fixation: offer, accept/decline, success (named masterwork), failure, cancel + refund, save/load.


func _sim(on := true, seed_value := 3) -> Simulation:
	var defs := peaceful_defs()
	defs.balance["fixation_enabled"] = on
	var sim := Simulation.new(seed_value, make_bus(), defs, {})
	sim.start_new_game()
	_sims.append(sim)
	sim.run_ticks(1)
	for c in sim.colonists.list:
		c.skills.levels["crafting"] = 4
	sim.tick = 24 * sim.ticks_per_day
	return sim


func _stock(sim: Simulation, item: String, n: int) -> void:
	sim.ledger.record_produced(item, n, "test")
	sim.items.drop(Vector2i(6 + (item.length() % 8), 6 + (item.length() % 2)), item, n)


func _bench(sim: Simulation) -> void:
	var b := sim.place_instant("workbench", Scen.find_spot(sim, "workbench", sim.colonists.list[0].cell + Vector2i(4, 4), 0))
	assert_true(b != null, "bench placed")


func _offer(sim: Simulation) -> Dictionary:
	_stock(sim, "plate", 8)
	_stock(sim, "refined_essence", 3)
	for _i in 2 * sim.ticks_per_day:
		sim.run_ticks(1)
		for p in sim.storyteller.pending:
			if p["kind"] == "fixation":
				return p
	return {}


func test_off_makes_no_offer() -> void:
	var sim := _sim(false)
	assert_true(_offer(sim).is_empty(), "flag OFF: no offer")


func test_decline_is_free_and_once() -> void:
	var sim := _sim()
	var p := _offer(sim)
	assert_false(p.is_empty(), "offered")
	var plates := sim.items.count_stored("plate")
	assert_true(sim.answer_event(int(p["uid"]), false))
	assert_eq(sim.items.count_stored("plate"), plates, "decline spends nothing")
	assert_true(sim.fixation.active.is_empty())
	sim.run_ticks(2 * sim.ticks_per_day)
	assert_false(sim.storyteller.has_pending(), "never offered twice")


func test_timeout_declines() -> void:
	var sim := _sim()
	assert_false(_offer(sim).is_empty())
	sim.run_ticks(int(sim.defs.fixation["offer_ticks"]) + 5)
	assert_false(sim.storyteller.has_pending())
	assert_true(sim.fixation.active.is_empty())


func test_accept_with_bench_makes_named_masterwork() -> void:
	var sim := _sim()
	_bench(sim)
	var p := _offer(sim)
	var cid := int(p["cid"])
	var plates := sim.items.count_stored("plate")
	assert_true(sim.answer_event(int(p["uid"]), true))
	assert_eq(sim.items.count_stored("plate"), plates - 6, "plates reserved")
	assert_eq(sim.fixation.reserved("refined_essence"), 2, "reservation visible")
	sim.run_ticks(int(sim.defs.fixation["work_ticks"]) + 40)

	assert_true(sim.fixation.active.is_empty(), "finished")
	assert_eq(sim.fixation.masterworks.size(), 1)
	var c := sim.colonists.get_by_id(cid)
	assert_eq(str(c.bio["masterwork"]), sim.fixation.masterworks[0]["name"])
	assert_true(str(c.bio["masterwork"]).begins_with(c.display_name + "'s "), "signed")
	var g: GearItem = sim.equipment.instances[int(sim.fixation.masterworks[0]["gear_id"])]
	assert_eq(g.rarity, "legendary")
	assert_eq(sim.fixation.reserved("plate"), 0)


func test_no_bench_fails_with_break_and_loss() -> void:
	var sim := _sim()
	for b in sim.buildings.list.duplicate():
		if b.def_id == "workbench":
			b.destroyed = true
	var p := _offer(sim)
	var cid := int(p["cid"])
	var plates := sim.items.count_stored("plate")
	sim.answer_event(int(p["uid"]), true)
	sim.run_ticks(3 * sim.ticks_per_day + 5)
	assert_true(sim.fixation.active.is_empty())
	assert_eq(sim.fixation.failures, 1)
	assert_eq(sim.items.count_stored("plate"), plates - 6, "items lost")
	assert_eq(sim.fixation.masterworks.size(), 0)
	assert_true(sim.mood.state_of(sim.colonists.get_by_id(cid)).break_kind != "", "break started")


func test_death_cancels_and_refunds() -> void:
	var sim := _sim()
	var p := _offer(sim)
	var cid := int(p["cid"])
	var before := sim.items.count_world("plate")
	sim.answer_event(int(p["uid"]), true)
	assert_eq(sim.items.count_world("plate"), before - 6)
	sim.colonists.get_by_id(cid).alive = false
	sim.run_ticks(2)
	assert_true(sim.fixation.active.is_empty())
	assert_eq(sim.items.count_world("plate"), before, "refunded to the world")
	assert_eq(sim.fixation.reserved("plate"), 0)


func test_accept_without_stock_is_rejected() -> void:
	var sim := _sim()
	var p := _offer(sim)
	sim.items.consume_stored("plate", sim.items.count_stored("plate"), Vector2i(6, 6))
	sim.answer_event(int(p["uid"]), true)
	assert_true(sim.fixation.active.is_empty(), "cannot accept without items")


func _run_hash(seed_value: int) -> String:
	var sim := _sim(true, seed_value)
	_bench(sim)
	var p := _offer(sim)
	sim.answer_event(int(p["uid"]), true)
	sim.run_ticks(400)
	var ms: Array = sim.fixation.masterworks
	return "%d|%s" % [sim.tick, str(ms)]


func test_deterministic() -> void:
	assert_eq(_run_hash(5), _run_hash(5))
	assert_true(_run_hash(5).contains("name"), "masterwork made")


func test_save_load_mid_fixation() -> void:
	# The sim starts at tick 0 in SaveGame replay, so drive a real run from tick 0 with the flag on.
	var defs := peaceful_defs()
	defs.balance["fixation_enabled"] = true
	defs.fixation = defs.fixation.duplicate(true)
	defs.fixation["min_day"] = 0
	defs.fixation["min_level"] = 0
	defs.fixation["cost"] = {"plate": 0}  # replay-safe: no hand-stocked items or edited skills
	var sim := Simulation.new(4, make_bus(), defs, {})
	sim.start_new_game()
	_sims.append(sim)
	var p := {}
	for _i in 600:
		sim.run_ticks(1)
		p = sim.storyteller.pending[0] if sim.storyteller.has_pending() else {}
		if not p.is_empty():
			break
	assert_false(p.is_empty(), "offered early")
	sim.answer_event(int(p["uid"]), true)
	sim.run_ticks(100)
	assert_false(sim.fixation.active.is_empty(), "mid-fixation")
	var data := SaveGame.to_dict(sim)
	var res := SaveGame.load_dict(data, make_bus(), defs)
	assert_true(bool(res["ok"]), str(res["error"]))
	var sim2: Simulation = res["sim"]
	_sims.append(sim2)
	assert_eq(sim2.fixation.active, sim.fixation.active, "same active state after load")
	assert_eq(sim2.fixation.held, sim.fixation.held)
