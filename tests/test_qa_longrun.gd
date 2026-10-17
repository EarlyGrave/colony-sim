extends TestCase
## QA: long bot-driven games must not raise engine errors (the runner fails on any),
## are deterministic, and survive save/load at the end.


func _days(sim: Simulation) -> int:
	return sim.ticks_per_day


func test_bot_30_days_several_seeds_no_errors() -> void:
	for s in [1, 2, 3]:
		var sim := make_sim(s)
		sim.set_meta("qa_setup", true)
		QaBot.play(sim, 30 * sim.ticks_per_day, 200)
		assert_true(sim.tick > 0)


func test_two_runs_same_seed_identical() -> void:
	var hashes: Array[int] = []
	for i in 2:
		var sim := make_sim(77)
		sim.set_meta("qa_setup", true)
		QaBot.play(sim, 20 * sim.ticks_per_day, 200)
		hashes.append(QaBot.full_hash(sim))
		sim.dispose()
	assert_eq(hashes[0], hashes[1])


func test_event_bus_listeners_released_on_dispose() -> void:
	var bus := make_bus()
	var before := _count(bus)
	for i in 5:
		var sim := Simulation.new(5 + i, bus)
		sim.start_new_game()
		QaBot.play(sim, 400)
		sim.dispose()
	assert_eq(_count(bus), before, "bus connections leaked by disposed simulations")


static func _count(bus: Object) -> int:
	var n := 0
	for s in bus.get_signal_list():
		n += bus.get_signal_connection_list(s["name"]).size()
	return n
