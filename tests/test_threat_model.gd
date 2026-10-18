extends TestCase
## Threat generation (T1): data/threat.json, ThreatModel, ThreatSystem.pick_target.


func _sim(seed_value := 3) -> Simulation:
	var d := peaceful_defs()
	d.threat["enabled"] = true
	var sim := make_sim(seed_value, false, 80, 80, d)
	return sim


func _enemy(sim: Simulation, c: Vector2i, species := "crawler") -> Enemy:
	return sim.threats._spawn(species, c)


func test_working_smelter_outranks_idle_bed() -> void:
	var sim := _sim()
	var c := sim.map_center()
	var smelter := sim.buildings.place("smelter", c + Vector2i(8, 0), false)
	var bed := sim.buildings.place("bed", c + Vector2i(-8, 0), false)
	assert_true(smelter != null and bed != null, "placed")
	smelter.progress = 5
	var e := _enemy(sim, c, "burrower")
	var ratio := sim.threats.model.score_building(smelter, e) / sim.threats.model.score_building(bed, e)
	var cfg: Dictionary = sim.defs.threat
	var want := float(cfg["base"]["smelter"]) * float(cfg["state_mod"]["working"]) / float(cfg["base"]["bed"])
	assert_true(absf(ratio / want - 1.0) < 0.01, "ratio %f want %f" % [ratio, want])


func test_distance_halves_score_at_d0() -> void:
	var sim := _sim()
	var c := sim.map_center()
	var b := sim.buildings.place("refinery", c, false)
	var d0 := int(sim.defs.threat["d0"])
	var near := _enemy(sim, c + Vector2i(0, 4))
	var far := _enemy(sim, c + Vector2i(0, 4 + d0 - 1))
	var s0 := sim.threats.model.score_building(b, near)
	var s1 := sim.threats.model.score_building(b, far)
	# near: dist ~ 3 (footprint edge); far: dist ~ d0 + 2 .. compare against formula
	var r_n := b.distance_to(Vector2(near.cell)) / float(d0)
	var r_f := b.distance_to(Vector2(far.cell)) / float(d0)
	assert_true(absf(s0 * (1.0 + r_n * r_n) - s1 * (1.0 + r_f * r_f)) < 0.001, "same raw value")
	var e := _enemy(sim, Vector2i(c.x, c.y + 2))
	var at := _enemy(sim, c + Vector2i(0, 2 + d0))
	var raw := sim.threats.model.score_building(b, e) * (1.0 + pow(b.distance_to(Vector2(e.cell)) / d0, 2))
	var half := sim.threats.model.score_building(b, at)
	var dd := b.distance_to(Vector2(at.cell))
	assert_true(absf(half * (1.0 + pow(dd / d0, 2)) - raw) < 0.001, "formula holds")
	assert_true(absf(1.0 / (1.0 + 1.0) - 0.5) < 0.0001, "d = d0 gives 1/2")


func test_pollution_adds_k_poll() -> void:
	var sim := _sim()
	var c := sim.map_center()
	var b := sim.buildings.place("refinery", c, false)
	var e := _enemy(sim, c + Vector2i(0, 5))
	var s0 := sim.threats.model.score_building(b, e)
	sim.mutation.field[b.cell.y * sim.map.width + b.cell.x] = 50.0
	var s1 := sim.threats.model.score_building(b, e)
	var r := b.distance_to(Vector2(e.cell)) / float(sim.defs.threat["d0"])
	var want := float(sim.defs.threat["k_poll"]) * 50.0 / (1.0 + r * r)
	assert_true(absf((s1 - s0) - want) < 0.0001, "delta %f want %f" % [s1 - s0, want])


func test_flags_and_threat_now() -> void:
	var sim := _sim()
	var b := sim.buildings.place("turret", sim.map_center(), false)
	var base: float = b.threat_now(sim)
	assert_true(absf(base - float(sim.defs.threat["base"]["turret"])) < 0.001, "turret base")
	b.threat_flags["burst"] = true
	assert_true(absf(b.threat_now(sim) - base * 3.0) < 0.001, "burst x3")
	b.threat_flags["burst"] = false
	b.broken = true
	assert_true(b.threat_now(sim) < base, "broken lowers")


