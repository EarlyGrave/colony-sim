extends TestCase
## C5: alarm militia. Idle inmates outside any squad rally to the nearest banner while the alarm is on.


func _sim_with_inmates(n: int) -> Simulation:
	var sim := make_sim(7, false, 48, 48, peaceful_defs())
	var center := sim.map_center()
	for i in n:
		sim.colonists.spawn(center + Vector2i(-14 + i, 8))
	return sim


func _banner(sim: Simulation, cell: Vector2i, member_ids: Array = []) -> SquadStub:
	var stub := SquadStub.new(sim.colonists)
	var s := SquadStub.Sq.new()
	s.id = 1
	s.name = "Squad 1"
	s.members = member_ids
	s.hold = cell
	stub.squads.list.append(s)
	sim.set_meta("squads_override", stub.squads)
	return stub


func test_idle_inmates_reach_banner_within_120_ticks() -> void:
	var sim := _sim_with_inmates(3)
	var banner := sim.map_center() + Vector2i(0, 0)
	_banner(sim, banner)
	sim.set_alarm(true)
	sim.run_ticks(120)
	for c in sim.colonists.list:
		assert_true(c.combat.drafted, "%s drafted" % c.display_name)
		var d := Vector2(c.cell).distance_to(Vector2(banner))
		assert_true(d <= 10.0, "%s within 10 cells (%.1f)" % [c.display_name, d])
	assert_eq(sim.militia.members.size(), 3)


func test_released_when_alarm_off() -> void:
	var sim := _sim_with_inmates(3)
	_banner(sim, sim.map_center())
	sim.set_alarm(true)
	sim.run_ticks(40)
	assert_true(sim.militia.active())
	sim.set_alarm(false)
	sim.run_ticks(12)
	assert_false(sim.militia.active())
	for c in sim.colonists.list:
		assert_false(c.combat.drafted, "none drafted after alarm off")


func test_squad_members_and_hurt_inmates_are_not_militia() -> void:
	var sim := _sim_with_inmates(3)
	var a: Colonist = sim.colonists.list[0]
	var b: Colonist = sim.colonists.list[1]
	b.hp = b.max_hp * 0.3
	_banner(sim, sim.map_center(), [a.id])
	sim.set_alarm(true)
	sim.run_ticks(30)
	assert_false(a.combat.drafted, "squad members are C1's business")
	assert_false(b.combat.drafted, "hurt inmate stays out")
	assert_true(sim.colonists.list[2].combat.drafted)


func test_flees_at_low_hp_and_stays_out() -> void:
	var sim := _sim_with_inmates(1)
	_banner(sim, sim.map_center())
	sim.set_alarm(true)
	sim.run_ticks(30)
	var c: Colonist = sim.colonists.list[0]
	assert_true(c.combat.drafted)
	c.hp = c.max_hp * 0.2
	sim.run_ticks(15)
	assert_false(c.combat.drafted, "fled at flee_hp_fraction")
	sim.run_ticks(40)
	assert_false(c.combat.drafted, "not re-drafted during the same alarm")


func test_no_squads_no_militia_and_rule_off() -> void:
	var sim := _sim_with_inmates(2)
	sim.set_alarm(true)
	sim.run_ticks(30)
	assert_false(sim.militia.active(), "no banner, no militia")
	_banner(sim, sim.map_center())
	sim.set_rule("militia_rally", false)
	sim.run_ticks(30)
	assert_false(sim.militia.active(), "rule off")
	sim.set_rule("militia_rally", true)
	sim.run_ticks(30)
	assert_true(sim.militia.active())


func test_deterministic() -> void:
	var cells: Array = []
	for run in 2:
		var sim := _sim_with_inmates(3)
		_banner(sim, sim.map_center())
		sim.set_alarm(true)
		sim.run_ticks(100)
		var snap: Array = []
		for c in sim.colonists.list:
			snap.append([c.cell, c.combat.drafted])
		cells.append(snap)
	assert_eq(cells[0], cells[1])
