extends TestCase
## E4: read-only gear section on the inmate card.


func _scene() -> Array:
	var sim := make_sim(3, false, 40, 40, peaceful_defs())
	var c := sim.colonists.spawn(Vector2i(5, 5))
	_bare(sim)
	return [sim, c]


func test_rows_follow_equipment_json_slots() -> void:
	var s := _scene()
	var sim: Simulation = s[0]
	var c: Colonist = s[1]
	sim.equip(c.id, sim.give_gear(c.id, "kevlar_vest", "rare", 4))
	var rows := GearPanel.rows(sim, c.id)
	assert_eq(rows.size(), sim.defs.equipment["slots"].size(), "one row per slot")
	for r: Dictionary in rows:
		assert_eq(r["slot_name"], sim.defs.equipment["slots"][r["slot"]]["name"])
	var armour: Array = rows.filter(func(r: Dictionary) -> bool: return r["slot"] == "torso_outer")
	assert_eq(armour[0]["item"], "Kevlar Vest")
	assert_true(str(armour[0]["stats"]).contains("armor_phys"))


func test_applies_only_with_gear_and_builds_tall_rows() -> void:
	var s := _scene()
	var sim: Simulation = s[0]
	var c: Colonist = s[1]
	var p := GearPanel.new()
	assert_false(p.applies(sim, {"colonist": c}), "no gear, no section")
	sim.equip(c.id, sim.give_gear(c.id, "helmet", "legendary", 10))
	assert_true(p.applies(sim, {"colonist": c}))
	var box := VBoxContainer.new()
	_owned_nodes.append(box)
	p.build(sim, {"colonist": c}, box)
	assert_eq(box.get_child_count(), sim.defs.equipment["slots"].size())
	for ch in box.get_children():
		assert_true((ch as Control).custom_minimum_size.y >= 64.0, "row >= 64 px")


## F3a: inmates start with a shiv; these tests count gear instances / item ids, so they begin from an empty armoury.
func _bare(sim: Simulation) -> Simulation:
	sim.equipment.instances.clear()
	sim.equipment.equipped.clear()
	sim.equipment.totals.clear()
	sim.equipment._next_id = 1
	sim.colonists._f3a_pending.clear()
	return sim