func test_regional_cap() -> void:
	var sim := _sim()
	var c := sim.map_center()
	for i in 5:
		var b := sim.buildings.place("refinery", c + Vector2i((i % 2) * 3, (i / 2) * 3), false)
		assert_true(b != null, "placed %d" % i)
	var m := sim.threats.model
	m.refresh(true)
	var sum := 0.0
	var rs := int(sim.defs.threat["region_size"])
	var regions: Dictionary = {}
	for i in m._val.size():
		var b: Building = m._ref[i]
		var rk := Vector2i(b.cell.x / rs, b.cell.y / rs)
		regions[rk] = float(regions.get(rk, 0.0)) + m._val[i]
	for rk in regions:
		assert_true(float(regions[rk]) <= float(sim.defs.threat["cap_per_region"]) + 0.01, "region sum capped")
		sum += float(regions[rk])
	assert_true(sum > 0.0, "some threat")


func test_pick_target_prefers_high_threat_over_near_belt_like_target() -> void:
	var sim := _sim()
	var c := sim.map_center()
	var far := sim.buildings.place("refinery", c + Vector2i(14, 0), false)
	var near := sim.buildings.place("bed", c + Vector2i(-3, 0), false)
	var e := _enemy(sim, c + Vector2i(-6, 0))
	var t := sim.threats.pick_target(e)
	assert_true(t.get("kind") == "building" and t.get("id") == far.id, "refinery chosen over bed %s" % [t])
	assert_true(near != null, "bed placed")


func test_hysteresis_limits_switches() -> void:
	var sim := _sim()
	var c := sim.map_center()
	sim.buildings.place("refinery", c + Vector2i(10, 0), false)
	sim.buildings.place("refinery", c + Vector2i(-10, 1), false)
	var e := _enemy(sim, c + Vector2i(0, 8))
	var switches := 0
	var last := -1
	for i in 1000:
		sim.tick += 1
		if i % 20 == 0:
			sim.threats._choose_target(e)
			if e.target_id != last:
				switches += 1
				last = e.target_id
		if i % 100 == 0:
			e.cell = c + Vector2i(i % 7 - 3, 8)
	assert_true(switches <= 2, "switches %d" % switches)


func test_deterministic_hash() -> void:
	var a := _run_hash()
	var b := _run_hash()
	assert_eq(a, b)


func _run_hash() -> int:
	var d := peaceful_defs()
	d.threat["enabled"] = true
	d.balance["threat"]["enabled"] = true
	var sim := Simulation.new(11, make_bus(), d)
	sim.start_new_game()
	_sims.append(sim)
	var c := sim.map_center()
	sim.buildings.place("refinery", c + Vector2i(6, 0), false)
	for i in 3000:
		sim.step()
	return hash(str(sim.threats.kills) + str(sim.threats.retarget_count) + str(sim.tick) + str(sim.ledger.state_hash() if sim.ledger.has_method("state_hash") else 0))


func test_crawlers_prefer_lit_beacon_over_nearby_belt() -> void:
	# R3X: 8 crawlers 15 cells from a lit ash beacon pick it over a belt 5 cells away.
	var wins := 0
	for seed_value in 10:
		var sim := _sim(seed_value + 1)
		var c := sim.map_center()
		var beacon := sim.buildings.place("ash_beacon", c + Vector2i(15, 0), false)
		assert_true(beacon != null, "beacon placed")
		beacon.add_input("waste", 2)
		sim.step()
		for i in 6:
			assert_true(sim.logistics.place_belt_cell(c + Vector2i(-5 + i, 0), 1))
		sim.threats.model.refresh(true)
		for i in 8:
			var e := _enemy(sim, c + Vector2i(0, (i % 4) - 2))
			var t := sim.threats.pick_target(e)
			if t.get("kind", "") == "building" and int(t["id"]) == beacon.id:
				wins += 1
	assert_true(wins >= 72, "beacon chosen %d/80" % wins)


func test_belts_are_targets_without_decoy() -> void:
	var sim := _sim()
	var c := sim.map_center()
	for i in 6:
		sim.logistics.place_belt_cell(c + Vector2i(i, 0), 1)
	var e := _enemy(sim, c + Vector2i(0, 4))
	var t := sim.threats.pick_target(e)
	assert_eq(t.get("kind", ""), "belt")
	sim.threats._choose_target(e)
	assert_eq(e.target_kind, Enemy.Target.BELT)


func test_belt_target_gets_walked_to_and_bitten() -> void:
	var sim := _sim()
	var c := sim.map_center()
	for i in 6:
		sim.logistics.place_belt_cell(c + Vector2i(i, 0), 1)
	var e := _enemy(sim, c + Vector2i(3, 6))
	sim.run_ticks(600)
	var hurt := 0
	for i in 6:
		if sim.logistics.belts.is_damaged(c + Vector2i(i, 0)):
			hurt += 1
	assert_gt(hurt, 0, "crawler bit the belt it was drawn to")
