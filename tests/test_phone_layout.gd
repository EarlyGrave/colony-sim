extends TestCase
## O4: phone layout. Rect-overlap scan over every visible HUD Control at phone and desktop sizes,
## in the idle state and with each popup / sheet open.

const SIZES: Array = [
	[Vector2i(844, 390), 1.0],  # phone landscape, logical px
	[Vector2i(2532, 1170), 2.55],  # same phone at DPR scale -> 993x459 logical
	[Vector2i(1280, 720), 1.0],  # desktop
]


func _make_game() -> GameController:
	var game := (load("res://view/game.tscn") as PackedScene).instantiate() as GameController
	_owned_nodes.append(game)
	var tree := Engine.get_main_loop() as SceneTree
	var host: Node = tree.current_scene if tree.current_scene != null else tree.root.get_child(tree.root.get_child_count() - 1)
	host.add_child(game)
	return game


## Headless has no idle frames between calls: run the HUD layout and the container sort by hand.
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
		_sort(game.auto_panel.get_parent())


## Closes the open sheet and frees it at once (queue_free would keep it in the tree without frames).
func _drop_sheets(game: GameController) -> void:
	game.hud.close_side()
	for ch in game.hud._root.get_children():
		if ch is GamePanel and ch != game.hud._inspector:
			game.hud._root.remove_child(ch)
			ch.free()


func _is_unit(n: Node) -> bool:
	if not (n is Control) or not (n as Control).is_visible_in_tree():
		return false
	if n is Button or n is ColonistBar or n is GamePanel or n is ForecastBar:
		return true
	if n is Label:
		return (n as Label).text != ""
	if n is PanelContainer:
		return not ((n as Control).get_theme_stylebox("panel") is StyleBoxEmpty)
	return false


func _opaque(n: Node) -> bool:
	return n is Button or n is ColonistBar or n is GamePanel


func _clipped(c: Control) -> Rect2:
	var r := c.get_global_rect()
	var p := c.get_parent()
	while p != null:
		if p is ScrollContainer:
			r = r.intersection((p as Control).get_global_rect())
		p = p.get_parent()
	return r


func _collect(n: Node, out: Array) -> void:
	if n is Control and not (n as Control).visible:
		return
	if _is_unit(n):
		var r := _clipped(n as Control)
		if r.size.x > 1.0 and r.size.y > 1.0:
			out.append([n, r])
	if _opaque(n):
		return
	for ch in n.get_children():
		_collect(ch, out)


## Names of intersecting unit pairs (ancestor / descendant pairs are not overlaps).
func _overlaps(game: GameController) -> Array[String]:
	var units: Array = []
	_collect(game.hud._root, units)
	_collect(game.auto_panel.get_parent(), units)
	var cb: Variant = game.get("_continue_btn")
	if cb is Button and (cb as Button).is_visible_in_tree():
		units.append([cb, (cb as Button).get_global_rect()])
	var bad: Array[String] = []
	for i in units.size():
		for j in range(i + 1, units.size()):
			var a: Node = units[i][0]
			var b: Node = units[j][0]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a):
				continue
			var ra: Rect2 = units[i][1]
			var rb: Rect2 = units[j][1]
			var x := ra.intersection(rb)
			if x.size.x > 1.0 and x.size.y > 1.0:
				bad.append("%s %s vs %s %s" % [_name(a), ra, _name(b), rb])
	return bad


func _name(n: Node) -> String:
	if n is Button:
		return "Button(%s)" % (n as Button).text.replace("\n", " ")
	if n is Label:
		return "Label(%s)" % (n as Label).text.left(20)
	return n.get_class() + ":" + str(n.name)


func _small_buttons(game: GameController) -> Array[String]:
	var units: Array = []
	_collect(game.hud._root, units)
	_collect(game.auto_panel.get_parent(), units)
	var bad: Array[String] = []
	for u in units:
		var n: Node = u[0]
		if not (n is Button):
			continue
		var inside_panel := false
		var p := n.get_parent()
		while p != null:
			if p is GamePanel:
				inside_panel = true
			p = p.get_parent()
		var sz := (n as Control).size  # unclipped: scroll-cropped buttons are still 64 px targets
		if not inside_panel and (sz.x < 63.5 or sz.y < 63.5):
			bad.append("%s %s" % [_name(n), sz])
	return bad


func _check_state(game: GameController, label: String) -> void:
	var bad := _overlaps(game)
	assert_eq(bad.size(), 0, "%s overlaps: %s" % [label, "; ".join(bad)])
	var small := _small_buttons(game)
	assert_eq(small.size(), 0, "%s small buttons: %s" % [label, "; ".join(small)])


func _each_size(fn: Callable) -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var old_size := root.size
	var old_scale := root.content_scale_factor
	for s: Array in SIZES:
		fn.call(s[0], s[1])
	root.size = old_size
	root.content_scale_factor = old_scale


