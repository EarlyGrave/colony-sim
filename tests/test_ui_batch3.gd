extends TestCase
## Batch 3 HUD: forecast bar, crisis banner, contract indicator, payoff popup, ammo policy.


func _host() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.current_scene if tree.current_scene != null else tree.root.get_child(tree.root.get_child_count() - 1)


func _alerts(sim: Simulation) -> AlertCenter:
	var a := AlertCenter.new()
	_owned_nodes.append(a)
	_host().add_child(a)
	a.bind(sim)
	return a


func _game() -> GameController:
	var game := (load("res://view/game.tscn") as PackedScene).instantiate() as GameController
	_owned_nodes.append(game)
	_host().add_child(game)
	return game


func _buttons(n: Node, out: Array[Button]) -> void:
	for ch in n.get_children():
		if ch is Button:
			out.append(ch)
		_buttons(ch, out)


func _crisis_level(sim: Simulation) -> void:
	sim.contamination.level = 0.55 * float(sim.defs.balance["contamination"]["max"])
	sim.run_ticks(3)


func test_forecast_tint_shifts_towards_threshold() -> void:
	var sim := make_sim(5, false)
	var ths := ForecastBar.thresholds(sim)
	assert_eq(ths.size(), 3)
	var far := ForecastBar.tint(0.05, ths)
	var near := ForecastBar.tint(0.48, ths)
	var past := ForecastBar.tint(0.95, ths)
	assert_gt(far.g, far.r, "green far away")
	assert_gt(near.r, far.r, "redder when near")
	assert_gt(past.r, 0.9)
	assert_lt(past.g, 0.4)


func test_crisis_banner_buttons_resolve() -> void:
	var sim := make_sim(3, true, 24, 24, peaceful_defs())
	_crisis_level(sim)
	assert_true(sim.crises.is_pending("siege"))
	var a := _alerts(sim)
	assert_true(a._panel.visible, "banner shown")
	var bs: Array[Button] = []
	_buttons(a._box, bs)
	var opt: Array[Button] = bs.filter(func(b: Button) -> bool: return b.text.begins_with("Hold"))
	assert_eq(opt.size(), 1)
	assert_true(opt[0].custom_minimum_size.y >= 64.0)
	opt[0].pressed.emit()
	assert_false(sim.crises.is_pending("siege"))
	a.refresh()
	assert_false(a._panel.visible, "banner gone")


func test_banner_collapses() -> void:
	var sim := make_sim(3, true, 24, 24, peaceful_defs())
	_crisis_level(sim)
	var a := _alerts(sim)
	var bs: Array[Button] = []
	_buttons(a._box, bs)
	for b in bs:
		if b.text == "Hide":
			b.pressed.emit()
	assert_true(a._strip.visible)
	assert_false(a._panel.visible)


func test_payoff_popup_calls_command() -> void:
	var sim := make_sim(5, true, 24, 24, peaceful_defs())
	sim.run_ticks(1)
	var c: Colonist = sim.colonists.list[0]
	var st := sim.debt.state_of(c)
	st.paid = st.total
	st.pending_choice = true
	var a := _alerts(sim)
	assert_true(a._panel.visible)
	var bs: Array[Button] = []
	_buttons(a._box, bs)
	var stay: Array[Button] = bs.filter(func(b: Button) -> bool: return b.text == "Stay")
	stay[0].pressed.emit()
	assert_eq(st.outcome, "stayed")


func test_hud_builds_with_crisis_and_contract() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var old_size := root.size
	root.size = Vector2i(844, 390)  # headless default viewport is 64x64: the phone layout would hide the chip
	var game := _game()
	var sim := game.sim
	_crisis_level(sim)
	var c := {"id": 99, "template": "t", "name": "Test", "essence": 5, "parts": 0, "offered_day": 0, "expire_day": 9,
		"deadline_day": 5, "deadline_days": 5, "reward": {"kind": "supplies"}, "state": "active"}
	sim.contracts.list.append(c)
	for i in 3:
		game.hud._process(0.3)
	root.size = old_size
	assert_true(game.hud._contract_btn.visible, "contract chip")
	assert_true(game.hud._alerts._panel.visible, "crisis banner")
	assert_true(game.hud._tool_buttons.has("patrol") and game.hud._tool_buttons.has("training_dummy"), "tools")


func test_patrol_tool_sets_route() -> void:
	var game := _game()
	game._on_tool_selected("patrol")
	var mc := game.sim.map_center()
	game._on_tapped(WorldView.cell_to_world(mc) + Vector2(4, 4))
	game._on_tapped(WorldView.cell_to_world(mc + Vector2i(2, 0)) + Vector2(4, 4))
	assert_eq(game.world.patrol_draft.size(), 2)
	game.hud.patrol_done.emit()
	assert_eq(game.sim.idle_work.patrol_route.size(), 2)
	assert_true(game.world.patrol_draft.is_empty())


func test_turret_ammo_toggle_button() -> void:
	var sim := make_sim(5)
	var t: Building = null
	for b in sim.buildings.list:
		if b.def.has("turret"):
			t = b
	if t == null:
		return
	var sec := load("res://view/panels/sections/building_section.gd").new() as InspectorSection
	var box := VBoxContainer.new()
	_owned_nodes.append(box)
	sec.build(sim, {"building": t, "kind": "building", "cell": t.cell, "colonist": null}, box)
	var bs: Array[Button] = []
	_buttons(box, bs)
	assert_eq(bs.size(), 1)
	bs[0].pressed.emit()
	assert_eq(t.ammo_policy, "conserve")
