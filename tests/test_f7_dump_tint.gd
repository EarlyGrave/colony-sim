extends TestCase
## F7 W1: dump-zone tint cells, peak marker source, legend entries and forecast suffix (view only).


func _host() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.current_scene if tree.current_scene != null else tree.root.get_child(tree.root.get_child_count() - 1)


func _wv(sim: Simulation) -> WorldView:
	var wv := WorldView.new()
	_host().add_child(wv)
	_owned_nodes.append(wv)
	wv.flat = true
	wv.bind(sim)
	return wv


func test_tint_cells_match_zone_and_peak_matches_threats() -> void:
	var sim := make_sim(4, false, 24, 24, peaceful_defs())
	for y in range(5, 7):
		for x in range(5, 8):
			sim.set_zone(Vector2i(x, y), "waste_dump")
	var wv := _wv(sim)
	var want: Dictionary = sim.items.zone_cells["waste_dump"]
	var got := wv.f7w1_dump_cells()
	assert_eq(got.size(), want.size())
	for c in got:
		assert_true(want.has(c), "tint cell is a zone cell")
	assert_eq(wv.f7w1_dump_peak(), sim.threats.f4d_pollution_peak())
	assert_true(wv.f7w1_dump_peak().x >= 5, "peak inside dump")
	wv.show_field = false
	wv.unbind()


func test_empty_map_draws_nothing_and_does_not_error() -> void:
	var sim := make_sim(5, false, 24, 24, peaceful_defs())
	var wv := _wv(sim)
	assert_eq(wv.f7w1_dump_cells().size(), 0)
	assert_eq(wv.f7w1_dump_peak(), Vector2i(-1, -1))
	wv._f7w1_draw_dump(wv, Rect2i(0, 0, 24, 24))
	wv.unbind()


func test_legend_has_three_entries_and_suffix_follows_flag() -> void:
	assert_eq(Hud.F7W1_LEGEND_DUMP[1], "dump")
	var sim := make_sim(6, false, 24, 24, peaceful_defs())
	assert_eq(Hud.f7w1_forecast_suffix(sim), "")
	sim.threats.cfg["spawn_at_pollution_peak"] = true
	assert_eq(Hud.f7w1_forecast_suffix(sim), " · first wave: dump side")
