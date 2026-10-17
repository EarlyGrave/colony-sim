extends TestCase
## Injuries, bleeding, downed state, tending, illness.

const MAX_BLEED_TICKS := 1500


func _colony(seed_value := 41) -> Simulation:
	var sim := make_sim(seed_value, true, 24, 24, peaceful_defs())
	var scen := preload("res://tests/scenario.gd")
	scen.standard_colony(sim, 2)
	for c in sim.colonists.list:  # these tests are about the body, not doctors
		sim.set_work_priority(c.id, "doctoring", 0)
	return sim


func test_untended_bleeding_kills() -> void:
	var sim := _colony()
	var c: Colonist = sim.colonists.list[0]
	sim.health.apply_damage(c, 30.0, "torso", "cut")
	var downed_at := -1
	for t in MAX_BLEED_TICKS:
		sim.step()
		if downed_at < 0 and c.health.downed:
			downed_at = t
		if not c.alive:
			break
	assert_true(downed_at >= 0, "should be downed before dying")
	assert_false(c.alive, "untended bleeding must kill within %d ticks" % MAX_BLEED_TICKS)


func test_tended_stops_bleeding() -> void:
	var sim := _colony()
	var c: Colonist = sim.colonists.list[0]
	sim.health.apply_damage(c, 30.0, "torso", "cut")
	assert_gt(c.health.bleed_rate(), 0.0)
	assert_eq(sim.health.tend(c, null), 1)
	assert_eq(c.health.bleed_rate(), 0.0)
	sim.run_ticks(MAX_BLEED_TICKS)
	assert_true(c.alive)


func test_downed_cannot_work_or_move() -> void:
	var sim := _colony()
	var c: Colonist = sim.colonists.list[0]
	c.carry_item = "essence_ore"
	c.carry_count = 3
	sim.ledger.record_produced("essence_ore", 3, "test")
	sim.health.apply_damage(c, 70.0, "legs", "bullet")
	assert_true(c.health.downed)
	assert_eq(c.carry_count, 0, "carried items dropped")
	var cell := c.cell
	sim.run_ticks(60)
	assert_eq(c.cell, cell)
	assert_true(c.job == null)
	for id in sim.defs.items:
		assert_eq(sim.items.count_world(id), sim.ledger.balance_of(id), "%s conserved" % id)


func test_sickness_is_an_illness() -> void:
	var sim := _colony()
	assert_true(sim.storyteller.fire("sickness"))
	var sick := 0
	for c in sim.colonists.list:
		if c.is_sick(sim.tick):
			sick += 1
			assert_true(c.health.is_sick())
	assert_eq(sick, 1)


func test_tend_quality_reads_skills() -> void:
	var sim := _colony()
	var c: Colonist = sim.colonists.list[0]
	assert_eq(sim.health.tend_quality(null), 0.5)
	var t: Dictionary = sim.defs.health["tend"]
	assert_near(sim.health.tend_quality(c), float(t["base_quality"]) + c.skills.level("medicine") * float(t["per_skill_level"]), 0.001)


func test_minor_wounds_heal() -> void:
	var sim := _colony()
	var c: Colonist = sim.colonists.list[0]
	sim.health.apply_damage(c, 3.0, "arms", "bruise")
	sim.health.tend(c, null)
	sim.run_ticks(600)
	assert_true(c.health.injuries.is_empty())
	assert_true(c.alive)


func _run(seed_value: int) -> String:
	var sim := _colony(seed_value)
	var c: Colonist = sim.colonists.list[0]
	sim.health.apply_damage(c, 12.0, "", "cut")
	sim.health.apply_damage(c, 8.0, "", "bite")
	sim.run_ticks(800)
	return "%d %.5f %d" % [c.health.injuries.size(), c.health.blood, c.cell.x * 1000 + c.cell.y]


func test_deterministic() -> void:
	assert_eq(_run(5), _run(5))
