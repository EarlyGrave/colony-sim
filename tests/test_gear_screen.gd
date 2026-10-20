extends TestCase
## F8: gear screen (paper-doll, grid inventory, card, tap-only actions).


func _scene() -> Array:
	var sim := make_sim(3, false, 40, 40, peaceful_defs())
	var c := sim.colonists.spawn(Vector2i(5, 5))
	sim.equipment.instances.clear()
	sim.equipment.equipped.clear()
	sim.equipment.totals.clear()
	sim.equipment._next_id = 1
	sim.colonists._f3a_pending.clear()
	return [sim, c]


func _open(sim: Simulation, cid: int) -> GearScreen:
	var p := GearScreen.new()
	_owned_nodes.append(p)
	p.focus_colonist(cid)
	p.open(sim)
	return p


func test_registered_with_label_gear() -> void:
	var found := false
	for e: Array in PanelRegistry.panel_entries():
		if e[0] == "gear_screen":
			found = true
			assert_eq(e[1], "Gear")
	assert_true(found, "gear_screen in PANELS")
	assert_true(PanelRegistry.make_panel("gear_screen") is GearScreen)


func test_equip_and_unequip_through_panel() -> void:
	var s := _scene()
	var sim: Simulation = s[0]
	var c: Colonist = s[1]
	var id := sim.give_gear(c.id, "helmet", "rare", 4)
	var p := _open(sim, c.id)
	p.tap_item(id)
	assert_eq(p.sel_id, id)
	p.do_equip()
	assert_eq(sim.equipment.equipped[c.id]["head"], id, "equipped")
	p.tap_slot("head")  # worn slot selects it
	assert_eq(p.sel_id, id)
	p.do_unequip()
	assert_false(sim.equipment.equipped.get(c.id, {}).has("head"), "unequipped")


func test_tap_matching_slot_equips_and_wrong_slot_only_hints() -> void:
	var s := _scene()
	var sim: Simulation = s[0]
	var c: Colonist = s[1]
	var id := sim.give_gear(c.id, "helmet", "common", 0)
	var p := _open(sim, c.id)
	p.tap_item(id)
	p.tap_slot("legs")
	assert_true(p.hint != "", "hint shown")
	assert_false(sim.equipment.equipped.get(c.id, {}).has("legs"), "no command")
	assert_false(sim.equipment.equipped.get(c.id, {}).has("head"), "no command")
	p.tap_slot("head")
	assert_eq(sim.equipment.equipped[c.id]["head"], id)


func test_twenty_items_make_twenty_cells_and_select() -> void:
	var s := _scene()
	var sim: Simulation = s[0]
	var c: Colonist = s[1]
	var ids: Array = []
	for i in 20:
		ids.append(sim.give_gear(c.id, "helmet", "common", i))
	var p := _open(sim, c.id)
	var buttons := p._grid.get_children().filter(func(n: Node) -> bool: return n is Button)
	assert_eq(buttons.size(), 20, "one button per stored item")
	assert_eq(p._grid.get_child_count(), 20, "20 items fill 4 full rows")
	(buttons[7] as Button).pressed.emit()
	assert_eq(p.sel_id, ids[7], "tap selects")


func test_min_fifteen_cells_and_six_slots() -> void:
	var s := _scene()
	var sim: Simulation = s[0]
	var c: Colonist = s[1]
	sim.give_gear(c.id, "helmet", "common", 0)
	var p := _open(sim, c.id)
	assert_eq(p._grid.get_child_count(), 15)
	assert_eq(p._doll.get_child_count(), 6)
	for b in p._doll.get_children():
		assert_true((b as Control).custom_minimum_size.x >= 72.0)


func test_socket_through_panel() -> void:
	var s := _scene()
	var sim: Simulation = s[0]
	var c: Colonist = s[1]
	var id := sim.give_gear(c.id, "rifle", "rare", 2)
	var p := _open(sim, c.id)
	p.tap_item(id)
	var opts := GearPanel.socket_options(sim, id)
	assert_true(opts.size() > 0)
	p.do_socket(opts[0])
	assert_eq((sim.equipment.instances[id] as GearItem).upgrades.size(), 1)


func test_refresh_follows_sim_changes_and_buttons_are_tall() -> void:
	var s := _scene()
	var sim: Simulation = s[0]
	var c: Colonist = s[1]
	var p := _open(sim, c.id)
	assert_eq(p._grid.get_child_count(), 15)
	for i in 16:
		sim.give_gear(c.id, "helmet", "common", i)
	p.refresh()
	assert_eq(p._grid.get_child_count(), 20, "grows by rows")
	var id: int = sim.equipment.stored_of(c.id)[0]
	p.tap_item(id)
	for n in p._side.get_children():
		if n is Button:
			assert_true((n as Button).custom_minimum_size.y >= 64.0)


func test_inspector_has_open_gear_button() -> void:
	var s := _scene()
	var sim: Simulation = s[0]
	var c: Colonist = s[1]
	sim.equip(c.id, sim.give_gear(c.id, "helmet", "rare", 4))
	var asked: Array = []
	var box := VBoxContainer.new()
	_owned_nodes.append(box)
	var target := {"colonist": c, "request_panel": func(pid: String, cid: int) -> void: asked.append([pid, cid])}
	GearPanel.new().build(sim, target, box)
	var b := box.get_child(0) as Button
	assert_true(b != null and b.text == "Open gear" and b.custom_minimum_size.y >= 64.0)
	b.pressed.emit()
	assert_eq(asked, [["gear_screen", c.id]])
