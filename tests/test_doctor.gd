extends TestCase
## Doctoring: rescue to bed, tending, feeding patients.


func _colony(doctoring: bool, seed_value := 41) -> Simulation:
	var sim := make_sim(seed_value, true, 24, 24, peaceful_defs())
	var scen := preload("res://tests/scenario.gd")
	scen.standard_colony(sim, 2)
	var food_at := sim.map_center() + Vector2i(3, -1)
	for y in 3:
		for x in 3:
			sim.set_zone(food_at + Vector2i(x - 1, y - 1), "stockpile")
	if not doctoring:
		for c in sim.colonists.list:
			sim.set_work_priority(c.id, "doctoring", 0)
	return sim


func _wound(sim: Simulation) -> Colonist:
	var c: Colonist = sim.colonists.list[0]
	sim.health.apply_damage(c, 70.0, "legs", "bullet")
	sim.health.apply_damage(c, 30.0, "torso", "cut")
	return c


func _conserved(sim: Simulation) -> void:
	for id in ["raw_food", "meal"]:
		assert_eq(sim.items.count_world(id) + _carried(sim, id), sim.ledger.balance_of(id), "%s conserved" % id)


func _carried(sim: Simulation, id: String) -> int:
	var n := 0
	for c in sim.colonists.list:
		if c.carry_item == id:
			n += c.carry_count
	return n


func test_rescued_tended_survives_untended_dies() -> void:
	var off := _colony(false)
	var p_off := _wound(off)
	off.run_ticks(1500)
	assert_false(p_off.alive, "untended dies")
	var on := _colony(true)
	var p := _wound(on)
	assert_true(p.health.downed)
	var bed_seen := false
	for t in 1500:
		on.step()
		if p.health.bed_id >= 0:
			bed_seen = true
	assert_true(p.alive, "doctored survives")
	assert_true(bed_seen, "rescued to a bed")
	assert_eq(p.health.bleed_rate(), 0.0, "bleeding stopped")
	_conserved(on)


func test_patient_is_fed() -> void:
	var sim := _colony(true)
	var p := _wound(sim)
	var fed := [0]
	sim.bus.patient_fed.connect(func(_a: int, _b: int) -> void: fed[0] += 1)
	sim.needs.state_of(p).food = 0.05
	sim.run_ticks(600)
	assert_gt(fed[0], 0, "patient fed")
	assert_gt(sim.needs.state_of(p).food, 0.05)
	_conserved(sim)


func test_bed_heals_faster() -> void:
	var a := _colony(true)
	var pa := _wound(a)
	a.run_ticks(300)
	var b := _colony(true)
	var pb := _wound(b)
	pb.health.bed_id = -1
	b.run_ticks(300)
	assert_true(pa.alive and pb.alive)
	assert_gt(a.health.cfg["doctor"]["bed_heal_mult"], 1.0)


func test_deterministic() -> void:
	var sig: Array = []
	for k in 2:
		var s := _colony(true)
		var p := _wound(s)
		s.run_ticks(800)
		sig.append([p.health.blood, p.cell, p.health.bed_id, s.tick])
	assert_eq(sig[0], sig[1])
