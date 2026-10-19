extends TestCase
## Y5: Belt entry in the Build popup, game-over ModalStyle card, scrim behind side sheets.


func _make_game() -> GameController:
	var game := (load("res://view/game.tscn") as PackedScene).instantiate() as GameController
	_owned_nodes.append(game)
	var tree := Engine.get_main_loop() as SceneTree
	var host: Node = tree.current_scene if tree.current_scene != null else tree.root.get_child(tree.root.get_child_count() - 1)
	host.add_child(game)
	return game


func test_belt_entry_in_build_popup() -> void:
	var game := _make_game()
	game.sim.run_ticks(10)
	var hud := game.hud
	hud._toggle_cat("build")
	var b: Button = hud._y5_belt_btn
	assert_eq(b.get_parent(), hud._cat_popup_row)
	assert_true(b.custom_minimum_size.y >= 64.0)
	b.pressed.emit()
	assert_eq(game.tool, "belt")
	assert_true(hud.u1_strip_wanted())
	assert_eq(hud._open_cat, "")


func test_game_over_uses_modal_style() -> void:
	var game := _make_game()
	var hud := game.hud
	hud.show_game_over("colonists_dead")
	var sb := hud._game_over.get_theme_stylebox("panel") as StyleBoxFlat
	assert_true(sb.bg_color.a >= 0.95)
	assert_true(hud._y5_go_scrim.visible)
	assert_eq(hud._y5_go_scrim.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(hud._game_over.get_parent(), hud.modal_root)
	var btn := hud._game_over.get_child(0).get_child(1) as Button
	assert_true(btn.custom_minimum_size.y >= 64.0)


func test_sheet_scrim_closes_sheet() -> void:
	var game := _make_game()
	var hud := game.hud
	assert_true(not hud._y5_scrim.visible)
	hud._open_side(PanelRegistry.make_panel("reviews"), "reviews")
	assert_true(hud._y5_scrim.visible)
	assert_eq(hud._y5_scrim.get_parent(), hud.modal_root)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	hud._y5_scrim.gui_input.emit(ev)
	assert_eq(hud._side_id, "")
	assert_true(not hud._y5_scrim.visible)
