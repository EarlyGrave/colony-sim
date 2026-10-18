extends TestCase
## B4: hand-phase plate recipe, expedition-demand contract/crisis, recall. All gated by b4_enabled.
const Scenario := preload("res://tests/scenario.gd")


func _b4_defs(on := true) -> Defs:
	var d := peaceful_defs()
	d.balance["b4_enabled"] = on
	return d


func _bench(sim: Simulation) -> Building:
	return sim.buildings.place("workbench", Scenario.find_spot(sim, "workbench", sim.map_center() + Vector2i(-4, -4), 0), false)


func test_hand_plate_gated() -> void:
	var off := make_sim(1, true, 48, 48, _b4_defs(false))
	assert_eq(off.add_bill(_bench(off).id, "hand_plate", "until", 3), -1)
	var on := make_sim(1, true, 48, 48, _b4_defs(true))
	assert_true(on.add_bill(_bench(on).id, "hand_plate", "until", 3) >= 0)


func test_hand_plate_produces_plate() -> void:
	var sim := make_sim(2, true, 48, 48, _b4_defs())
	Scenario.standard_colony(sim, 3)
	var b := _bench(sim)
	sim.items.drop(sim.map_center() + Vector2i(0, 3), "essence_ore", 12)
	sim.add_bill(b.id, "hand_plate", "until", 2)
	for i in sim.ticks_per_day * 3:
		sim.step()
	assert_true(sim.items.count_stored("plate") >= 1, "plate made by hand")


func test_expedition_contract_demand() -> void:
	var sim := make_sim(3, false, 24, 24, _b4_defs())
	var c: Dictionary = {}
	for _i in 12:
		sim.contracts._offer(sim.day())
		c = sim.contracts.list.back()
		if c.has("demand"):
			break
	assert_true(c.has("demand"), "frontier template offered")
	sim.contracts.accept(int(c["id"]))
	c["essence"] = 0
	c["parts"] = 0
	assert_false(sim.contracts.can_deliver(c), "needs the ore")
	sim.set_zone(Vector2i(6, 6), "stockpile")
	sim.ledger.record_produced("cinder_ore", 3, "test")
	sim.items.drop(Vector2i(6, 6), "cinder_ore", 3)
	assert_true(sim.contracts.deliver(int(c["id"])))
	assert_eq(sim.items.count_stored("cinder_ore"), 0)


func test_crisis_tribute_option_gated() -> void:
	var off := make_sim(4, true, 48, 48, _b4_defs(false))
	assert_false((off.crises.crises["siege"]["options"] as Dictionary).has("tribute"))
	var on := make_sim(4, true, 48, 48, _b4_defs(true))
	assert_true((on.crises.crises["siege"]["options"] as Dictionary).has("tribute"))


func test_recall_returns_party() -> void:
	var c: Object = Campaign.new(5, func() -> Node: return make_bus(), peaceful_defs())
	c.start()
	c.in_flight.append({"kind": "party", "map_id": 7, "biome": "start", "crew": [{"name": "A"}], "supplies": {}, "arrive": 1})
	for i in 3:
		c.step()
	assert_false(Expedition.map_entry(c, 7).is_empty(), "outpost arrived")
	assert_true(c.recall(7))
	assert_true(Expedition.map_entry(c, 7).is_empty())
	assert_eq(c.in_flight.size(), 1)
	assert_eq(str(c.in_flight[0]["kind"]), "return")
	assert_eq((c.in_flight[0]["crew"] as Array).size(), 1)
	c.dispose()
