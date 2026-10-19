extends TestCase
## District lockdown (raid alarm is local) + mine_hut shelter.


func _sim() -> Simulation:
	var sim := make_sim(5, false, 80, 40)
	sim.buildings.place("hq", Vector2i(5, 5), false)
	return sim


func test_far_inmate_keeps_working() -> void:
	var sim := _sim()
	var far := sim.colonists.spawn(Vector2i(70, 30))
	var near := sim.colonists.spawn(Vector2i(8, 8))
	sim.threats.set_meta("lockdown_origin", Vector2i(5, 5))
	sim._alarm_raid(true)
	assert_true(sim.threats.in_lockdown(near.cell), "near hides")
	assert_false(sim.threats.in_lockdown(far.cell), "40+ cells away keeps working")


func test_manual_alarm_hides_all() -> void:
	var sim := _sim()
	var far := sim.colonists.spawn(Vector2i(70, 30))
	sim.threats.set_meta("lockdown_origin", Vector2i(5, 5))
	sim.set_alarm(true)
	assert_true(sim.threats.in_lockdown(far.cell), "manual = everyone")
	sim.set_alarm(false)
	assert_false(sim.threats.in_lockdown(far.cell))


func test_radius_zero_is_global() -> void:
	var d := Defs.get_default().duplicate_defs()
	d.threat["lockdown_radius"] = 0
	var sim := make_sim(5, false, 80, 40, d)
	sim.buildings.place("hq", Vector2i(5, 5), false)
	sim.threats.set_meta("lockdown_origin", Vector2i(5, 5))
	sim._alarm_raid(true)
	assert_true(sim.threats.in_lockdown(Vector2i(70, 30)))


func test_mine_hut_is_nearest_shelter() -> void:
	var sim := _sim()
	sim.buildings.place("mine_hut", Vector2i(60, 30), false)
	var sh := sim.buildings.find_shelter(Vector2i(62, 30))
	assert_true(sh != null and sh.def_id == "mine_hut", "hut chosen")
	assert_true(Vector2(sh.cell).distance_to(Vector2(62, 30)) <= 3.0, "flee path <= 3")
