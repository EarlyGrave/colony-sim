extends TestCase
## W4: campaign save v3 (replay each map, restore ledgers / in-flight verbatim). v2 is rejected.

var _camps: Array = []


func after_each() -> void:
	for c in _camps:
		c.dispose()
	_camps.clear()
	super.after_each()


func _factory() -> Callable:
	return func() -> Node: return make_bus()


func _camp() -> Object:
	var c: Object = Campaign.new(9, _factory(), peaceful_defs())
	c.start()
	_camps.append(c)
	return c


func test_mid_trip_roundtrip_hash_equal_then_continues_equal() -> void:
	var c := _camp()
	# A party still travelling and a crate in flight toward home.
	c.in_flight.append({"kind": "party", "map_id": 1, "biome": "start", "crew": [{"name": "A"}, {"name": "B"}],
		"supplies": {"essence_ore": 3}, "arrive": 200})
	c.in_flight.append({"kind": "crate", "from": 1, "to": 0, "items": {"essence_ore": 4}, "arrive": 300})
	Expedition.campaign_ledger(c)["collateral_debt"] = 100
	for i in 60:
		c.step()
	var text := SaveGame.campaign_to_json(c)
	var res := SaveGame.campaign_from_json(text, _factory(), peaceful_defs())
	assert_true(res["ok"], str(res["error"]))
	var c2: Object = res["campaign"]
	_camps.append(c2)
	assert_eq(c2.tick, c.tick)
	assert_eq(c2.state_hash(), c.state_hash())
	for i in 500:
		c.step()
		c2.step()
	assert_eq(c2.maps.size(), 2)  # party arrived on both sides
	assert_eq(c2.state_hash(), c.state_hash())


func test_in_flight_crates_survive_roundtrip() -> void:
	var c := _camp()
	c.in_flight.append({"kind": "crate", "from": 1, "to": 0, "items": {"essence_ore": 4}, "arrive": 90})
	var res := SaveGame.campaign_from_json(SaveGame.campaign_to_json(c), _factory(), peaceful_defs())
	assert_true(res["ok"])
	_camps.append(res["campaign"])
	assert_eq(var_to_str(res["campaign"].in_flight), var_to_str(c.in_flight))


func test_v2_and_garbage_rejected() -> void:
	var sim := make_sim(3, true, 24, 24, peaceful_defs())
	var v2 := SaveGame.to_dict(sim)
	var res := SaveGame.campaign_from_dict(v2, _factory(), peaceful_defs())
	assert_false(res["ok"])
	assert_eq(res["error"], "version")
	assert_eq(SaveGame.campaign_from_json("nope", _factory(), peaceful_defs())["error"], "corrupt")
	assert_eq(SaveGame.campaign_from_dict({"version": 3}, _factory(), peaceful_defs())["error"], "corrupt")
	var c := _camp()
	var d := SaveGame.campaign_to_dict(c)
	d["defs_hash"] = 1
	assert_eq(SaveGame.campaign_from_dict(d, _factory(), peaceful_defs())["error"], "defs_changed")


func test_sim_save_version_unchanged() -> void:
	assert_eq(SaveGame.VERSION, 2)
	assert_eq(SaveGame.CAMPAIGN_VERSION, 3)
