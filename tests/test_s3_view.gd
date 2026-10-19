extends TestCase
## S3: shuttle models, view sync without the shuttle API, win screen.


func test_stage_for() -> void:
	assert_eq(ShuttleView3D.stage_for(0, 10), 0)
	assert_eq(ShuttleView3D.stage_for(5, 10), 1)
	assert_eq(ShuttleView3D.stage_for(10, 10), 2)


func test_models_grow_by_stage() -> void:
	var a := ShuttleView3D.build_gantry(0)
	var b := ShuttleView3D.build_gantry(1)
	var c := ShuttleView3D.build_gantry(2)
	assert_true(a.get_child_count() < b.get_child_count() and b.get_child_count() < c.get_child_count(), "stages add parts")
	assert_true(c.get_child_count() <= 40, "part budget")
	var s := ShuttleView3D.build_shuttle()
	var bc := ShuttleView3D.build_beacon()
	assert_true(s.get_child_count() > 0 and bc.get_child_count() > 0)
	for n in [a, b, c, s, bc]:
		n.free()


func test_view_syncs_without_shuttle_api() -> void:
	var sim := make_sim(1)
	var v := ShuttleView3D.new()
	v.bind(sim)
	v.sync(0.1)
	v.clear()
	v.free()


func test_win_screen() -> void:
	var lines := WinScreen.stats_lines({"days": 12, "colonists": 4, "debt_paid": 300, "pollution": 0.37})
	assert_eq(lines[0], "Days survived: 12")
	assert_eq(lines[3], "Pollution: 37%")
	var w := WinScreen.new({"days": 1})
	var btns: Array = w.find_children("*", "Button", true, false)
	assert_eq(btns.size(), 3)  # N2: + Next Sentence
	for b: Button in btns:
		assert_true(b.custom_minimum_size.y >= 64.0)
	w.free()
