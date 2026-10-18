extends TestCase
## C5: squad banners (tap / long-press), ground and enemy taps, forecast panel, phone layout.
## Uses SquadStub for the C1/C2 squad API, real HUD / game scene.


func _make_game() -> GameController:
	var game := (load("res://view/game.tscn") as PackedScene).instantiate() as GameController
	_owned_nodes.append(game)
	var tree := Engine.get_main_loop() as SceneTree
	var host: Node = tree.current_scene if tree.current_scene != null else tree.root.get_child(tree.root.get_child_count() - 1)
	host.add_child(game)
	return game


func _with_squads(game: GameController, n := 1) -> SquadStub:
	var stub := SquadStub.new(game.sim.colonists)
	var roles := ["bulwark", "lancer", "medic"]
	var ids: Array = game.sim.colonists.list.map(func(c: Colonist) -> int: return c.id)
	for k in n:
		var m: Array = []
		var ro: Array = []
		for i in 3:
			m.append(ids[(k * 3 + i) % ids.size()])
			ro.append(roles[i])
		stub.form_squad(m, ro)
	stub.calls.clear()
	game.hud.squad_bar.api = stub
	game.hud.squad_bar.refresh()
	return stub


func _sort(n: Node) -> void:
	for ch in n.get_children():
		_sort(ch)
	if n is Container:
		(n as Container).notification(Container.NOTIFICATION_SORT_CHILDREN)


func _settle(game: GameController, size: Vector2i, ui_scale: float) -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	root.content_scale_factor = ui_scale
	root.size = size
	for i in 4:
		game.hud._process(0.3)
		_sort(game.hud)


