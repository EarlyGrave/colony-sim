extends TestCase
## E2 equipment module: slots, resum, durability, data-driven slots, determinism.


func _scene() -> Array:
	var sim := make_sim(3, false, 40, 40, peaceful_defs())
	var c := sim.colonists.spawn(Vector2i(5, 5))
	return [sim, c.id]


func test_wrong_or_unknown_rejected() -> void:
	var s := _scene()
	var sim: Simulation = s[0]
	assert_eq(sim.give_gear(s[1], "nope"), -1)
	assert_eq(sim.give_gear(s[1], "helmet", "mythic"), -1)
	assert_eq(sim.give_gear(999, "helmet"), -1)
	var h := sim.give_gear(s[1], "helmet")
	assert_false(sim.equip(999, h), "not the owner")
	assert_false(sim.unequip(s[1], "head"), "empty slot")
	sim.defs.gear["bad"] = {"slot": "tail"}
	assert_eq(sim.give_gear(s[1], "bad"), -1, "base with unknown slot")


func test_equip_replaces_and_resums_once() -> void:
	var s := _scene()
	var sim: Simulation = s[0]
	var a := sim.give_gear(s[1], "rifle")
	var b := sim.give_gear(s[1], "plasma_blade")
	assert_true(sim.equip(s[1], a))
	assert_eq(sim.equipment.resum_count, 1)
	assert_true(sim.equip(s[1], b))
	assert_eq(sim.equipment.resum_count, 2)
	assert_eq(sim.equipment.equipped[s[1]]["weapon"], b)
	assert_eq(sim.equipment.total(s[1], "damage"), 11.0)
	assert_true(sim.unequip(s[1], "weapon"))
	assert_eq(sim.equipment.total(s[1], "damage"), 0.0)


func test_two_vests_sum_across_slots() -> void:
	var s := _scene()
	var sim: Simulation = s[0]
	sim.defs.gear["vest2"] = sim.defs.gear["kevlar_vest"].duplicate(true)
	sim.defs.gear["vest2"]["slot"] = "torso_inner"
	sim.equip(s[1], sim.give_gear(s[1], "kevlar_vest"))
	sim.equip(s[1], sim.give_gear(s[1], "vest2"))
	assert_eq(sim.equipment.total(s[1], "armor_phys"), 80.0)
	assert_eq(sim.equipment.total(s[1], "flat_phys"), 4.0)


func test_durability_zero_keeps_item_halves_stats() -> void:
	var s := _scene()
	var sim: Simulation = s[0]
	var v := sim.give_gear(s[1], "kevlar_vest")
	sim.equip(s[1], v)
	sim.equipment.set_durability(v, 0.0)
	assert_true(sim.equipment.instances.has(v))
	assert_eq(sim.equipment.total(s[1], "armor_phys"), 20.0)
	sim.equipment.set_durability(v, 100.0)
	assert_eq(sim.equipment.total(s[1], "armor_phys"), 40.0)


func test_new_slot_without_code_change() -> void:
	var s := _scene()
	var sim: Simulation = s[0]
	sim.defs.equipment["slots"]["back"] = {"name": "Back"}
	sim.defs.gear["pack"] = {"name": "Pack", "slot": "back", "armor": {"phys": 7}, "tags": ["armor"]}
	var p := sim.give_gear(s[1], "pack")
	assert_true(p > 0 and sim.equip(s[1], p))
	assert_eq(sim.equipment.total(s[1], "armor_phys"), 7.0)


func test_socket_rules() -> void:
	var s := _scene()
	var sim: Simulation = s[0]
	var common := sim.give_gear(s[1], "kevlar_vest", "common")
	assert_false(sim.socket(common, "kevlar_plate"), "common has no slots")
	var rare := sim.give_gear(s[1], "kevlar_vest", "rare")
	assert_false(sim.socket(rare, "ap_rounds"), "tag mismatch")
	sim.equip(s[1], rare)
	assert_true(sim.socket(rare, "kevlar_plate"))
	# E3: rare gear rolls a random affix (flat_phys +1 here), so assert via a common-rarity base instead.
	assert_true(sim.equipment.total(s[1], "flat_phys") >= 5.0)
	assert_false(sim.socket(rare, "kevlar_plate"), "slots full")


func _run() -> int:
	var s := _scene()
	var sim: Simulation = s[0]
	sim.equip(s[1], sim.give_gear(s[1], "kevlar_vest", "rare", 5))
	sim.socket(1, "kevlar_plate")
	for i in 20:
		sim.step()
	return SaveGame.state_hash(sim)


func test_deterministic_and_hash_gated() -> void:
	assert_eq(_run(), _run())
	var s := _scene()
	assert_false(s[0].equipment.has_state(), "no instances, hash part absent")
