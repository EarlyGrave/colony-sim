extends TestCase
## CX: role balance targets from tools/combat_model.gd (analytic, data-driven).

const Model := preload("res://tools/combat_model.gd")


func test_bulwark_lasts_twice_as_long_as_an_unsquadded_inmate() -> void:
	var defs := Defs.get_default()
	for id: String in defs.enemies:
		for v in ["", "mutant"]:
			var plain := Model.survive_s(defs, id, 1.0, v)
			var bulwark := Model.survive_s(defs, id, float(defs.roles["roles"]["bulwark"]["dmg_taken_mult"]), v)
			assert_true(bulwark >= 2.0 * plain, "%s %s: bulwark %.1fs vs inmate %.1fs" % [id, v, bulwark, plain])


func test_lancer_kills_brutes_in_60_percent_of_a_rifle_inmates_time() -> void:
	var defs := Defs.get_default()
	for lvl in [0, 3, 6]:
		var t := Model.lancer_vs_rifle(defs, "brute", lvl, 5.0)
		assert_true(t[0] <= 0.6 * t[1], "skill %d: lancer %.1fs vs rifle %.1fs" % [lvl, t[0], t[1]])


func test_bulwark_multiplier_is_applied_to_real_damage() -> void:
	var sim := make_sim(5, false, 30, 30, peaceful_defs())
	var b := sim.colonists.spawn(Vector2i(5, 5))
	var p := sim.colonists.spawn(Vector2i(8, 5))
	sim.form_squad([b.id], ["bulwark"])
	var ib := sim.health.apply_damage(b, 20.0, "arms", "bite")
	var ip := sim.health.apply_damage(p, 20.0, "arms", "bite")
	assert_near(ib.severity / ip.severity, float(sim.defs.roles["roles"]["bulwark"]["dmg_taken_mult"]), 0.001)