func _mouse(pressed: bool, pos: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	return ev


func _banner_tap(bar: SquadBar, sid: int) -> void:
	var b: Button = bar.banners[sid]
	bar.banner_input(_mouse(true, Vector2(20, 20)), sid, b)
	bar.banner_input(_mouse(false, Vector2(20, 20)), sid, b)


func test_bar_hidden_without_squad_api() -> void:
	var game := _make_game()
	game.sim.run_ticks(5)
	game.hud._process(0.1)
	assert_false(game.hud.squad_bar.visible, "no squad API -> no bar, layout unchanged")


func test_banner_tap_selects_and_toggles() -> void:
	var game := _make_game()
	_with_squads(game)
	var bar := game.hud.squad_bar
	assert_true(bar.visible)
	assert_eq(bar.banners.size(), 1)
	_banner_tap(bar, 1)
	assert_eq(bar.selected, 1)
	assert_true(bar.disband_btn.visible, "Disband shows for the selected squad")
	_banner_tap(bar, 1)
	assert_eq(bar.selected, -1)


func test_ground_tap_emits_one_squad_hold() -> void:
	var game := _make_game()
	var stub := _with_squads(game)
	_banner_tap(game.hud.squad_bar, 1)
	var cell := game.sim.map_center() + Vector2i(2, 2)
	game._on_tapped(Vector2(cell) * WorldView.TILE + Vector2.ONE * WorldView.TILE * 0.5)
	assert_eq(stub.count("squad_hold"), 1)
	assert_eq(stub.count("squad_focus"), 0)
	assert_eq(stub.calls[0][2], cell)


func test_enemy_tap_emits_one_squad_focus() -> void:
	var game := _make_game()
	var stub := _with_squads(game)
	_banner_tap(game.hud.squad_bar, 1)
	var cell := game.sim.map_center() + Vector2i(4, 0)
	var e := game.sim.threats._spawn("crawler", cell)
	assert_true(e != null)
	var pos := e.visual_pos() * WorldView.TILE + Vector2.ONE * WorldView.TILE * 0.5
	game._on_tapped(pos)
	assert_eq(stub.count("squad_focus"), 1)
	assert_eq(stub.calls[0][2], e.id)
	assert_eq(stub.count("squad_hold"), 0, "an enemy tap is not also a hold")


func test_no_selection_leaves_single_inmate_drafting_alone() -> void:
	var game := _make_game()
	var stub := _with_squads(game)
	var c: Colonist = game.sim.colonists.list[0]
	assert_true(game.sim.set_drafted(c.id, true))
	game.combat_selected = c.id
	var cell := c.cell + Vector2i(2, 0)
	game._on_tapped(Vector2(cell) * WorldView.TILE + Vector2.ONE * WorldView.TILE * 0.5)
	assert_eq(stub.calls.size(), 0, "no banner selected: squad API untouched")
	assert_eq(c.combat.order_cell, cell, "single order_move still works")


func test_long_press_opens_three_big_slots_and_uses_ability() -> void:
	var game := _make_game()
	var stub := _with_squads(game)
	var bar := game.hud.squad_bar
	var b: Button = bar.banners[1]
	bar.banner_input(_mouse(true, Vector2(30, 30)), 1, b)
	for i in 30:
		bar._process(0.02)
	assert_true(bar.radial.is_open, "open after 0.6 s")
	assert_eq(bar.radial.slots.size(), 3)
	assert_true(RadialMenu.SLOT_SIZE >= 64.0)
	assert_eq(game._c5_time_scale(), 0.3, "time slows while the radial is open")
	var ids: Array = bar.radial.slots.map(func(s: Array) -> String: return s[0])
	assert_eq(ids, ["taunt", "volley", "stabilise"])
	# Release over the Volley slot (inside the banner's gui_input the position is banner-local).
	var target := bar.radial.slot_center(1)
	bar.banner_input(_mouse(false, b.get_global_transform_with_canvas().affine_inverse() * target), 1, b)
	assert_eq(stub.count("use_ability"), 1)
	assert_eq(stub.calls[0][2], "volley")
	assert_eq(bar.selected, -1, "a long press does not also select")
	assert_eq(game._c5_time_scale(), 1.0)


func test_short_press_never_opens_radial() -> void:
	var game := _make_game()
	_with_squads(game)
	var bar := game.hud.squad_bar
	var b: Button = bar.banners[1]
	bar.banner_input(_mouse(true, Vector2(30, 30)), 1, b)
	for i in 5:
		bar._process(0.02)
	assert_false(bar.radial.is_open)
	bar.banner_input(_mouse(false, Vector2(30, 30)), 1, b)
	assert_eq(bar.selected, 1)


func test_cooldown_slot_is_not_pickable() -> void:
	var game := _make_game()
	var stub := _with_squads(game)
	stub.squads.cooldowns["1:taunt"] = 120
	var bar := game.hud.squad_bar
	var slots := bar.ability_slots(1)
	assert_false(bool(slots[0][2]), "taunt on cooldown")
	assert_eq(slots[0][3], "12s")
	bar.radial.set_slots(1, slots)
	bar.radial.open_at(Vector2(400, 300))
	bar.radial.press_end(bar.radial.slot_center(0))
	assert_eq(stub.count("use_ability"), 0)


func test_emulated_mouse_in_world_is_ignored() -> void:
	var game := _make_game()
	var stub := _with_squads(game)
	_banner_tap(game.hud.squad_bar, 1)
	var ev := _mouse(true, Vector2(300, 300))
	ev.device = InputEvent.DEVICE_ID_EMULATION
	game.o5_feed(ev)
	assert_false(game.radial.is_pressing(), "emulated press ignored by the world long-press")
	assert_eq(stub.calls.size(), 0)


func test_form_squad_button_uses_free_inmates() -> void:
	var game := _make_game()
	var stub := SquadStub.new(game.sim.colonists)
	game.hud.squad_bar.api = stub
	game.hud.squad_bar.refresh()
	assert_true(game.hud.squad_bar.form_default())
	assert_eq(stub.count("form_squad"), 1)
	var ids: Array = stub.calls[0][1]
	assert_true(ids.size() >= 1 and ids.size() <= 3)
	assert_eq((stub.calls[0][2] as Array).size(), ids.size(), "a role per inmate")


func test_forecast_panel_reads_without_touching_state() -> void:
	var game := _make_game()
	var sim := game.sim
	sim.threats.awakened = true
	sim.threats.next_wave_tick = sim.tick + 120
	sim.threats._schedule_origin()
	var before := SaveGame.state_hash(sim)
	var f := ForecastPanel.forecast(sim)
	assert_true(f["awake"])
	assert_eq(f["eta_ticks"], 120)
	assert_true(f["side"] != "")
	assert_true((f["types"] as Array).size() >= 1)
	assert_true(int(f["count_hi"]) >= 1)
	assert_true(ForecastPanel.describe(f).contains("Wave 1 in"))
	game.hud.toggle_panel("forecast")
	assert_true(game.hud._side is ForecastPanel)
	assert_eq(SaveGame.state_hash(sim), before, "forecast adds no sim state")
	assert_eq(sim.threats.next_wave_tick, sim.tick + 120)


func test_wave_button_opens_forecast_and_is_big() -> void:
	var game := _make_game()
	_with_squads(game)
	var bar := game.hud.squad_bar
	bar.wave_btn.pressed.emit()
	assert_true(game.hud._side is ForecastPanel)
	assert_true(bar.wave_btn.custom_minimum_size.y >= 64.0 and bar.form_btn.custom_minimum_size.y >= 64.0)


func test_phone_layout_no_overlap_with_bar_slot_and_cluster() -> void:
	var game := _make_game()
	_with_squads(game, 2)
	game.sim.run_ticks(30)
	var root := (Engine.get_main_loop() as SceneTree).root
	var old_size := root.size
	var old_scale := root.content_scale_factor
	for s: Array in [[Vector2i(844, 390), 1.0], [Vector2i(2532, 1170), 2.55]]:
		var tag := "%dx%d@%.2f" % [s[0].x, s[0].y, s[1]]
		_settle(game, s[0], s[1])
		var hud := game.hud
		var vp := hud.get_viewport().get_visible_rect().size
		var bar := hud.squad_bar
		assert_true(bar.visible, tag + " bar visible")
		var br := bar.get_global_rect()
		assert_true(br.size.y >= 64.0, tag + " bar height")
		for b in bar.banners.values():
			assert_true((b as Button).size.y >= 63.5 and (b as Button).size.x >= 63.5, tag + " banner >= 64")
		var others: Array = [hud._o4_cluster, hud._o4_slot, hud._colonist_dock, hud._o4_strip]
		for o: Control in others:
			if o.is_visible_in_tree():
				var x := br.intersection(o.get_global_rect())
				assert_false(x.size.x > 1.0 and x.size.y > 1.0, "%s bar overlaps %s %s vs %s" % [tag, o.name, br, o.get_global_rect()])
		for ch in hud._root.get_children():
			if ch is Control and ch != bar and ch.visible and (ch == hud._message or ch == hud._legend):
				var x2 := br.intersection((ch as Control).get_global_rect())
				assert_false(x2.size.x > 1.0 and x2.size.y > 1.0, "%s bar overlaps %s" % [tag, ch.name])
		var map_frac := (vp.y - hud._o4_strip.get_global_rect().end.y) / vp.y
		assert_true(map_frac >= 0.6, "%s map area %.2f >= 0.6" % [tag, map_frac])
		hud.toggle_panel("forecast")
		_settle(game, s[0], s[1])
		var side := hud._side.get_global_rect()
		var x3 := bar.get_global_rect().intersection(side)
		assert_false(x3.size.x > 1.0 and x3.size.y > 1.0, tag + " bar clear of forecast sheet")
		hud.close_side()
	root.size = old_size
	root.content_scale_factor = old_scale
