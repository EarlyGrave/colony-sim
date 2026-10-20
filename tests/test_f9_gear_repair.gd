extends TestCase
## F9W3: gear wear (behind durability.wear_enabled) and plate repair at a workbench.


func _scene(wear := false) -> Array:
	var defs := peaceful_defs()
	defs.equipment["durability"]["wear_enabled"] = wear
	var sim := make_sim(3, false, 40, 40, defs)
	var c := sim.colonists.spawn(Vector2i(5, 5))
	return [sim, c]


func _bench(sim: Simulation) -> Building:
	return sim.buildings.place("workbench", Vector2i(10, 5), false)


func _plates(sim: Simulation, n: int) -> void:
	for x in 4:
		sim.set_zone(Vector2i(6 + x, 6), "stockpile")
	sim.ledger.record_produced("plate", n, "test")
	sim.items.drop(Vector2i(6, 6), "plate", n)
	assert_eq(sim.items.count_stored("plate"), n, "plates stored")


func test_wear_off_by_default() -> void:
	assert_false(bool(peaceful_defs().equipment["durability"]["wear_enabled"]))
	var s := _scene(false)
	var sim: Simulation = s[0]
	var c: Colonist = s[1]
	var id := sim.give_gear(c.id, "helmet", "common", 0)
	sim.equip(c.id, id)
	sim.equipment.wear_hit_taken(c.id)
	sim.equipment.wear_attack(c.id)
	assert_eq(sim.equipment.instances[id].durability, 100.0)


func test_wear_on_loses_durability() -> void:
	var s := _scene(true)
	var sim: Simulation = s[0]
	var c: Colonist = s[1]
	var h := sim.give_gear(c.id, "helmet", "common", 0)
	var w := sim.give_gear(c.id, "prison_shiv", "common", 0)
	sim.equip(c.id, h)
	sim.equip(c.id, w)
	sim.equipment.wear_hit_taken(c.id)
	sim.equipment.wear_attack(c.id)
	assert_true(is_equal_approx(sim.equipment.instances[h].durability, 99.8), "armour loses per hit")
	assert_true(is_equal_approx(sim.equipment.instances[w].durability, 99.9), "weapon loses per attack")


func test_repair_cost_and_refusals() -> void:
	var s := _scene()
	var sim: Simulation = s[0]
	var c: Colonist = s[1]
	var id := sim.give_gear(c.id, "helmet", "common", 0)
	assert_eq(sim.equipment.repair_cost(id), 0, "full durability")
	sim.equipment.set_durability(id, 50.0)
	assert_eq(sim.equipment.repair_cost(id), 2, "ceil(0.5 * 3)")
	sim.equipment.set_durability(id, 0.0)
	assert_eq(sim.equipment.repair_cost(id), 3)
	_plates(sim, 5)
	assert_false(sim.repair_gear(id), "no workbench")
	assert_eq(sim.items.count_stored("plate"), 5)
	_bench(sim)
	sim.items.consume_stored("plate", 4, sim.map_center())
	assert_false(sim.repair_gear(id), "short on plates")
	assert_eq(sim.equipment.instances[id].durability, 0.0)


func test_repair_restores_and_pays() -> void:
	var s := _scene()
	var sim: Simulation = s[0]
	var c: Colonist = s[1]
	var id := sim.give_gear(c.id, "kevlar_vest", "common", 0)
	sim.equip(c.id, id)
	var full := sim.equipment.total(c.id, "armor_phys")
	sim.equipment.set_durability(id, 0.0)
	assert_lt(sim.equipment.total(c.id, "armor_phys"), full, "broken armour is weaker")
	_bench(sim)
	_plates(sim, 4)
	assert_true(sim.repair_gear(id))
	assert_eq(sim.items.count_stored("plate"), 1, "3 plates paid")
	assert_eq(sim.equipment.instances[id].durability, 100.0)
	assert_true(is_equal_approx(sim.equipment.total(c.id, "armor_phys"), full), "stats back to full")
	assert_false(sim.repair_gear(id), "undamaged: refused")
	assert_true(str(sim.command_log).contains("repair_gear"), "recorded")


func test_broken_bench_refuses() -> void:
	var s := _scene()
	var sim: Simulation = s[0]
	var c: Colonist = s[1]
	var id := sim.give_gear(c.id, "helmet", "common", 0)
	sim.equipment.set_durability(id, 10.0)
	_plates(sim, 3)
	var b := _bench(sim)
	b.broken = true
	assert_false(sim.repair_gear(id))


func _run(seed_v: int) -> int:
	var defs := peaceful_defs()
	defs.equipment["durability"]["wear_enabled"] = true
	var sim := make_sim(seed_v, false, 40, 40, defs)
	var c := sim.colonists.spawn(Vector2i(5, 5))
	var id := sim.give_gear(c.id, "helmet", "common", 0)
	sim.equip(c.id, id)
	for i in 30:
		sim.equipment.wear_hit_taken(c.id)
	sim.run_ticks(50)
	return SaveGame.state_hash(sim)


func test_deterministic_and_save_load() -> void:
	assert_eq(_run(5), _run(5))
	var s := _scene(true)
	var sim: Simulation = s[0]
	var c: Colonist = s[1]
	var id := sim.give_gear(c.id, "helmet", "common", 0)
	sim.equip(c.id, id)
	sim.equipment.set_durability(id, 40.0)
	var h := SaveGame.state_hash(sim)
	assert_ne(h, 0)
	sim.equipment.set_durability(id, 100.0)
	assert_ne(SaveGame.state_hash(sim), h, "durability is part of the state hash")


func test_screen_repair_button() -> void:
	var s := _scene()
	var sim: Simulation = s[0]
	var c: Colonist = s[1]
	var id := sim.give_gear(c.id, "helmet", "common", 0)
	var p := GearScreen.new()
	_owned_nodes.append(p)
	p.focus_colonist(c.id)
	p.open(sim)
	p.tap_item(id)
	assert_eq(_buttons(p, "Repair").size(), 0, "no repair button at full durability")
	sim.equipment.set_durability(id, 40.0)
	p.tap_item(id)
	p._rebuild()
	var bs := _buttons(p, "Repair")
	assert_eq(bs.size(), 1)
	assert_true(bs[0].disabled, "no bench / plates")
	assert_eq(bs[0].text, "Repair (2 plate)")
	_bench(sim)
	_plates(sim, 2)
	p._rebuild()
	bs = _buttons(p, "Repair")
	assert_false(bs[0].disabled)
	p.do_repair()
	assert_eq(sim.equipment.instances[id].durability, 100.0)


func _buttons(n: Node, prefix: String) -> Array:
	var out: Array = []
	if n is Button and (n as Button).text.begins_with(prefix):
		out.append(n)
	for ch in n.get_children():
		out.append_array(_buttons(ch, prefix))
	return out
