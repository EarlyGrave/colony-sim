extends TestCase
## E5: gear panel wiring (UI -> recorded commands), crafting and drops (deterministic).


func _scene(seed_v := 3) -> Array:
	var sim := make_sim(seed_v, false, 40, 40, peaceful_defs())
	var c := sim.colonists.spawn(Vector2i(5, 5))
	return [sim, c]


func _press(box: Node, label_start: String) -> bool:
	for b: Button in box.find_children("*", "Button", true, false):
		if b.text.begins_with(label_start):
			assert_true(b.custom_minimum_size.y >= 64.0, "button >= 64 px")
			b.pressed.emit()
			return true
	return false


func _build(sim: Simulation, c: Colonist) -> VBoxContainer:
	var box := VBoxContainer.new()
	_owned_nodes.append(box)
	GearPanel.new().build(sim, {"colonist": c}, box)
	return box


func test_ui_equip_unequip_socket_commands() -> void:
	var s := _scene()
	var sim: Simulation = s[0]
	var c: Colonist = s[1]
	var id := sim.give_gear(c.id, "kevlar_vest", "uncommon", 2)
	var p := GearPanel.new()
	assert_true(p.applies(sim, {"colonist": c}), "stored gear shows the section")
	assert_true(_press(_build(sim, c), "Socket: Kevlar"), "socket button")
	assert_eq(sim.equipment.instances[id].upgrades.size(), 1)
	assert_true(_press(_build(sim, c), "Equip"))
	assert_eq(sim.equipment.equipped[c.id]["torso_outer"], id)
	assert_true(sim.equipment.stored_of(c.id).is_empty())
	assert_true(_press(_build(sim, c), "Unequip"))
	assert_eq(sim.equipment.stored_of(c.id), [id])
	var txt := str(sim.command_log)
	assert_true(txt.contains("socket") and txt.contains("unequip"), "commands recorded")


func _craft_once(seed_v: int) -> String:
	var s := _scene(seed_v)
	var sim: Simulation = s[0]
	var c: Colonist = s[1]
	var b := sim.buildings.place("workbench", Vector2i(10, 5), false)
	sim.ledger.record_produced("machine_parts", 3, "test")
	sim.ledger.record_produced("refined_essence", 2, "test")
	b.input["machine_parts"] = 3
	b.input["refined_essence"] = 2
	assert_gt(sim.add_bill(b.id, "craft_gear_vest", "count", 1), 0)
	sim.crafting._select(b)
	assert_true(sim.buildings.work(b, int(b.recipe["work_ticks"]), c))
	assert_eq(sim.equipment.instances.size(), 1, "one gear instance crafted")
	var g: GearItem = sim.equipment.instances.values()[0]
	assert_eq(g.base, "kevlar_vest")
	assert_eq(g.owner, c.id)
	return "%s|%d|%s" % [g.rarity, g.affixes.size(), str(g.affixes)]


func test_craft_is_deterministic() -> void:
	assert_eq(_craft_once(11), _craft_once(11))


func _drops(seed_v: int, n: int) -> String:
	var s := _scene(seed_v)
	var sim: Simulation = s[0]
	var c: Colonist = s[1]
	sim.defs.equipment["sources"]["drops"]["metropolis"]["chance"] = 0.5
	for i in n:
		var e: Enemy = sim.threats._spawn("drone_scout", Vector2i(20, 20))
		sim.threats.damage_enemy(e, 9999.0, "generic", c)
	var out: Array = []
	for id: int in sim.equipment.instances:
		var g: GearItem = sim.equipment.instances[id]
		out.append("%s:%s:%d" % [g.base, g.rarity, g.owner])
	return str(out)


func test_drone_drops_deterministic_and_faction_gated() -> void:
	var a := _drops(5, 30)
	assert_eq(a, _drops(5, 30))
	assert_ne(a, "[]", "some drops at 50%")
	var s := _scene()
	var sim: Simulation = s[0]
	var e: Enemy = sim.threats._spawn("crawler", Vector2i(20, 20))
	sim.threats.damage_enemy(e, 9999.0)
	assert_eq(sim.equipment.instances.size(), 0, "creatures drop no gear")
