extends TestCase
## F8: ItemCard pure-data lines() and profile().


func _scene() -> Array:
	var sim := make_sim(3, false, 40, 40, peaceful_defs())
	var c := sim.colonists.spawn(Vector2i(5, 5))
	return [sim, c]


func test_lines_affixes_sockets_durability() -> void:
	var s := _scene()
	var sim: Simulation = s[0]
	var c: Colonist = s[1]
	var id := sim.give_gear(c.id, "rifle", "rare", 4)
	var g: GearItem = sim.equipment.instances[id]
	g.affixes = [["dmg_pct", 0.12], ["crit_chance", 0.05]]
	g.upgrades = ["ap_rounds"]
	g.durability = 20.0
	g.resum_stats(sim.defs)
	var L := ItemCard.lines(sim, id)
	assert_eq(L["name"], "Rifle")
	assert_eq(L["rarity"], "rare")
	assert_true((L["base"] as Array).has("+12 Damage"))
	assert_eq((L["affixes"] as Array).size(), 2)
	assert_true((L["affixes"] as Array).has("+12% Damage"))
	assert_true((L["affixes"] as Array).has("+5% Crit chance"))
	assert_eq(L["sockets"][0], "Sockets: AP Rounds (+25% Physical penetration)")
	assert_eq(L["durability"], "Durability 20/100")
	assert_true(L["durability_low"])
	var all := " ".join(L["base"]) + " ".join(L["affixes"]) + " ".join(L["sockets"]) + str(L["durability"])
	for raw in ["dmg_pct", "crit_chance", "ap_rounds", "pen_pct_phys"]:
		assert_false(all.contains(raw), "no raw id " + raw)
	assert_true(ItemCard.lines(sim, 9999).is_empty())


func test_empty_socket_and_broken() -> void:
	var s := _scene()
	var sim: Simulation = s[0]
	var c: Colonist = s[1]
	var id := sim.give_gear(c.id, "helmet", "epic", 4)
	sim.equipment.set_durability(id, 0.0)
	var L := ItemCard.lines(sim, id)
	assert_eq(L["sockets"][0], "Sockets: [empty], [empty]")
	assert_true(str(L["durability"]).contains("Broken: stats halved"))


func test_card_builds_and_hint() -> void:
	var s := _scene()
	var sim: Simulation = s[0]
	var c: Colonist = s[1]
	var card := ItemCard.make(sim, sim.give_gear(c.id, "kevlar_vest", "rare", 4))
	_owned_nodes.append(card)
	assert_true(card.custom_minimum_size.x <= 360.0)
	card.set_item(sim, -1)
	assert_eq(ItemCard.lines(sim, -1).size(), 0)


func test_profile_matches_totals() -> void:
	var s := _scene()
	var sim: Simulation = s[0]
	var c: Colonist = s[1]
	sim.equip(c.id, sim.give_gear(c.id, "kevlar_vest", "common", 0))
	sim.equip(c.id, sim.give_gear(c.id, "helmet", "common", 0))
	var p := ItemCard.profile(sim, c.id)
	var ap := roundi(sim.equipment.total(c.id, "armor_phys"))
	var ae := roundi(sim.equipment.total(c.id, "armor_energy"))
	assert_eq(ap, 60)
	assert_eq(p[0], "Armour: %d phys / %d energy" % [ap, ae])
	assert_eq(p.size(), 4)
	assert_eq(p[2], "Max HP: %d" % roundi(c.max_hp))


func test_repair_line_only_when_damaged() -> void:  # F9W3
	var s := _scene()
	var sim: Simulation = s[0]
	var c: Colonist = s[1]
	var id := sim.give_gear(c.id, "helmet", "common", 0)
	assert_eq(ItemCard.lines(sim, id)["repair"], "")
	sim.equipment.set_durability(id, 40.0)
	assert_eq(ItemCard.lines(sim, id)["repair"], "Repair: 2 plate")
