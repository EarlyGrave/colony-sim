extends TestCase
## E1: StatBlock + CombatSystem.resolve damage formula.

const Model := preload("res://tools/combat_model.gd")


func test_table() -> void:
	assert_true(is_equal_approx(CombatSystem.resolve(20, 100, 0, 0, 0), 10.0), "armor 100 halves")
	assert_true(is_equal_approx(CombatSystem.resolve(20, 200, 0, 0, 0), 6.6666667), "armor 200")
	assert_true(is_equal_approx(CombatSystem.resolve(20, 100, 3, 0, 0), 8.5), "flat 3 then armor 100")
	assert_true(is_equal_approx(CombatSystem.resolve(20, 100, 0, 0.5, 0), 13.333333), "pen 0.5")
	assert_true(is_equal_approx(CombatSystem.resolve(20, 0, 3, 0, 3), 20.0), "flat_pen cancels flat")
	assert_eq(CombatSystem.resolve(2, 500, 10, 0, 0), 1.0, "min 1")
	assert_eq(CombatSystem.resolve(6.3, 0, 0, 0, 0), 6.3, "zero armour is identity")


func test_model_matches() -> void:
	assert_eq(Model.resolve(20, 100), CombatSystem.resolve(20, 100, 0, 0, 0), "model uses same formula")


func test_stat_block_and_enemy_keys() -> void:
	var a := StatBlock.make()
	StatBlock.sum_into(a, {"armor_phys": 40, "flat_phys": 2, "bogus": 9})
	StatBlock.sum_into(a, {"armor_phys": 5})
	assert_eq(a[StatBlock.ARM_PHYS], 45.0, "sums")
	assert_eq(a[StatBlock.FLAT_PHYS], 2.0, "flat")
	var sim := make_sim(3, true, 16, 16, peaceful_defs())
	var d: Dictionary = sim.defs.enemies["crawler"].duplicate(true)
	d["armor"] = {"phys": 100, "energy": 0}
	var e := Enemy.new(1, "crawler", d, Vector2i(2, 2))
	var plain := Enemy.new(2, "crawler", sim.defs.enemies["crawler"], Vector2i(2, 2))
	assert_eq(sim.combat.resolve_hit(StatBlock.make(), e.def_stats, 20.0), 10.0, "armoured enemy")
	assert_eq(sim.combat.resolve_hit(StatBlock.make(), plain.def_stats, 20.0), 20.0, "armor 0 = old number")
