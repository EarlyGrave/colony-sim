extends TestCase
## T5: nests, hunger bank, starved waves, rally letter, mutant variants.


func _plan(seed_value: int) -> Array:
	var sim := make_sim(seed_value)
	var out: Array = []
	for n in sim.ecology.nests:
		out.append(n["cell"])
	return out


func test_nests_deterministic_and_on_edge() -> void:
	for s in [1, 2, 3, 4, 5]:
		var a := _plan(s)
		assert_eq(a, _plan(s), "same seed same nests")
		assert_true(a.size() >= 2 and a.size() <= 4, "2-4 nests, got %d" % a.size())
		var sim := make_sim(s)
		for c: Vector2i in a:
			var m := mini(mini(c.x, c.y), mini(sim.map.width - 1 - c.x, sim.map.height - 1 - c.y))
			assert_true(m <= int(sim.ecology.cfg["edge_margin"]), "nest on map edge")
			assert_true(sim.pathfinder.reachable_terrain(c, sim.map_center()), "nest reachable")


func test_clean_map_only_starved_waves() -> void:
	var sim := make_sim(3)
	sim.threats.awaken()
	var cap := int(sim.ecology.cfg["starved_max"])
	var biggest := [0]
	sim.bus.raid_started.connect(func(_id: String, _s: float, n: int) -> void: biggest[0] = maxi(biggest[0], n))
	sim.threats.cfg["wave_duration_ticks"] = 200
	sim.run_ticks(sim.ticks_per_day * 10)
	assert_gt(sim.threats.wave_index, 1, "waves happened")
	assert_true(biggest[0] <= cap, "clean map waves <= starved_max (%d > %d)" % [biggest[0], cap])
	assert_true(sim.ecology.bank_total() < 0.001, "no pollution, no bank")


func test_bank_pays_for_big_raids() -> void:
	var sim := make_sim(3)
	var units: Array[String] = []
	for i in 12:
		units.append("crawler")
	assert_eq(sim.ecology.muster(units).size(), int(sim.ecology.cfg["starved_max"]))
	sim.ecology.nests[0]["bank"] = 5.0
	var kept := sim.ecology.muster(units)
	assert_eq(kept.size(), int(sim.ecology.cfg["starved_max"]) + 5, "bank buys 5 more crawlers")
	assert_true(sim.ecology.bank_total() < 0.001, "bank spent")


func test_hunger_gain_scales_with_pollution() -> void:
	var sim := make_sim(5)
	var c: Vector2i = sim.ecology.nests[0]["cell"]
	var f1 := 0.03
	var one := 0.0
	var three := 0.0
	for k in [1.0, 3.0]:
		var s2 := make_sim(5)
		s2.contamination.level = s2.defs.balance["contamination"]["max"] * f1 * k
		s2.ecology.nests[0]["bank"] = 0.0
		s2.run_ticks(400)
		if k == 1.0:
			one = s2.ecology.nests[0]["bank"]
		else:
			three = s2.ecology.nests[0]["bank"]
	assert_gt(one, 0.0, "pollution feeds the bank")
	assert_true(three >= 2.5 * one * 0.9, "3x pollution gives >= 2.5x hunger (%f vs %f)" % [three, one])
	assert_eq(sim.ecology.nests[0]["cell"], c)


func test_rally_letter_precedes_attack() -> void:
	var sim := make_sim(4)
	var letter_tick := [-1]
	var start_tick := [-1]
	sim.bus.letter_received.connect(func(title: String, _t: String) -> void:
		if title == "Creatures are massing" and letter_tick[0] < 0:
			letter_tick[0] = sim.tick)
	sim.bus.wave_started.connect(func(_i: int, _s: float) -> void:
		if start_tick[0] < 0:
			start_tick[0] = sim.tick)
	sim.threats.awaken()
	sim.threats.next_wave_tick = sim.tick + 3000
	sim.run_ticks(3200)
	assert_true(letter_tick[0] >= 0, "rally letter sent")
	assert_true(start_tick[0] - letter_tick[0] >= int(sim.ecology.cfg["rally_ticks"]) - 60, "letter lead %d" % (start_tick[0] - letter_tick[0]))


func test_mutant_fraction_rises_with_pollution() -> void:
	var sim := make_sim(2)
	var eco := sim.ecology
	var def: Dictionary = sim.defs.enemies["crawler"]
	var bands: Array = eco.cfg["variant_bands"]
	var fr: Array[float] = []
	for p in [0.0, float(bands[0]["min"]), float(bands[1]["min"]), float(bands[2]["min"])]:
		eco.nests[0]["tier"] = eco.tier_for(p, 0)
		var n := 0
		for i in 1000:
			if eco.roll_variant(def, 0) != "":
				n += 1
		fr.append(float(n) / 1000.0)
	assert_eq(fr[0], 0.0)
	for i in range(1, fr.size()):
		assert_gt(fr[i], fr[i - 1], "monotone band %d" % i)


func test_variant_hysteresis_on_cleanup() -> void:
	var sim := make_sim(2)
	var eco := sim.ecology
	var m := float(eco.cfg["variant_bands"][1]["min"])
	assert_eq(eco.tier_for(m, 0), 2)
	assert_eq(eco.tier_for(m * 0.9, 2), 2, "holds just below the threshold")
	assert_true(eco.tier_for(m * 0.5, 2) < 2, "reverts after real cleanup")


func test_replay_equal_state() -> void:
	var a := make_sim(6)
	var b := make_sim(6)
	for s in [a, b]:
		s.threats.awaken()
		s.run_ticks(3000)
	assert_eq(var_to_str(a.ecology.state_parts()), var_to_str(b.ecology.state_parts()))
	assert_eq(SaveGame.state_hash(a), SaveGame.state_hash(b))
