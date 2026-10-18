extends TestCase
## O3 difficulty presets: opts mapping, raid ladder, waste scaling, dialog.


func _sim_with(id: String, seed_value := 2) -> Simulation:
	var defs := Defs.get_default()
	var opts := StartOpts.preset_opts(defs, id)
	var sim := Simulation.new(seed_value, make_bus(), null, opts)
	sim.start_new_game()
	_sims.append(sim)
	return sim


func test_standard_is_empty_opts() -> void:
	assert_true(StartOpts.preset_opts(Defs.get_default(), "standard_term").is_empty())


func test_raid_points_ladder() -> void:
	var s := _sim_with("short_stay").threats.raid_points(3)
	var m := _sim_with("standard_term").threats.raid_points(3)
	var h := _sim_with("hard_time").threats.raid_points(3)
	assert_gt(m, s * 1.15, "standard >= 15% over short")
	assert_gt(h, m * 1.15, "hard >= 15% over standard")


func _contam_after_batch(id: String) -> float:
	var sim := _sim_with(id, 7)
	sim.items.drop(sim.map_center() + Vector2i(5, 5), "waste", 20)
	var before := sim.contamination.level
	for i in 20:
		sim.contamination.tick()
	return sim.contamination.level - before


func test_waste_mult_scales_contamination() -> void:
	var base := _contam_after_batch("standard_term")
	assert_gt(base, 0.0)
	var d: Dictionary = Defs.get_default().presets["presets"]
	for id in ["short_stay", "hard_time"]:
		assert_near(_contam_after_batch(id) / base, float(d[id]["waste_mult"]), 0.01, id)


func test_debt_and_crate_applied() -> void:
	var std := _sim_with("standard_term")
	var hard := _sim_with("hard_time")
	std.step()
	hard.step()
	var a: int = std.debt.state_of(std.colonists.list[0]).total
	var b: int = hard.debt.state_of(hard.colonists.list[0]).total
	assert_gt(float(b), float(a) * 1.2)


func test_dialog_cards_set_preset_once() -> void:
	var meta := MetaState.new()
	var saves: Array = []
	var dlg := NewGameDialog.new(meta, func(m: MetaState) -> void: saves.append(m.preset))
	var got: Array = []
	dlg.start_requested.connect(func(o: Dictionary) -> void: got.append(o))
	for id: String in ["short_stay", "hard_time", "standard_term"]:
		assert_gte_size(dlg.cards[id].custom_minimum_size.y)
		dlg.cards[id].pressed.emit()
		assert_eq(meta.preset, id)
	assert_eq(saves, ["short_stay", "hard_time", "standard_term"])
	assert_eq(dlg.select_count, 3)
	dlg.cards["standard_term"].pressed.emit()  # same card again: no change
	assert_eq(dlg.select_count, 3)
	dlg.cards["hard_time"].pressed.emit()
	dlg.start_button.pressed.emit()
	assert_eq(got.size(), 1)
	assert_eq(got[0]["wave_mult"], 1.3)
	dlg.free()


func assert_gte_size(h: float) -> void:
	assert_true(h >= 64.0, "button >= 64 px")


func test_meta_preset_roundtrip() -> void:
	var m := MetaState.new()
	m.preset = "hard_time"
	var n := MetaState.new()
	n.load_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	assert_eq(n.preset, "hard_time")
	assert_eq(n.make_opts()["debt_mult"], 1.3)
