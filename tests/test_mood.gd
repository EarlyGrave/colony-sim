extends TestCase
## Basic mood: thoughts, expiry, death, breaks, determinism.


func _sim(seed_value := 5) -> Simulation:
	var d := peaceful_defs()
	d.mood["minor_chance"] = 1.0
	d.mood["extreme_chance"] = 1.0
	return make_sim(seed_value, true, 24, 24, d)


func _push(sim: Simulation, c: Colonist, v: float) -> void:
	sim.mood.state_of(c).thoughts.append({"id": "x", "value": v, "until": -1})
	sim.mood._recalc(c.mood)


func test_thought_changes_mood_and_expires() -> void:
	var sim := _sim()
	var c: Colonist = sim.colonists.list[0]
	var base := sim.mood.mood_of(c)
	assert_true(sim.mood.add_thought(c, "ate_raw"))
	assert_lt(sim.mood.mood_of(c), base)
	assert_false(sim.mood.add_thought(c, "no_such_thought"))
	sim.run_ticks(sim.ticks_per_day + 100)
	assert_near(sim.mood.mood_of(c), base, 0.01, "expired")


func test_colonist_death_lowers_others() -> void:
	var sim := _sim()
	var a: Colonist = sim.colonists.list[0]
	var b: Colonist = sim.colonists.list[1]
	var before := sim.mood.mood_of(b)
	sim.colonists.kill(a)
	assert_lt(sim.mood.mood_of(b), before)


func test_injury_thought() -> void:
	var sim := _sim()
	var c: Colonist = sim.colonists.list[0]
	sim.health.apply_damage(c, 5.0, "arms", "cut")
	sim.run_ticks(60)
	assert_true(c.mood.find("injured") >= 0)


func test_low_mood_wander_break() -> void:
	var sim := _sim()
	var c: Colonist = sim.colonists.list[0]
	_push(sim, c, -20.0)
	assert_lt(c.mood.value, 35.0)
	assert_gt(c.mood.value, 15.0)
	var kinds: Array = []
	sim.bus.mood_break_started.connect(func(_id: int, k: String) -> void: kinds.append(k))
	sim.run_ticks(sim.ticks_per_day + 5)
	assert_eq(kinds, ["wander"])
	assert_eq(c.job.type, "mental_break")


func test_extreme_break_sabotages_machine() -> void:
	var sim := _sim()
	var scen := preload("res://tests/scenario.gd")
	scen.standard_colony(sim, 1)
	var c: Colonist = sim.colonists.list[0]
	_push(sim, c, -45.0)
	var kinds: Array = []
	sim.bus.mood_break_started.connect(func(_id: int, k: String) -> void: kinds.append(k))
	sim.run_ticks(sim.ticks_per_day + 5)
	assert_eq(kinds, ["sabotage"])
	var broken := 0
	for b in sim.buildings.list:
		if b.is_machine() and b.broken:
			broken += 1
	assert_eq(broken, 1)


func _trace(seed_value: int) -> Array:
	var sim := _sim(seed_value)
	var c: Colonist = sim.colonists.list[0]
	_push(sim, c, -25.0)
	sim.run_ticks(sim.ticks_per_day * 2)
	return [c.cell, c.mood.break_kind, sim.rng.randi()]


func test_deterministic() -> void:
	assert_eq(_trace(9), _trace(9))
