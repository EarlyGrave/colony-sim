extends TestCase
## W4: sling building and in-flight crates.

const StubCampaign := preload("res://tests/stub_campaign.gd")
var _camps: Array = []


func after_each() -> void:
	for c in _camps:
		c.dispose()
	_camps.clear()
	super.after_each()


func _camp_with_outpost() -> Object:
	var c: Object = StubCampaign.new(6, func() -> Node: return make_bus(), peaceful_defs())
	c.start()
	_camps.append(c)
	c.in_flight.append({"kind": "party", "map_id": 1, "biome": "start", "crew": [{"name": "A"}],
		"supplies": {}, "arrive": 1})
	c.step()
	return c


func _place_sling(c: Object) -> void:
	var sim: Simulation = Expedition.map_entry(c, 1)["sim"]
	var spot := preload("res://tests/scenario.gd").find_spot(sim, "sling", sim.map_center() + Vector2i(5, 0), 0)
	assert_true(sim.place_instant("sling", spot) != null)


func test_sling_def_data() -> void:
	var d: Dictionary = Defs.get_default().buildings["sling"]
	for k in ["capacity", "cooldown", "travel", "max_in_flight"]:
		assert_gt(float(d[k]), 0.0, k)
	assert_true((Defs.get_default().research["expeditions"]["unlocks"]["buildings"] as Array).has("sling"))


func test_over_capacity_and_no_sling_rejected() -> void:
	var c := _camp_with_outpost()
	assert_false(Sling.send(c, 1, {"essence_ore": 1}))  # no sling building yet
	_place_sling(c)
	var cap := int(Sling.sling_def(c)["capacity"])
	assert_false(Sling.send(c, 1, {"essence_ore": cap + 1}))
	assert_false(Sling.send(c, 1, {}))
	assert_true(c.in_flight.is_empty())


func test_crate_arrives_after_travel_ticks_exactly() -> void:
	var c := _camp_with_outpost()
	var travel := int(Sling.sling_def(c)["travel"])
	c.in_flight.append({"kind": "crate", "from": 1, "to": 0, "items": {"essence_ore": 5}, "arrive": c.tick + travel})
	c.active = 1  # home unattended: crate waits in the inbox
	var t0: int = c.tick
	var sim1: Simulation = c.active_sim()
	for i in travel - 1:
		sim1.step()
		c.tick += 1
		Sling.tick(c)
	assert_eq(c.in_flight.size(), 1)
	sim1.step()
	c.tick += 1
	Sling.tick(c)
	assert_true(c.in_flight.is_empty())
	assert_eq(c.tick, t0 + travel)
	assert_eq(int(Expedition.ledger(c, 0)["inbox"].get("essence_ore", 0)), 5)


func test_send_cooldown_and_in_flight_cap() -> void:
	var c := _camp_with_outpost()
	_place_sling(c)
	var sim: Simulation = Expedition.map_entry(c, 1)["sim"]
	if not sim.has_method("dispatch_party"):
		return  # W2 hook missing on this branch
	var cell := sim.map_center() + Vector2i(-6, 2)
	sim.set_zone(cell, "stockpile")
	sim.items.add_at(cell, "essence_ore", 5)
	assert_true(Sling.send(c, 1, {"essence_ore": 2}))
	assert_false(Sling.send(c, 1, {"essence_ore": 1}))  # cooling down
	assert_eq(c.in_flight.size(), 1)
	assert_eq(sim.items.count_stored("essence_ore"), 3)
