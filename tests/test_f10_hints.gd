extends TestCase
## F10W1: contextual one-shot hints (HintDirector) + SeenFlags.


var _shown: Array = []


func _setup_flags() -> void:
	SeenFlags.path = "user://test_seen_flags_%d.json" % OS.get_process_id()
	SeenFlags.reset()


func _show(t: String) -> void:
	_shown.append(t)


func _director(d := "Full") -> HintDirector:
	_setup_flags()
	_shown.clear()
	var h := HintDirector.new()
	h.density = d
	return h


func _poll(h: HintDirector, sim: Simulation, now: float) -> String:
	return h.poll(sim, now, _show)


func _sim() -> Simulation:
	var sim := make_sim(3, false, 30, 30, peaceful_defs())
	sim.tutorial = null
	return sim


func test_texts_short() -> void:
	var h := HintDirector.new()
	assert_eq(h.texts.size(), 5)
	for k: String in h.texts:
		assert_true(str(h.texts[k]).length() <= 70, k)


func test_gear_first_once() -> void:
	var h := _director()
	var sim := _sim()
	assert_eq(_poll(h, sim, 0.0), "")
	var c := sim.colonists.spawn(Vector2i(5, 5))
	sim.give_gear(c.id, "helmet", "common", 0)
	assert_eq(_poll(h, sim, 1.0), "gear_first")
	assert_eq(_shown.size(), 1)
	assert_eq(_poll(h, sim, 50.0), "")
	assert_eq(_shown.size(), 1)
	# a new director in the same profile stays silent
	var h2 := HintDirector.new()
	h2.density = "Full"
	assert_eq(_poll(h2, sim, 1.0), "")


func test_gear_damaged_and_rate_limit() -> void:
	var h := _director()
	var sim := _sim()
	var c := sim.colonists.spawn(Vector2i(5, 5))
	var id := sim.give_gear(c.id, "helmet", "common", 0)
	assert_eq(_poll(h, sim, 0.0), "gear_first")
	sim.equipment.set_durability(id, 10.0)
	assert_eq(_poll(h, sim, 3.0), "")  # < 10 s gap, stays queued
	assert_eq(_poll(h, sim, 10.5), "gear_damaged")


func test_stale_dropped() -> void:
	var h := _director()
	var sim := _sim()
	var c := sim.colonists.spawn(Vector2i(5, 5))
	var id := sim.give_gear(c.id, "helmet", "common", 0)
	sim.equipment.set_durability(id, 10.0)
	_poll(h, sim, 0.0)
	assert_eq(_poll(h, sim, 5000.0), "gear_damaged")  # re-scanned, fresh again


func test_bus_triggers() -> void:
	var h := _director()
	var sim := _sim()
	h.connect_bus(sim.bus)
	sim.bus.quest_choice_posted.emit(1, "other_quest", [])
	assert_eq(_poll(h, sim, 0.0), "")
	sim.bus.quest_choice_posted.emit(1, HintDirector.PATH_QUEST, [])
	assert_eq(_poll(h, sim, 1.0), "path_choice")
	sim.bus.metro_raid_started.emit("r1", 5.0)
	assert_eq(_poll(h, sim, 5.0), "")
	assert_eq(_poll(h, sim, 12.0), "drone_raid")
	sim.bus.metro_raid_started.emit("r2", 5.0)
	assert_eq(_poll(h, sim, 40.0), "")
	h.disconnect_bus()


func test_density() -> void:
	var sim := _sim()
	var c := sim.colonists.spawn(Vector2i(5, 5))
	sim.give_gear(c.id, "helmet", "common", 0)
	var h := _director("Off")
	assert_eq(_poll(h, sim, 0.0), "")
	assert_false(SeenFlags.seen("gear_first"))
	h = _director("New")
	h.connect_bus(sim.bus)
	sim.bus.quest_choice_posted.emit(1, HintDirector.PATH_QUEST, [])
	assert_eq(_poll(h, sim, 0.0), "gear_first")
	assert_eq(_poll(h, sim, 30.0), "")  # path_choice not in New
	h.disconnect_bus()


func test_tutorial_suppresses() -> void:
	var h := _director()
	var sim := make_sim(3, false, 30, 30, peaceful_defs())
	var c := sim.colonists.spawn(Vector2i(5, 5))
	sim.give_gear(c.id, "helmet", "common", 0)
	if TutorialCard.current_step(sim) < 0:
		return  # no tutorial in this scenario: nothing to suppress
	assert_eq(_poll(h, sim, 0.0), "")


func test_poll_does_not_touch_sim() -> void:
	var h := _director()
	var sim := _sim()
	var c := sim.colonists.spawn(Vector2i(5, 5))
	sim.give_gear(c.id, "helmet", "common", 0)
	var before := SaveGame.state_hash(sim)
	_poll(h, sim, 0.0)
	assert_eq(SaveGame.state_hash(sim), before)


func test_seen_flags_persist() -> void:
	_setup_flags()
	assert_false(SeenFlags.seen("x"))
	SeenFlags.mark("x")
	assert_true(SeenFlags.seen("x"))
	SeenFlags._loaded_path = ""  # force reload from file
	assert_true(SeenFlags.seen("x"))
	SeenFlags.reset()
	assert_false(SeenFlags.seen("x"))
