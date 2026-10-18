extends TestCase
## C3: telegraphed wind-up before enemy attacks.


func _wound(sim: Simulation, cell: Vector2i, stay: bool) -> Array:
	var c := sim.colonists.spawn(cell)
	var e := sim.threats._spawn("burrower", cell + Vector2i(1, 0))
	var seen := false
	for i in 80:
		sim.run_ticks(1)
		if not sim.threats.telegraphs().is_empty():
			seen = true
			break
	if not stay:
		c.cell = Vector2i(2, 2)
	sim.run_ticks(30)
	return [seen, sim.health.state_of(c).injuries.size(), e]


func test_hit_lands_if_target_stays() -> void:
	var sim := make_sim(3, false, 30, 30, peaceful_defs())
	var r := _wound(sim, Vector2i(10, 10), true)
	assert_true(r[0], "wind-up visible before the hit")
	assert_gt(r[1], 0, "hit lands on the marked cell")


func test_hit_misses_if_target_left() -> void:
	var sim := make_sim(3, false, 30, 30, peaceful_defs())
	var r := _wound(sim, Vector2i(10, 10), false)
	assert_true(r[0])
	assert_eq(r[1], 0, "unit left the marked cell")


func test_view_marks_cells() -> void:
	var sim := make_sim(3, false, 30, 30, peaceful_defs())
	var fx := Effects3D.new()
	_owned_nodes.append(fx)
	fx.bind(sim)
	sim.colonists.spawn(Vector2i(10, 10))
	sim.threats._spawn("brute", Vector2i(11, 10))
	for i in 80:
		sim.run_ticks(1)
		fx.tick(0.05)
		if fx.c3_visible_cells() > 0:
			break
	assert_eq(fx.c3_visible_cells(), 9, "brute marks a 3x3 area")


func test_windup_is_deterministic() -> void:
	var a := make_sim(3, false, 30, 30, peaceful_defs())
	var b := make_sim(3, false, 30, 30, peaceful_defs())
	_wound(a, Vector2i(10, 10), true)
	_wound(b, Vector2i(10, 10), true)
	assert_eq(a.threats.telegraphs(), b.threats.telegraphs())
