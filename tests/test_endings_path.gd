extends TestCase
## EN1: sim.path(), per-path point of no return, ending_won.


func _sim() -> Simulation:
	var d := peaceful_defs()
	d.balance["e1_enabled"] = true
	var sim := make_sim(5, false, 24, 24, d)
	sim.colonists.spawn(Vector2i(4, 4))
	sim.buildings.place("warden_terminal", Vector2i(10, 10), false)
	sim.run_ticks(1)
	sim.milestones.done_tiers = [0, 1, 2]
	return sim


func test_no_path_by_default() -> void:
	var sim := _sim()
	assert_eq(sim.path(), "")
	assert_false(sim.endings.is_locked())
	assert_true(sim.endings.petition_allowed())


func test_set_path_and_change_until_locked() -> void:
	var sim := _sim()
	assert_false(sim.set_path("nope"))
	assert_true(sim.set_path("fight"))
	assert_eq(sim.path(), "fight")
	assert_true(sim.set_path("escape"))
	assert_eq(sim.path(), "escape")
	sim.quests.set_flag("ponr_escape")
	assert_true(sim.endings.is_locked())
	assert_false(sim.set_path("fight"), "Q14b refused after PoNR")
	assert_eq(sim.path(), "escape")


func test_petitions_refused_when_non_submit_locked() -> void:
	var sim := _sim()
	sim.set_path("fight")
	assert_true(sim.endings.petition_allowed(), "not locked yet")
	sim.quests.set_flag("ponr_fight")
	assert_false(sim.endings.petition_allowed())
	assert_false(sim.deliver_petition(1))


func test_submit_ponr_is_first_petition() -> void:
	var sim := _sim()
	sim.set_path("submit")
	assert_false(sim.endings.is_locked())
	sim.petition.done_phases.append(1)
	assert_true(sim.endings.is_locked())
	assert_false(sim.set_path("fight"))
	assert_true(sim.endings.petition_allowed())


func test_ending_won_signal_once() -> void:
	var sim := _sim()
	var got: Array = []
	sim.bus.ending_won.connect(func(id: String) -> void: got.append(id))
	assert_false(sim.ending_won("bogus"))
	assert_true(sim.ending_won("fight"))
	assert_false(sim.ending_won("fight"))
	assert_eq(got, ["fight"])
	assert_true(sim.endings.won("fight"))
