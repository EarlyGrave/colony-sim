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
	assert_eq(lines[4], "Pollution: 37%")
	var w := WinScreen.new({"days": 1})
	var btns: Array = w.find_children("*", "Button", true, false)
	assert_eq(btns.size(), 3)  # N2: + Next Sentence
	for b: Button in btns:
		assert_true(b.custom_minimum_size.y >= 64.0)
	w.free()


# region F2
func test_win_screen_epilogue_per_ending() -> void:
	for id: String in ["submit", "fight", "escape", "remission"]:
		var ep := WinScreen.epilogue_lines(id)
		assert_true(ep.size() >= 5, id)
		var w := WinScreen.new({"days": 1, "ending": id})
		assert_true(w.epilogue_title != null, id)
		assert_eq(w.epilogue_title.text, str(ep[0]))
		assert_eq(w.epilogue_box.get_child_count(), ep.size() - 1)
		assert_eq((w.epilogue_box.get_child(0) as Label).text, str(ep[1]))
		assert_eq(w.find_children("*", "Button", true, false).size(), 3)
		w.free()
	var none := WinScreen.new({"days": 1})
	assert_true(none.epilogue_title == null)
	none.free()


func test_win_screen_ending_id_from_sim() -> void:
	var sim := make_sim(5, false, 30, 30)
	assert_eq(WinScreen.ending_id(sim), "")
	assert_eq(WinScreen.stats_from(sim)["ending"], "")
	sim.set_path("fight")
	assert_eq(WinScreen.ending_id(sim), "fight")
	sim.endings.mark_won("fight")
	assert_eq(WinScreen.stats_from(sim)["ending"], "fight")
# endregion
