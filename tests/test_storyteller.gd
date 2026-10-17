extends TestCase
## E9: storyteller events, each breaking exactly one link.


func _colony(seed_value := 31) -> Simulation:
	var defs := peaceful_defs()
	var sim := make_sim(seed_value, true, 24, 24, defs)
	var scen := preload("res://tests/scenario.gd")
	scen.standard_colony(sim, 2)
	return sim


func test_lightning_breaks_one_machine_and_it_gets_repaired() -> void:
	var sim := _colony()
	assert_true(sim.storyteller.fire("lightning"))
	var broken := 0
	for b in sim.buildings.list:
		if b.broken:
			broken += 1
	assert_eq(broken, 1, "exactly one machine broken")
	sim.run_ticks(600)
	for b in sim.buildings.list:
		assert_false(b.broken, "%s should be repaired" % b.def["name"])


func test_sickness_stops_work_then_recovers() -> void:
	var sim := _colony()
	assert_true(sim.storyteller.fire("sickness"))
	var sick: Colonist = null
	for c in sim.colonists.list:
		if c.is_sick(sim.tick):
			sick = c
	assert_true(sick != null)
	var cell := sick.cell
	sim.run_ticks(100)
	assert_true(sick.job == null, "sick colonist must not work")
	assert_eq(sick.cell, cell, "sick colonist stays put")
	sim.run_ticks(int(sim.defs.events["sickness"]["duration_ticks"]))
	sim.run_ticks(30)
	assert_false(sick.is_sick(sim.tick))
	assert_true(sick.job != null or sick.idle_until > 0, "recovered colonist goes back to work")


func test_sickness_never_takes_the_last_worker() -> void:
	var sim := make_sim(32, false, 12, 12, peaceful_defs())
	sim.colonists.spawn(Vector2i(2, 2))
	assert_false(sim.storyteller.fire("sickness"))


func test_cave_in_seals_designated_deposit_and_is_accounted() -> void:
	var sim := _colony()
	var before := sim.map.total_deposit_amount()
	assert_true(sim.storyteller.fire("cave_in"))
	assert_gt(sim.map.deposit_lost, 0)
	assert_eq(before - sim.map.total_deposit_amount(), sim.map.deposit_lost)


func test_only_one_broken_link_at_a_time() -> void:
	var sim := _colony()
	sim.storyteller.fire("lightning")
	assert_false(sim.storyteller.colony_is_whole(), "no new event while something is broken")


func test_events_happen_and_are_deterministic() -> void:
	var a := _colony(40)
	var b := _colony(40)
	var log_a: Array[String] = []
	var log_b: Array[String] = []
	a.bus.story_event.connect(func(id: String, _t: String) -> void: log_a.append("%d:%s" % [a.tick, id]))
	b.bus.story_event.connect(func(id: String, _t: String) -> void: log_b.append("%d:%s" % [b.tick, id]))
	a.run_ticks(a.ticks_per_day * 8)
	b.run_ticks(b.ticks_per_day * 8)
	assert_eq(log_a, log_b)
	var total := 0
	for id in a.storyteller.fired:
		total += int(a.storyteller.fired[id])
	assert_gt(total, 1, "storyteller should fire a few events in 8 days")
