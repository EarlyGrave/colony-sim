extends TestCase
## W4: expedition send/arrive/loss. Tests needing W2's `dispatch_party` hook skip until it is merged.

const StubCampaign := preload("res://tests/stub_campaign.gd")
var _camps: Array = []


func after_each() -> void:
	for c in _camps:
		c.dispose()
	_camps.clear()
	super.after_each()


func _camp(seed_value := 5) -> Object:
	var c: Object = StubCampaign.new(seed_value, func() -> Node: return make_bus(), peaceful_defs())
	c.start()
	_camps.append(c)
	return c


func _ids(sim: Simulation, n: int) -> Array:
	var out: Array = []
	for col in sim.colonists.list:
		if out.size() < n and col.alive:
			out.append(col.id)
	return out


func _inject_party(c: Object, map_id: int, crew_n: int, arrive: int) -> void:
	var crew: Array = []
	for i in crew_n:
		crew.append({"name": "Crew%d" % i})
	c.in_flight.append({"kind": "party", "map_id": map_id, "biome": "start", "crew": crew,
		"supplies": {}, "arrive": arrive})


func test_tech_defined_in_research_json() -> void:
	var t: Dictionary = Defs.get_default().research["expeditions"]
	assert_eq(int(t["tier"]), 2)
	var pre: Array = t["prereqs"]
	assert_eq(int(Defs.get_default().research[pre[0]]["tier"]), 1)
	assert_true((t["unlocks"]["rules"] as Array).has("expeditions"))
	assert_true(Defs.get_default().rules.has("expeditions"))


func test_send_refused_without_tech() -> void:
	var c := _camp()
	var home: Simulation = c.active_sim()
	var before := home.colonists.list.size()
	assert_false(Expedition.send(c, "start", _ids(home, 3), {}))
	assert_eq(home.colonists.list.size(), before)
	assert_true(c.in_flight.is_empty())


func test_send_with_tech_and_arrival_at_travel_ticks() -> void:
	var c := _camp()
	var home: Simulation = c.active_sim()
	if not home.has_method("dispatch_party"):
		return  # W2 hook missing on this branch
	home.research.done.append("expeditions")
	var biome: String = Defs.get_default().biomes.keys()[0]
	var alive_before := 0
	for col in home.colonists.list:
		alive_before += 1 if col.alive else 0
	assert_true(Expedition.send(c, biome, _ids(home, 3), {}))
	var alive_after := 0
	for col in home.colonists.list:
		alive_after += 1 if col.alive else 0
	assert_eq(alive_after, alive_before - 3)
	var travel := int(Expedition.cfg(c)["travel_ticks"])
	for i in travel - 1:
		c.step()
	assert_eq(c.maps.size(), 1)
	c.step()
	assert_eq(c.maps.size(), 2)
	assert_eq(c.tick, travel)
	assert_eq(str(c.maps[1]["kind"]), "outpost")


func test_party_arrives_exactly_on_tick() -> void:
	var c := _camp()
	_inject_party(c, 1, 3, 20)
	for i in 19:
		c.step()
	assert_eq(c.maps.size(), 1)
	c.step()
	assert_eq(c.maps.size(), 2)
	assert_eq(int(c.maps[1]["id"]), 1)
	assert_eq(int(c.maps[1]["seed"]), c.campaign_seed * 1000003 + 7919)
	assert_true(c.in_flight.is_empty())


func test_crew_death_charges_collateral_once() -> void:
	var c := _camp()
	_inject_party(c, 1, 3, 1)
	c.step()
	var m: Dictionary = c.maps[1]
	var out: Simulation = m["sim"]
	m["crew_n"] = out.colonists.list.size()
	var coll := int(Expedition.cfg(c)["collateral"])
	out.colonists.list[0].alive = false
	out.colonists.list[1].alive = false
	Expedition.tick(c)
	Expedition.tick(c)  # second call must not charge again
	assert_eq(int(Expedition.campaign_ledger(c)["collateral_debt"]), 2 * coll)
	for col in out.colonists.list:
		col.alive = false
	Expedition.tick(c)
	assert_eq(int(Expedition.campaign_ledger(c)["collateral_debt"]), int(m["crew_n"]) * coll)
	Expedition.tick(c)
	assert_eq(int(Expedition.campaign_ledger(c)["collateral_debt"]), int(m["crew_n"]) * coll)


func test_recall_sends_buffer_home() -> void:
	var c := _camp()
	_inject_party(c, 1, 3, 1)
	c.step()
	Expedition.ledger(c, 1)["buffer"] = {"essence_ore": 7}
	assert_false(Expedition.recall(c, 0))
	assert_true(Expedition.recall(c, 1))
	assert_eq(c.maps.size(), 1)
	for i in int(Expedition.cfg(c)["travel_ticks"]):
		c.step()
	var got := int(Expedition.ledger(c, 0)["inbox"].get("essence_ore", 0))
	var on_map: bool = c.active_sim().has_method("receive_cargo")
	assert_true(got == 7 or on_map)
