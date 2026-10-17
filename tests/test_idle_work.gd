extends TestCase
## Idle-to-work: scrub / patrol / training givers, determinism, route save/load.


func _scene() -> Simulation:
	var sim := make_sim(5, false, 40, 40, peaceful_defs())
	return sim


func _run_to_job(sim: Simulation, c: Colonist, job_type: String, ticks := 20) -> bool:
	for i in ticks:
		sim.jobs.tick_colonist(c)
		if c.job != null and c.job.type == job_type:
			return true
		sim.step()
	return false


func test_defaults_are_lowest_priority() -> void:
	var sim := _scene()
	var c := sim.colonists.spawn(Vector2i(20, 20))
	for t in ["cleanup", "patrol", "training"]:
		assert_eq(c.skills.priority(t), 4, t)
	assert_eq(c.skills.priority("mining"), 3)


func test_scrub_removes_waste_and_contamination() -> void:
	var sim := _scene()
	var c := sim.colonists.spawn(Vector2i(20, 20))
	sim.ledger.record_produced("waste", 5, "test")
	sim.items.add_at(Vector2i(22, 20), "waste", 5)
	sim.contamination.level = 10.0
	assert_true(_run_to_job(sim, c, "scrub"), "no scrub job")
	var before := sim.contamination.level
	sim.run_ticks(200)
	assert_lt(sim.contamination.level, before, "contamination did not drop")
	assert_lt(sim.items.count_on_ground("waste"), 5)
	assert_gt(sim.idle_work.scrubbed_total, 0.0)


func test_scrub_is_capped() -> void:
	var sim := _scene()
	sim.contamination.level = 6.0
	sim.idle_work.scrubbed_total = 4.0  # 40% of 10 already scrubbed
	assert_false(sim.idle_work.can_scrub())
	var c := sim.colonists.spawn(Vector2i(20, 20))
	sim.items.add_at(Vector2i(22, 20), "waste", 5)
	assert_false(_run_to_job(sim, c, "scrub"), "scrubbed past the cap")


func test_scrub_can_make_colonist_ill() -> void:
	var defs := peaceful_defs()
	defs.idle_work["cleanup"]["illness_chance"] = 1.0
	var sim := make_sim(5, false, 40, 40, defs)
	var c := sim.colonists.spawn(Vector2i(20, 20))
	sim.items.add_at(Vector2i(21, 20), "waste", 5)
	sim.contamination.level = 10.0
	sim.run_ticks(150)
	assert_true(c.health != null and not c.health.injuries.is_empty(), "no illness after scrubbing")


func test_patrol_walks_route_and_trains() -> void:
	var sim := _scene()
	var c := sim.colonists.spawn(Vector2i(20, 20))
	var pts: Array[Vector2i] = [Vector2i(10, 10), Vector2i(30, 10), Vector2i(30, 30)]
	sim.set_patrol_route(pts)
	var xp_before: float = c.skills.xp["melee"] + c.skills.xp["shooting"] + c.skills.level("melee") * 1000 + c.skills.level("shooting") * 1000
	assert_true(_run_to_job(sim, c, "patrol"), "no patrol job")
	sim.run_ticks(60)
	assert_gt(c.cell.distance_to(Vector2(20, 20)), 3.0, "did not move along route")
	var xp_after: float = c.skills.xp["melee"] + c.skills.xp["shooting"] + c.skills.level("melee") * 1000 + c.skills.level("shooting") * 1000
	assert_gt(xp_after, xp_before, "no xp")
	assert_gt(sim.idle_work.warning_bonus(), 0, "vigil bonus missing")


func test_patrol_auto_route_is_passable() -> void:
	var sim := _scene()
	var r := sim.idle_work.route()
	assert_gt(r.size(), 3)
	for p in r:
		assert_true(sim.map.is_passable(p))


func test_patrol_spots_enemy() -> void:
	var sim := make_sim(5, false, 40, 40)
	var c := sim.colonists.spawn(Vector2i(20, 20))
	var seen: Array = []
	sim.bus.patrol_spotted.connect(func(id: int, _cell: Vector2i, n: int) -> void: seen.append([id, n]))
	var def_id: String = sim.defs.enemies.keys()[0]
	sim.threats._spawn(def_id, Vector2i(24, 20))
	sim.idle_work.patrol_scan(c)
	assert_eq(seen.size(), 1)
	assert_gt(sim.idle_work.spot_bonus_ticks, 0)
	sim.idle_work.patrol_scan(c)
	assert_eq(seen.size(), 1, "spotted twice in one wave")


func test_training_dummy_trains_lowest_skill_with_daily_cap() -> void:
	var sim := _scene()
	var c := sim.colonists.spawn(Vector2i(20, 20))
	c.skills.levels["melee"] = 5
	c.skills.levels["shooting"] = 1
	sim.buildings.place("training_dummy", Vector2i(23, 20), false)
	assert_eq(sim.idle_work.training_skill(c), "shooting")
	var level_xp: float = c.skills.xp["shooting"]
	sim.run_ticks(400)
	var cap := float(sim.defs.idle_work["training"]["daily_xp_cap"])
	assert_gt(c.skills.xp["shooting"] + c.skills.level("shooting") * 1000.0, level_xp + 1000.0 * 1, "shooting did not improve")
	assert_eq(c.skills.xp["melee"], 0.0, "trained the wrong skill")
	assert_true(sim.idle_work.training_left(c) >= 0.0 and sim.idle_work.training_left(c) < cap)


func test_training_cap_stops_work() -> void:
	var sim := _scene()
	var c := sim.colonists.spawn(Vector2i(20, 20))
	sim.buildings.place("training_dummy", Vector2i(23, 20), false)
	var cap := float(sim.defs.idle_work["training"]["daily_xp_cap"])
	var skill := sim.idle_work.training_skill(c)
	for i in int(cap / float(sim.defs.idle_work["training"]["xp_per_tick"])) + 5:
		sim.idle_work.train_tick(c, skill)
	assert_eq(sim.idle_work.training_left(c), 0.0)
	assert_false(_run_to_job(sim, c, "train", 5), "trained past the cap")


func test_deterministic() -> void:
	var hashes: Array[int] = []
	for run in 2:
		var defs := peaceful_defs()
		defs.idle_work["cleanup"]["illness_chance"] = 0.5
		var sim := make_sim(7, false, 40, 40, defs)
		sim.colonists.spawn(Vector2i(20, 20))
		sim.colonists.spawn(Vector2i(21, 20))
		sim.buildings.place("training_dummy", Vector2i(25, 20), false)
		sim.items.add_at(Vector2i(22, 24), "waste", 8)
		sim.contamination.level = 20.0
		sim.run_ticks(1200)
		hashes.append(SaveGame.state_hash(sim) + int(sim.contamination.level * 1000.0) + int(sim.idle_work.scrubbed_total * 1000.0))
	assert_eq(hashes[0], hashes[1])


func test_patrol_route_save_load() -> void:
	var sim := make_sim(11, true, 24, 24, peaceful_defs())
	var pts: Array[Vector2i] = [Vector2i(5, 5), Vector2i(12, 5), Vector2i(12, 12)]
	sim.set_patrol_route(pts)
	sim.run_ticks(50)
	var r := SaveGame.load_json(SaveGame.to_json(sim), make_bus(), peaceful_defs())
	assert_true(r["ok"], str(r["error"]))
	var loaded: Simulation = r["sim"]
	_sims.append(loaded)
	assert_eq(loaded.idle_work.patrol_route, sim.idle_work.patrol_route)
	assert_eq(SaveGame.state_hash(loaded), SaveGame.state_hash(sim))