func test_idle_and_popups_do_not_overlap() -> void:
	var game := _make_game()
	game.sim.run_ticks(60)
	_each_size(func(size: Vector2i, sc: float) -> void:
		var tag := "%dx%d@%.2f" % [size.x, size.y, sc]
		_settle(game, size, sc)
		_check_state(game, tag + " idle")
		for cat in ["zones", "build", "orders"]:
			game.hud._toggle_cat(cat)
			_settle(game, size, sc)
			_check_state(game, "%s cat %s" % [tag, cat])
			game.hud._toggle_cat(cat)
		game.hud._menu_popup.visible = true
		_settle(game, size, sc)
		_check_state(game, tag + " more menu")
		game.hud._menu_popup.visible = false
		game.auto_panel._machine_row.visible = true  # R5X: expanded Machines row vs the map chips
		_settle(game, size, sc)
		_check_state(game, tag + " machines row")
		game.auto_panel._machine_row.visible = false)


func test_side_sheets_clear_of_column_and_toolbars() -> void:
	var game := _make_game()
	game.sim.run_ticks(60)
	_each_size(func(size: Vector2i, sc: float) -> void:
		var tag := "%dx%d@%.2f" % [size.x, size.y, sc]
		for pid in ["letters", "research", "work", "perks", "save"]:
			game.hud.toggle_panel(pid)
			_settle(game, size, sc)
			var vp := game.hud.get_viewport().get_visible_rect().size
			var r := game.hud._side.get_global_rect()
			assert_true(r.position.x >= 80.0, "%s %s sheet left %.1f >= 80" % [tag, pid, r.position.x])
			assert_true(r.size.x <= vp.x * 0.45 + 16.0, "%s %s sheet width %.1f" % [tag, pid, r.size.x])
			_check_state(game, "%s sheet %s" % [tag, pid])
			_drop_sheets(game)
		game.hud.open_expedition("expedition")
		_settle(game, size, sc)
		_check_state(game, tag + " expedition sheet")
		_drop_sheets(game))


# region F5
func test_radial_ring_clear_of_belt_strip() -> void:
	var game := _make_game()
	game.sim.run_ticks(60)
	_each_size(func(size: Vector2i, sc: float) -> void:
		var tag := "%dx%d@%.2f" % [size.x, size.y, sc]
		game.tool = "wall"  # region U1: the strip is a context drawer, shown while a build tool is active
		_settle(game, size, sc)
		var vp := game.hud.get_viewport().get_visible_rect().size
		var strip := game.auto_panel.get_global_rect()
		assert_true(game.auto_panel.visible and strip.size.x > 0.0, tag + " strip shown")
		assert_true(strip.end.y <= vp.y - 4.0 and strip.end.y >= vp.y - 16.0, "%s strip docked: bottom gap %.1f" % [tag, vp.y - strip.end.y])
		var presses: Array[Vector2] = [strip.get_center(), strip.position, strip.end, Vector2(1, 1), vp - Vector2(1, 1), Vector2(1, vp.y - 1), Vector2(vp.x - 1, 1), vp * 0.5]
		for pos in presses:
			game.radial.open_at(pos)
			assert_false(game.radial.ring_hits(game.radial.center, [strip]), "%s ring vs strip, press %s" % [tag, pos])
			for i in RadialMenu.SLOTS.size():
				var p: Vector2 = game.radial.slot_center(i)
				assert_true(p.x >= 35.0 and p.y >= 35.0 and p.x <= vp.x - 35.0 and p.y <= vp.y - 35.0, "%s slot inside viewport" % tag)
			game.radial.close())
# endregion


func test_column_strip_and_map_budget() -> void:
	var game := _make_game()
	game.sim.run_ticks(60)
	_each_size(func(size: Vector2i, sc: float) -> void:
		var tag := "%dx%d@%.2f" % [size.x, size.y, sc]
		_settle(game, size, sc)
		var hud := game.hud
		var vp := hud.get_viewport().get_visible_rect().size
		var col := hud._colonist_bar.get_global_rect()
		assert_true(col.end.x <= 72.5, "%s column right edge %.1f" % [tag, col.end.x])
		assert_true(col.size.y > 0.0)
		var strip_bottom := hud._o4_strip.get_global_rect().end.y
		assert_true(vp.y - strip_bottom >= vp.y * 0.64, "%s map share %.2f" % [tag, (vp.y - strip_bottom) / vp.y])
		for l: Label in [hud._clock, hud._stats, hud._forecast, hud._threat]:
			assert_true(l.visible and l.text != "", "%s status label shown" % tag)
			assert_eq(l.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING)
			var w := l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x
			assert_true(w <= l.size.x + 1.0, "%s label '%s' fits (%.0f of %.0f)" % [tag, l.text, w, l.size.x])
		var slot := hud.tutorial_slot()
		assert_true(slot != null and slot.get_global_rect().position.y >= strip_bottom, tag + " tutorial slot below the strip")
		assert_true(slot.visible and slot.size.x >= 200.0, tag + " tutorial slot usable"))


