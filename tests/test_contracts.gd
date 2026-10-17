extends TestCase
## Warden contracts: schedule, delivery, failure sanctions, decline, ledger, replay.


func _sim(seed_value := 3) -> Simulation:
	var sim := make_sim(seed_value, false, 24, 24, peaceful_defs())
	sim.colonists.spawn(Vector2i(4, 4))
	sim.set_zone(Vector2i(6, 6), "stockpile")
	sim.set_zone(Vector2i(6, 7), "stockpile")
	return sim


func _to_day(sim: Simulation, d: int) -> void:
	sim.run_ticks(d * sim.ticks_per_day - sim.tick)


func _first_offer(sim: Simulation) -> Dictionary:
	_to_day(sim, int(sim.defs.contracts["first_offer_day"]))
	return sim.contracts.list[0]


func test_offer_schedule() -> void:
	var sim := _sim()
	_to_day(sim, int(sim.defs.contracts["first_offer_day"]) - 1)
	assert_eq(sim.contracts.list.size(), 0)
	_to_day(sim, int(sim.defs.contracts["first_offer_day"]))
	assert_eq(sim.contracts.list.size(), 1)
	assert_eq(sim.contracts.list[0]["state"], "offered")


func test_deliver_success_and_ledger() -> void:
	var sim := _sim()
	var c := _first_offer(sim)
	var id := int(c["id"])
	assert_true(sim.accept_contract(id))
	assert_false(sim.deliver_contract(id), "nothing stored yet")
	c["reward"] = {"kind": "supplies", "items": {"meal": 5}}
	sim.ledger.record_produced("refined_essence", 20, "test")
	sim.ledger.record_produced("machine_parts", 20, "test")
	sim.items.drop(Vector2i(6, 6), "refined_essence", 20)
	sim.items.drop(Vector2i(6, 7), "machine_parts", 20)
	var before := sim.items.count_world("refined_essence")
	assert_true(sim.deliver_contract(id))
	assert_eq(c["state"], "fulfilled")
	assert_eq(sim.items.count_world("refined_essence"), before - int(c["essence"]))
	assert_eq(sim.ledger.get_count("contract:refined_essence"), int(c["essence"]))
	assert_eq(sim.items.count_world("meal"), 5)
	for item in ["refined_essence", "machine_parts", "meal"]:
		assert_eq(sim.items.count_world(item), sim.ledger.balance_of(item), item)


func test_deadline_failure_sanctions() -> void:
	var sim := _sim()
	var c := _first_offer(sim)
	sim.accept_contract(int(c["id"]))
	_to_day(sim, int(c["deadline_day"]))
	assert_eq(c["state"], "failed")
	assert_gt(sim.contracts.anger, 0.0)
	assert_gt(sim.contracts.next_raid_mult, 1.0)


func test_inspection_injures() -> void:
	var sim := _sim()
	var c := _first_offer(sim)
	sim.contracts.anger = 3.0
	sim.accept_contract(int(c["id"]))
	_to_day(sim, int(c["deadline_day"]))
	assert_false(sim.health.state_of(sim.colonists.list[0]).injuries.is_empty())


func test_decline_and_expire() -> void:
	var sim := _sim()
	var c := _first_offer(sim)
	assert_true(sim.decline_contract(int(c["id"])))
	assert_eq(c["state"], "declined")
	assert_gt(sim.contracts.anger, 0.0)
	assert_false(sim.accept_contract(int(c["id"])))
	assert_gt(sim.contracts.take_raid_mult(), 1.0)
	assert_eq(sim.contracts.next_raid_mult, 1.0)
	var sim2 := _sim()
	var c2 := _first_offer(sim2)
	_to_day(sim2, int(c2["expire_day"]))
	assert_eq(c2["state"], "expired")


func _scripted(sim: Simulation) -> void:
	_to_day(sim, 2)
	sim.accept_contract(1)
	_to_day(sim, 7)
	sim.decline_contract(2)
	_to_day(sim, 12)


func test_determinism_and_replay() -> void:
	var a := make_sim(9, true, 24, 24, peaceful_defs())
	_scripted(a)
	var b := make_sim(9, true, 24, 24, peaceful_defs())
	_scripted(b)
	assert_eq(JSON.stringify(a.contracts.list), JSON.stringify(b.contracts.list))
	assert_eq(a.contracts.anger, b.contracts.anger)
	var res := SaveGame.load_json(SaveGame.to_json(a), make_bus(), peaceful_defs())
	assert_true(res["ok"], str(res["error"]))
	var r: Simulation = res["sim"]
	_sims.append(r)
	assert_eq(JSON.stringify(r.contracts.list), JSON.stringify(a.contracts.list))
	assert_eq(r.contracts.anger, a.contracts.anger)
