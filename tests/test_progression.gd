extends TestCase
## Progression: join-level baseline for perk points, event XP, award() hook.


func _colony() -> Array:
	var sim := make_sim(5, false, 20, 20, peaceful_defs())
	var c := sim.colonists.spawn(Vector2i(4, 4))
	return [sim, c]


func test_start_with_no_free_points() -> void:
	var sim := make_sim(7, true, 24, 24, peaceful_defs())
	for c in sim.colonists.list:
		for s: String in c.skills.levels:
			assert_eq(sim.perks.points_available(c, s), 0, s)
			assert_eq(c.skills.join_level(s), c.skills.level(s))


func test_join_level_3_gets_next_point_at_4() -> void:
	var r := _colony()
	var sim: Simulation = r[0]
	var c: Colonist = r[1]
	c.skills.levels["mining"] = 3
	c.skills.mark_joined()
	assert_eq(sim.perks.points_available(c, "mining"), 0)
	c.skills.levels["mining"] = 4
	assert_eq(sim.perks.points_available(c, "mining"), 1)
	c.skills.levels["mining"] = 6
	assert_eq(sim.perks.points_available(c, "mining"), 2)


func test_arrivals_have_baseline() -> void:
	var sim := make_sim(9, false, 20, 20, peaceful_defs())
	var c := ColonistGenerator.generate(sim, Vector2i(3, 3))
	for s: String in c.skills.levels:
		assert_eq(c.skills.join_level(s), c.skills.level(s))
		assert_eq(sim.perks.points_available(c, s), 0)


func test_award_and_signal() -> void:
	var r := _colony()
	var sim: Simulation = r[0]
	var c: Colonist = r[1]
	var got: Array = []
	sim.bus.xp_awarded.connect(func(id: int, s: String, a: float, why: String) -> void: got.append([id, s, a, why]))
	c.skills.levels["medicine"] = 0
	c.skills.xp["medicine"] = 0.0
	assert_true(sim.progression.award(c, "medicine", 10.0, "test"))
	assert_eq(got.size(), 1)
	assert_eq(got[0][3], "test")
	assert_false(sim.progression.award(c, "nonsense", 10.0, "test"))
	assert_false(sim.progression.award(null, "medicine", 10.0, "test"))


func test_levels_via_xp_give_points() -> void:
	var r := _colony()
	var sim: Simulation = r[0]
	var c: Colonist = r[1]
	c.skills.levels["plants"] = 0
	c.skills.mark_joined()
	c.skills.passions["plants"] = Skills.Passion.NONE
	sim.progression.award(c, "plants", 100000.0, "test")
	assert_eq(c.skills.level("plants"), 10)
	assert_eq(sim.perks.points_available(c, "plants"), 5)


func test_day_and_rescue_and_wave_events() -> void:
	var r := _colony()
	var sim: Simulation = r[0]
	var c: Colonist = r[1]
	var got: Array = []
	sim.bus.xp_awarded.connect(func(_id: int, s: String, _a: float, why: String) -> void: got.append([s, why]))
	sim.bus.day_started.emit(2)
	assert_eq(got.size(), 1)
	assert_eq(got[0][1], "day_survived")
	got.clear()
	sim.bus.colonist_rescued.emit(99, c.id)
	assert_eq(got[0], ["medicine", "colonist_rescued"])
	got.clear()
	sim.bus.wave_repelled.emit(1)
	assert_eq(got[0][1], "wave_repelled")
	assert_true(["shooting", "melee"].has(got[0][0]))
	got.clear()
	sim.bus.event_choice_resolved.emit(1, true)
	assert_eq(got[0][1], "event_choice")


func test_wave_repelled_emitted_when_killed() -> void:
	var sim := make_sim(3, true, 24, 24)
	var n := [0]
	sim.bus.wave_repelled.connect(func(_i: int) -> void: n[0] += 1)
	sim.threats.start_wave()
	for e in sim.threats.enemies.duplicate():
		sim.threats.damage_enemy(e, 100000.0)
	sim.run_ticks(5)
	assert_eq(n[0], 1)


func test_first_refine_xp_to_operator() -> void:
	var r := _colony()
	var sim: Simulation = r[0]
	var c: Colonist = r[1]
	var got: Array = []
	sim.bus.xp_awarded.connect(func(id: int, s: String, _a: float, why: String) -> void: got.append([id, s, why]))
	sim.buildings.refined_batches = 1
	sim.buildings.batch_operator = c
	sim.bus.batch_refined.emit(1, "x")
	assert_eq(got, [[c.id, "operating", "first_refine"]])