# region L2
func test_logic_row_and_splitter_sheet_do_not_overlap() -> void:
	var game := _make_game()
	game.sim.run_ticks(60)
	_each_size(func(size: Vector2i, sc: float) -> void:
		var tag := "%dx%d@%.2f" % [size.x, size.y, sc]
		game.auto_panel._logic_btn.button_pressed = true
		_settle(game, size, sc)
		_check_state(game, tag + " logic row")
		game.auto_panel._logic_btn.button_pressed = false
		var c := Vector2i(5, 5)
		game.splitter_panel.open(game.sim, c, 8.0)
		_settle(game, size, sc)
		_check_state(game, tag + " node sheet")
		game.splitter_panel._open_picker(1)
		_settle(game, size, sc)
		_check_state(game, tag + " item picker")
		game.splitter_panel.close())
# endregion


# region U1
func _u1_covers(c: Control) -> bool:
	if c is Button or c is ColonistBar or c is GamePanel or c is ForecastBar:
		return true
	if c is PanelContainer:
		var sb := c.get_theme_stylebox("panel")
		if sb is StyleBoxEmpty:
			return false
		if c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			return true
		return sb is StyleBoxFlat and (sb as StyleBoxFlat).bg_color.a >= 0.5
	return false


func _u1_rects(n: Node, out: Array[Rect2]) -> void:
	if n is Control and not (n as Control).visible:
		return
	if n is Control and _u1_covers(n as Control):
		var r := _clipped(n as Control)
		if r.size.x > 1.0 and r.size.y > 1.0:
			out.append(r)
	for ch in n.get_children():
		_u1_rects(ch, out)


func test_world_visible_percent() -> void:
	var game := _make_game()
	game.sim.run_ticks(60)
	var size := Vector2i(844, 390)
	_settle(game, size, 1.0)
	game.hud._u1_legend_t = -100.0  # steady state: the legend has faded
	_settle(game, size, 1.0)
	var rects: Array[Rect2] = []
	_u1_rects(game.hud._root, rects)
	_u1_rects(game.auto_panel.get_parent(), rects)
	var cb: Variant = game.get("_continue_btn")
	if cb is Button and (cb as Button).is_visible_in_tree():
		rects.append((cb as Button).get_global_rect())
	var covered := 0
	for y in size.y:
		for x in size.x:
			var p := Vector2(x + 0.5, y + 0.5)
			for r in rects:
				if r.has_point(p):
					covered += 1
					break
	var pct := 100.0 * (1.0 - float(covered) / float(size.x * size.y))
	print("U1 world visible: %.1f%%" % pct)
	assert_true(pct >= 55.0, "world visible %.1f%% >= 55" % pct)
	assert_false(game.auto_panel.visible, "belt strip hidden while idle")
	assert_true(game.hud.notification_anchor != null and game.hud.modal_root != null, "U1 hooks exist")
# endregion


# region EV
func test_ending_sheet_fits() -> void:
	var game := _make_game()
	game.sim.run_ticks(60)
	game.sim.set_path("escape")
	_each_size(func(size: Vector2i, sc: float) -> void:
		var tag := "%dx%d@%.2f" % [size.x, size.y, sc]
		game.hud.toggle_panel("ending")
		_settle(game, size, sc)
		var vp := game.hud.get_viewport().get_visible_rect().size
		var r := game.hud._side.get_global_rect()
		assert_true(r.position.x >= 80.0 and r.size.x <= vp.x * 0.45 + 16.0, "%s ending sheet %s" % [tag, r])
		_check_state(game, tag + " ending sheet")
		_drop_sheets(game))
# endregion


# region F8
func test_gear_screen_fits() -> void:
	var game := _make_game()
	game.sim.run_ticks(60)
	var c: Colonist = game.sim.colonists.list[0]
	game.sim.equip(c.id, game.sim.give_gear(c.id, "helmet", "epic", 5))
	for i in 7:
		game.sim.give_gear(c.id, "kevlar_vest", "rare", i)
	GearScreen.focus_cid = c.id
	_each_size(func(size: Vector2i, sc: float) -> void:
		var tag := "%dx%d@%.2f" % [size.x, size.y, sc]
		game.hud.toggle_panel("gear_screen")
		_settle(game, size, sc)
		var vp := game.hud.get_viewport().get_visible_rect().size
		var sheet := game.hud._side.get_global_rect()
		assert_true(sheet.position.x >= 72.0 and sheet.end.x <= vp.x and sheet.end.y <= vp.y, "%s gear sheet %s in %s" % [tag, sheet, vp])
		var gs := game.hud._side as GearScreen
		for ctl: Control in [gs._doll, gs._grid, gs._side]:
			var r := ctl.get_global_rect()
			assert_true(r.end.x <= sheet.end.x + 1.0, "%s column %s right edge %.0f <= %.0f" % [tag, ctl.name, r.end.x, sheet.end.x])
		for b in gs._doll.get_children() + gs._grid.get_children():
			if b is Button:
				assert_true((b as Button).size.x >= 63.5 and (b as Button).size.y >= 63.5, "%s cell %s" % [tag, (b as Button).size])
		assert_false(game.hud._o4_cluster.visible, tag + " thumb cluster hidden under the full-width sheet")
		_check_state(game, tag + " gear sheet")
		_drop_sheets(game)
		_settle(game, size, sc)
		assert_true(game.hud._o4_cluster.visible, tag + " cluster back"))
# endregion
