extends TestCase
## F10W3: "NEW" badges on the gear / petition / orders buttons and the More button.

const SCRATCH := "user://test_f10_badges_seen.json"
var _old_path := ""


func before_each() -> void:
	_old_path = SeenFlags.path
	SeenFlags.path = SCRATCH
	SeenFlags.reset()
	MetaStore.save_hint_density("Full")


func after_each() -> void:
	SeenFlags.reset()
	SeenFlags.path = _old_path
	MetaStore.save_hint_density("Full")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))


func _make_game() -> GameController:
	var game := (load("res://view/game.tscn") as PackedScene).instantiate() as GameController
	_owned_nodes.append(game)
	var tree := Engine.get_main_loop() as SceneTree
	var host: Node = tree.current_scene if tree.current_scene != null else tree.root.get_child(tree.root.get_child_count() - 1)
	host.add_child(game)
	game.sim.run_ticks(30)
	return game


func _refresh(game: GameController) -> void:
	game.hud._process(0.3)
	game.hud._s4_update()
	game.hud._e4_update()
	game.hud._f10_badges(true)


func _gear(game: GameController) -> void:
	var c: Colonist = game.sim.colonists.list[0]
	game.sim.give_gear(c.id, "helmet", "rare", 3)


func test_gear_badge_predicate_and_more_mirror() -> void:
	var game := _make_game()
	var gb: Button = game.hud._panel_buttons["gear_screen"]
	# Predicate off: no gear instances at all (colonists start with a shiv, so clear the state).
	game.sim.equipment.instances.clear()
	_refresh(game)
	assert_false(NewBadge.is_on(gb), "no badge without any gear")
	assert_false(NewBadge.is_on(game.hud._menu_btn), "More clean")
	_gear(game)
	_refresh(game)
	assert_true(NewBadge.is_on(gb), "badge once gear exists")
	assert_true(NewBadge.is_on(game.hud._menu_btn), "More mirrors its entry")
	game.hud.toggle_panel("gear_screen")
	assert_false(NewBadge.is_on(gb), "cleared on open")
	assert_false(NewBadge.is_on(game.hud._menu_btn), "More cleared too")
	assert_true(SeenFlags.seen("badge.gear_screen"))


func test_cleared_badge_persists_across_reload() -> void:
	var game := _make_game()
	_gear(game)
	_refresh(game)
	game.hud.toggle_panel("gear_screen")
	game.hud.close_side()
	var game2 := _make_game()
	_gear(game2)
	_refresh(game2)
	assert_false(NewBadge.is_on(game2.hud._panel_buttons["gear_screen"]), "never returns after reload")


func test_density_off_hides_badges() -> void:
	MetaStore.save_hint_density("Off")
	var game := _make_game()
	_gear(game)
	_refresh(game)
	assert_false(NewBadge.is_on(game.hud._panel_buttons["gear_screen"]), "Off: no badge")
	assert_false(NewBadge.is_on(game.hud._menu_btn), "Off: no More badge")


func test_orders_badge_only_with_flag() -> void:
	var game := _make_game()
	var ob: Button = game.hud._panel_buttons["orders"]
	_refresh(game)
	assert_false(NewBadge.is_on(ob), "flag OFF never badges")
	assert_false(ob.visible)
	var old: Variant = game.sim.defs.balance.get("reg_enabled", false)
	game.sim.defs.balance["reg_enabled"] = true
	_refresh(game)
	if ob.visible:
		assert_true(NewBadge.is_on(ob), "flag ON badges Orders")
	game.sim.defs.balance["reg_enabled"] = old


func test_badge_is_small_overlay() -> void:
	var game := _make_game()
	var gb: Button = game.hud._panel_buttons["gear_screen"]
	_gear(game)
	_refresh(game)
	var bd := gb.get_node("NewBadge") as Control
	assert_true(bd.size.x <= 28.0 and bd.size.y <= 28.0, "badge <= 28 px")
	assert_eq(bd.mouse_filter, Control.MOUSE_FILTER_IGNORE)
