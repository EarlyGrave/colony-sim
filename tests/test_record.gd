extends TestCase
const Scenario := preload("res://tests/scenario.gd")
## F3: colonist records, nicknames, rap sheets, barks, commendations.


func test_counters_match_bus_facts() -> void:
	var sim := make_sim(2)
	Scenario.standard_colony(sim, 2)
	Scenario.designate_nearest_deposits(sim, 4)
	var ore := [0]
	var downs := [0]
	var waves := [0]
	sim.bus.item_mined.connect(func(_c: Vector2i, _i: String, n: int) -> void: ore[0] += n)
	sim.bus.colonist_downed.connect(func(_i: int) -> void: downs[0] += 1)
	sim.bus.wave_ended.connect(func(_i: int) -> void: waves[0] += 1)
	var survivors_waves := 0
	sim.run_ticks(3000)
	var o := 0
	var d := 0
	for c in sim.colonists.list:
		o += sim.colonists.rec(c)["ore_mined"]
		d += sim.colonists.rec(c)["downs"]
		survivors_waves = maxi(survivors_waves, sim.colonists.rec(c)["waves_survived"])
	assert_gt(ore[0], 0, "scenario mined nothing")
	assert_eq(o, ore[0], "ore counters differ from bus")
	assert_eq(d, downs[0], "down counters differ from bus")
	assert_true(survivors_waves <= waves[0])


func test_hash_ignores_records() -> void:
	var a := make_sim(2)
	var b := make_sim(2)
	Scenario.standard_colony(a, 1)
	Scenario.standard_colony(b, 1)
	a.run_ticks(300)
	b.run_ticks(300)
	for c in b.colonists.list:
		b.colonists.rec(c)["ore_mined"] += 999
		b.colonists.add_kill(c, "crawler")
		b.colonists.rec(c)["nick_stat"] = "kills"
	assert_eq(SaveGame.state_hash(a), SaveGame.state_hash(b))


func test_nickname_permanent_once_earned() -> void:
	var sim := make_sim(3, false, 24, 24)
	var c := sim.colonists.spawn(Vector2i(2, 2))
	assert_eq(ColonistRecord.nickname(c, sim.colonists.rec(c), sim.defs.names), "")
	var need := int(sim.defs.balance["flavor"]["nick_kills"])
	for i in need:
		sim.colonists.add_kill(c, "crawler")
	sim.colonists.record_changed(c)
	assert_eq(sim.colonists.rec(c)["nick_stat"], "kills")
	var nm := ColonistRecord.nickname(c, sim.colonists.rec(c), sim.defs.names)
	assert_ne(nm, "")
	sim.colonists.rec(c)["ore_mined"] = 100000
	sim.colonists.record_changed(c)
	assert_eq(sim.colonists.rec(c)["nick_stat"], "kills", "nickname must not change")
	assert_eq(ColonistRecord.nickname(c, sim.colonists.rec(c), sim.defs.names), nm)


func test_rap_sheet_stable_and_varied() -> void:
	var names := Defs.get_default().names
	var seen := {}
	for id in range(1, 21):
		var a := ColonistRecord.rap_sheet(id, names)
		assert_eq(a, ColonistRecord.rap_sheet(id, names))
		seen[str(a)] = true
	assert_true(seen.size() >= 18, "rap sheets too similar: %d" % seen.size())


func test_bark_cooldown_90s() -> void:
	var sim := make_sim(4, false, 24, 24)
	var c := sim.colonists.spawn(Vector2i(2, 2))
	var layer := BarkLayer.new()
	layer.sim = sim
	assert_true(layer.try_bark(c, "working"))
	sim.tick += 89 * Simulation.TICKS_PER_SECOND
	layer.bubbles.clear()
	assert_false(layer.try_bark(c, "working"), "second bark inside 90 s")
	sim.tick += 2 * Simulation.TICKS_PER_SECOND
	assert_true(layer.try_bark(c, "working"), "bark after cooldown")
	layer.free()


func test_bark_visible_cap() -> void:
	var sim := make_sim(4, false, 24, 24)
	var layer := BarkLayer.new()
	layer.sim = sim
	var n := 0
	for i in 4:
		if layer.try_bark(sim.colonists.spawn(Vector2i(2 + i, 2)), "working"):
			n += 1
	assert_eq(n, 2)
	for l in layer.bubbles:
		l.free()
	layer.free()


func test_commendations_fire_once() -> void:
	var sim := make_sim(5, false, 24, 24)
	var c := sim.colonists.spawn(Vector2i(2, 2))
	var letters := [0]
	sim.bus.letter_received.connect(func(_t: String, _x: String) -> void: letters[0] += 1)
	sim.colonists.rec(c)["waves_survived"] = 1
	sim.bus.day_started.emit(1)
	sim.bus.day_started.emit(2)
	assert_eq(letters[0], 1)
	assert_true(sim.colonists.commended.has("participation_ribbon"))
	assert_true(sim.defs.milestones["commendations"].size() >= 5)
