extends TestCase
## F9 W1: sockets cost stock items (data/upgrades.json "cost").


func _scene(plates: int, rounds: int = 0) -> Array:
	var sim := make_sim(3, false, 40, 40, peaceful_defs())
	var c := sim.colonists.spawn(Vector2i(5, 5))
	for x in 4:
		sim.set_zone(Vector2i(2 + x, 2), "stockpile")
	if plates > 0:
		sim.ledger.record_produced("plate", plates, "test")
		sim.items.drop(Vector2i(2, 2), "plate", plates)
	if rounds > 0:
		sim.ledger.record_produced("essence_rounds", rounds, "test")
		sim.items.drop(Vector2i(3, 2), "essence_rounds", rounds)
	return [sim, c]


func test_cost_consumed() -> void:
	var s := _scene(5)
	var sim: Simulation = s[0]
	var id := sim.give_gear(s[1].id, "kevlar_vest", "rare")
	assert_eq(int(sim.equipment.socket_cost("kevlar_plate")["plate"]), 2)
	assert_true(sim.socket(id, "kevlar_plate"))
	assert_eq(sim.items.count_stored("plate"), 3)


func test_short_refused_unchanged() -> void:
	var s := _scene(1)
	var sim: Simulation = s[0]
	var id := sim.give_gear(s[1].id, "kevlar_vest", "rare")
	assert_false(sim.socket(id, "kevlar_plate"))
	assert_eq((sim.equipment.instances[id] as GearItem).upgrades.size(), 0)
	assert_eq(sim.items.count_stored("plate"), 1)
	assert_eq(sim.equipment.socket_missing("kevlar_plate"), "1 plate")


func test_multi_item_cost_all_or_nothing() -> void:
	var s := _scene(3, 1)
	var sim: Simulation = s[0]
	var id := sim.give_gear(s[1].id, "rifle", "rare")
	assert_false(sim.socket(id, "ap_rounds"), "rounds short")
	assert_eq(sim.items.count_stored("plate"), 3, "nothing consumed")


func test_tag_mismatch_does_not_consume() -> void:
	var s := _scene(5, 5)
	var sim: Simulation = s[0]
	var id := sim.give_gear(s[1].id, "kevlar_vest", "rare")
	assert_false(sim.socket(id, "ap_rounds"))
	assert_eq(sim.items.count_stored("plate"), 5)


func test_gear_screen_buttons_disabled_when_short() -> void:
	var s := _scene(1)
	var sim: Simulation = s[0]
	var id := sim.give_gear(s[1].id, "kevlar_vest", "rare")
	var p := GearScreen.new()
	_owned_nodes.append(p)
	p.focus_colonist(s[1].id)
	p.open(sim)
	p.tap_item(id)
	var found := false
	for b: Button in p.find_children("*", "Button", true, false):
		if b.text.begins_with("Kevlar Plate"):
			found = true
			assert_true(b.disabled)
			assert_true(b.text.contains("-2 plate"))
			assert_true(b.tooltip_text.contains("Need 1 plate"))
	assert_true(found)
	p.do_socket("kevlar_plate")
	assert_true(p.hint.begins_with("Need"))


func test_deterministic_hash() -> void:
	var h: Array[int] = []
	for i in 2:
		var s := _scene(4)
		var sim: Simulation = s[0]
		sim.socket(sim.give_gear(s[1].id, "kevlar_vest", "rare", 3), "kevlar_plate")
		for t in 10:
			sim.step()
		h.append(SaveGame.state_hash(sim))
	assert_eq(h[0], h[1])
