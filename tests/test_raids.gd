extends TestCase
## Raids: points budget, raid types, spitters, morale. data/raids.json.


func _strong_defs() -> Defs:
	var d := Defs.get_default().duplicate_defs()
	d.balance["threat"]["base_strength"] = 40.0
	return d


## 40x40 empty map with a capsule and a refinery in the middle.
func _base(seed_value := 11, defs: Defs = null) -> Simulation:
	var sim := make_sim(seed_value, false, 40, 40, defs)
	sim.buildings.place("hq", Vector2i(19, 19), false)
	sim.buildings.place("refinery", Vector2i(24, 19), false)
	return sim


func _edge_dist(sim: Simulation, c: Vector2i) -> int:
	return mini(mini(c.x, c.y), mini(sim.map.width - 1 - c.x, sim.map.height - 1 - c.y))


func test_points_scale_with_wealth() -> void:
	var sim := _base()
	var base := sim.threats.raid_points(1)
	sim.items.add_at(Vector2i(5, 5), "essence_ore", 40)
	var with_ore := sim.threats.raid_points(1)
	assert_gt(with_ore, base, "stored items add points")
	sim.items.add_at(Vector2i(6, 5), "refined_essence", 40)
	assert_gt(sim.threats.raid_points(1), with_ore, "refined stock is worth more")
	var before := sim.threats.raid_points(1)
	sim.buildings.place("turret", Vector2i(10, 10), false)
	assert_gt(sim.threats.raid_points(1), before, "buildings add points")
	before = sim.threats.raid_points(1)
	sim.colonists.spawn(Vector2i(3, 3))
	assert_gt(sim.threats.raid_points(1), before, "colonists add points")
	assert_eq(sim.threats.wave_strength(2), sim.threats.raid_points(2))


func test_raid_type_follows_points() -> void:
	var sim := _base()
	for i in 20:
		assert_eq(sim.threats.pick_raid_type(0.5), "swarm", "tiny budgets only get swarms")
	var seen := {}
	for i in 200:
		seen[sim.threats.pick_raid_type(60.0)] = true
	for id: String in sim.defs.raids:
		assert_true(seen.has(id), "%s should be reachable at high points" % id)


func test_swarm_spawns_crawlers_at_edge() -> void:
	var sim := _base(11, _strong_defs())
	sim.threats.force_raid_id = "swarm"
	sim.threats.awaken()
	sim.threats.start_wave()
	assert_gt(sim.threats.enemies.size(), 1)
	for e in sim.threats.enemies:
		assert_eq(e.def_id, "crawler")
		assert_true(_edge_dist(sim, e.cell) <= int(sim.threats.cfg["spawn_scatter"]), "swarm comes from the edge")


func test_brute_pack_has_brutes() -> void:
	var sim := _base(12, _strong_defs())
	sim.threats.force_raid_id = "brute_pack"
	sim.threats.start_wave()
	var brutes := 0
	for e in sim.threats.enemies:
		assert_true(e.def_id in ["brute", "crawler"])
		if e.def_id == "brute":
			brutes += 1
	assert_gt(brutes, 2)


func test_burrowers_drop_near_building_after_tremor() -> void:
	var sim := _base(13, _strong_defs())
	var tremors: Array = []
	sim.bus.raid_tremor.connect(func(c: Vector2i, t: int, text: String) -> void: tremors.append([c, t, text]))
	sim.threats.force_raid_id = "burrowers"
	sim.threats.start_wave()
	assert_eq(sim.threats.enemies.size(), 0, "nothing yet: only a tremor")
	assert_eq(tremors.size(), 1)
	assert_ne(tremors[0][2], "", "burrowers have their own warning text")
	assert_false(sim.threats.pending_drop.is_empty())
	sim.run_ticks(int(tremors[0][1]) - 2)
	assert_eq(sim.threats.enemies.size(), 0)
	assert_true(sim.threats.wave_active, "wave does not end during the tremor")
	sim.run_ticks(4)
	assert_gt(sim.threats.enemies.size(), 0, "burrowers surface after the tremor")
	for e in sim.threats.enemies:
		assert_eq(e.def_id, "burrower")
		var near := false
		for building in sim.buildings.list:
			if building.distance_to(Vector2(e.cell)) <= 4.0:
				near = true
		assert_true(near, "burrower at %s is not near a building" % str(e.cell))
		assert_gt(_edge_dist(sim, e.cell), 3, "not an edge spawn")


func test_spitter_hits_colonist_through_health() -> void:
	var sim := make_sim(14, false, 30, 30, peaceful_defs())
	var c := sim.colonists.spawn(Vector2i(10, 10))
	var e := sim.threats._spawn("spitter", Vector2i(14, 10))
	e.move_ticks = 1000000
	for i in 40:
		sim.threats._tick_enemy(e)
	assert_ne(c.health, null)
	var burns := 0
	for inj in c.health.injuries:
		if inj.kind == "burn":
			burns += 1
	assert_gt(burns, 0, "acid burns the colonist from range")
	assert_gt(Vector2(c.cell).distance_to(Vector2(e.cell)), 3.0, "spitter shoots from a distance")


func test_spitter_damages_buildings() -> void:
	var sim := make_sim(15, false, 30, 30, peaceful_defs())
	var b := sim.buildings.place("refinery", Vector2i(10, 10), false)
	var e := sim.threats._spawn("spitter", Vector2i(16, 10))
	e.move_ticks = 1000000
	var hp := b.hp
	for i in 60:
		sim.threats._tick_enemy(e)
	assert_lt(b.hp, hp, "ranged acid damages buildings")


func test_raid_retreats_after_heavy_casualties() -> void:
	var sim := _base(16, _strong_defs())
	var retreats := [0]
	sim.bus.raid_retreat.connect(func(_id: String) -> void: retreats[0] += 1)
	sim.threats.force_raid_id = "swarm"
	sim.threats.start_wave()
	var t := sim.threats
	var total := t.raid_total
	assert_gt(total, 8)
	var frac := float(sim.defs.raids["swarm"]["retreat_fraction"])
	var killed := 0
	while float(killed) / float(total) <= frac:
		assert_false(t.retreating, "no retreat before the threshold")
		t.damage_enemy(t.enemies[0], 9999.0)
		killed += 1
	assert_true(t.retreating)
	assert_eq(retreats[0], 1)
	assert_gt(t.enemies.size(), 0, "survivors remain")
	for e in t.enemies:
		assert_true(e.leaving)
	sim.run_ticks(2)
	assert_false(t.wave_active, "wave ends once everyone turns back")


func test_raids_are_deterministic() -> void:
	var log_a := _raid_log(21)
	var log_b := _raid_log(21)
	assert_eq(log_a, log_b)
	assert_gt(log_a.size(), 0)


func _raid_log(seed_value: int) -> Array:
	var sim := _base(seed_value, _strong_defs())
	var out: Array = []
	for i in 4:
		sim.threats.start_wave()
		out.append(sim.threats.raid_id)
		for e in sim.threats.enemies:
			out.append([e.def_id, e.cell])
		out.append(sim.threats.pending_drop.get("cell", Vector2i(-1, -1)))
		sim.run_ticks(80)
		sim.threats.end_wave()
	return out
