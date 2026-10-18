extends TestCase
## Campaign layer: home == plain Simulation, seeds, switching, determinism, bus isolation, cost.

var _buses: Array = []


func _factory() -> Callable:
	return func() -> Object: return make_bus()


func _camp(seed_value: int, defs: Defs = null) -> Campaign:
	var c := Campaign.new(seed_value, _factory(), defs if defs != null else peaceful_defs())
	c.start()
	_buses.append(c)
	return c


func after_each() -> void:
	for c: Campaign in _buses:
		c.dispose()
	_buses.clear()
	super.after_each()


func _defs_with_biome(hazard: int) -> Defs:
	var d := peaceful_defs()
	d.resources["test_ore"] = {"item": "test_ore", "tier": 2, "base_rate": 10.0,
		"purity_mult": {"impure": 0.5, "normal": 1.0, "pure": 2.0}}
	d.biomes["test_biome"] = {"hazard": hazard, "yield_mult": 1.0, "resources": {"test_ore": 1}}
	return d


func _crew(sim: Simulation, n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append({"name": "Crew%d" % i})
	return out


func test_home_matches_plain_simulation() -> void:
	var c := _camp(7)
	var plain := make_sim(7, true, 24, 24, peaceful_defs())
	for i in 600:
		c.step()
		plain.step()
	assert_eq(SaveGame.state_hash(c.home_sim()), SaveGame.state_hash(plain))
	assert_eq(c.tick, 600)


func test_outpost_seed_formula() -> void:
	assert_eq(Campaign.outpost_seed(7, 1), 7 * 1000003 + 1 * 7919)
	var c := _camp(7)
	var id := c.add_outpost("start", _crew(c.home_sim(), 2), {"food": 50})
	assert_eq(id, 1)
	assert_eq(c.map_info(1)["seed"], 7 * 1000003 + 7919)
	assert_eq(c.maps[1]["sim"].seed_value, 7 * 1000003 + 7919)
	assert_eq(c.maps[1]["sim"].map.width, 96)


func test_switch_map_recorded() -> void:
	var c := _camp(3)
	c.add_outpost("start", _crew(c.home_sim(), 1), {})
	assert_false(c.switch_map(5))
	for i in 5:
		c.step()
	assert_true(c.switch_map(1))
	assert_eq(c.active, 1)
	assert_eq(c.active_sim(), c.maps[1]["sim"])
	assert_eq(c.log[0], [5, "switch_map", [1]])


func _run(seed_value: int, ticks: int) -> int:
	var c := _camp(seed_value)
	c.add_outpost("start", _crew(c.home_sim(), 2), {"food": 40})
	c.add_outpost("start", _crew(c.home_sim(), 3), {"food": 40})
	for i in ticks:
		if i == 500:
			c.switch_map(1)
		elif i == 1500:
			c.switch_map(2)
		elif i == 2500:
			c.switch_map(0)
		c.step()
	return c.state_hash()


func test_same_commands_same_hash_three_maps() -> void:
	assert_eq(_run(11, 3000), _run(11, 3000))
	assert_ne(_run(11, 3000), _run(12, 3000))


func test_outpost_raid_never_emits_on_home_bus() -> void:
	var d := _defs_with_biome(6)
	var c := _camp(9, d)
	var home_bus: Object = c.home_sim().bus
	var count := [0]
	var inc := func(_a = null, _b = null, _c = null) -> void: count[0] += 1
	for sig in ["alarm_changed", "expedition_loss", "map_switched", "cargo_arrived"]:
		if home_bus.has_signal(sig):
			home_bus.connect(sig, inc)
	var id := c.add_outpost("test_biome", _crew(c.home_sim(), 2), {"food": 100000})
	c.ledgers[id]["miners"] = 2
	var plain := make_sim(9, true, 24, 24, d)
	for i in 600 * 12:
		c.step()
		plain.step()
	assert_gt(float(c.ledgers[id]["raids"]), 0.0)
	assert_eq(SaveGame.state_hash(c.home_sim()), SaveGame.state_hash(plain))
	if not bool(c.ledgers[id]["lost"]):
		assert_eq(count[0], 0)
	# raids alone (no loss yet) must leave home signals silent
	var c2 := _camp(9, d)
	var n2 := [0]
	var inc2 := func(_a = null) -> void: n2[0] += 1
	if c2.home_sim().bus.has_signal("alarm_changed"):
		c2.home_sim().bus.connect("alarm_changed", inc2)
	c2.add_outpost("test_biome", _crew(c2.home_sim(), 2), {"food": 100000})
	for i in 600 * 3:
		c2.step()
	assert_eq(n2[0], 0)


func test_switch_in_flushes_buffer_when_hook_exists() -> void:
	var d := _defs_with_biome(0)
	var c := _camp(4, d)
	var id := c.add_outpost("test_biome", _crew(c.home_sim(), 5), {"food": 1000})
	for i in 600 * 3:
		c.step()
	var made := Autopilot.buffer_total(c.ledgers[id])
	assert_gt(float(made), 0.0)
	c.switch_map(id)
	if c.active_sim().has_method("receive_cargo"):
		assert_eq(Autopilot.buffer_total(c.ledgers[id]), 0)
	else:
		assert_eq(Autopilot.buffer_total(c.ledgers[id]), made)


func test_three_map_step_cost() -> void:
	var c1 := _camp(6)
	var c3 := _camp(6)
	c3.add_outpost("start", _crew(c3.home_sim(), 2), {"food": 40})
	c3.add_outpost("start", _crew(c3.home_sim(), 2), {"food": 40})
	var t0 := Time.get_ticks_usec()
	for i in 600:
		c1.step()
	var t1 := Time.get_ticks_usec()
	for i in 600:
		c3.step()
	var t2 := Time.get_ticks_usec()
	var extra_ms := (float(t2 - t1) - float(t1 - t0)) / 600.0 / 1000.0
	assert_true(extra_ms <= 0.15, "3-map extra cost %.3f ms/tick" % extra_ms)
