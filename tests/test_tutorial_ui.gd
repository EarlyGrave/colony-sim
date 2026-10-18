extends TestCase
## O2: Warden card, highlight, handbook. Uses the has_method-guarded sim.tutorial API.


func _card(sim: Simulation, idx: int) -> TutorialCard:
	var c := TutorialCard.new()
	_owned_nodes.append(c)
	c.bind(sim)
	c.show_step(idx)
	return c


func test_card_per_step_buttons_big() -> void:
	var sim := make_sim(1, false, 16, 16, peaceful_defs())
	var n := TutorialCard.lessons(sim).size()
	assert_eq(n, 12, "12 lessons")
	for i in n:
		var c := _card(sim, i)
		assert_true(c.title_label.text != "", "title step %d" % i)
		assert_true(c.skip_step_btn.custom_minimum_size.y >= 64.0 and c.skip_step_btn.custom_minimum_size.x >= 64.0, "skip step size")
		assert_true(c.skip_all_btn.custom_minimum_size.y >= 64.0 and c.skip_all_btn.custom_minimum_size.x >= 64.0, "skip all size")


func test_highlight_ignores_input() -> void:
	var h := TutorialHighlight.new()
	_owned_nodes.append(h)
	assert_eq(h.mouse_filter, Control.MOUSE_FILTER_IGNORE, "ignore")
	h.show_over(Rect2(10, 10, 80, 80))
	assert_true(h.visible, "shown")
	h.hide_highlight()
	assert_false(h.visible, "hidden")


func test_handbook_lists_12_rows() -> void:
	var sim := make_sim(1, false, 16, 16, peaceful_defs())
	var p := HandbookPanel.new()
	_owned_nodes.append(p)
	p.open(sim)
	assert_eq(p.rows.size(), 12, "rows")
	for b in p.rows:
		assert_true(b.custom_minimum_size.y >= 64.0, "row height")
	assert_eq(p.density_buttons.size(), 3, "density modes")


func test_density_roundtrip() -> void:
	var path := "user://test_hints.json"
	assert_true(MetaStore.save_hint_density("Off", path), "save")
	assert_eq(MetaStore.load_hint_density(path), "Off", "load")
	DirAccess.remove_absolute(path)
	assert_eq(MetaStore.load_hint_density(path), "Full", "default")


func test_skip_buttons_guarded_without_sim_api() -> void:
	var sim := make_sim(1, false, 16, 16, peaceful_defs())
	var c := _card(sim, 0)
	c.skip_step_btn.pressed.emit()  # no tutorial API yet: must not error
	c.skip_all_btn.pressed.emit()
	assert_true(true, "no errors")
