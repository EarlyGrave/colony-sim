extends TestCase
## E4: 200+ fully equipped inmates in melee contact (tools/equip_bench.gd). Budget "combat" in tests/perf_budget.json
## (bucket = CombatSystem.try_attack, median of 3 x 300 ticks), bounded resum count, determinism, burst/magazine/crit rules.
## Wall-clock asserts are skipped with PERF_SKIP / PERF_SKIP_WALL (sharded runs); the determinism checks always run.

const Bench := preload("res://tools/equip_bench.gd")


func _skip_wall() -> bool:
	return OS.get_environment("PERF_SKIP") != "" or OS.get_environment("PERF_SKIP_WALL") != ""


func _median(a: Array) -> float:
	var b := a.duplicate()
	b.sort()
	return float(b[b.size() / 2])


func test_combat_budget_220_equipped() -> void:
	var f := FileAccess.open("res://tests/perf_budget.json", FileAccess.READ)
	var b: Dictionary = JSON.parse_string(f.get_as_text())
	var avgs: Array = []
	var p95s: Array = []
	for i in 3:
		var r := Bench.run_once(1, make_bus())
		avgs.append(r["combat_avg"])
		p95s.append(r["combat_p95"])
		assert_true(int(r["units"]) >= 220, "units %d" % int(r["units"]))
		assert_eq(int(r["enemies"]), 300)
		assert_true(int(r["resums"]) <= 220, "equipment resums over the run %d" % int(r["resums"]))
		assert_true(int(r["combat_resums"]) <= 220, "combat resums over the run %d" % int(r["combat_resums"]))
	print("        combat bucket (220 inmates x 6 legendary, 300 enemies): avg %.3f p95 %.3f ms" % [_median(avgs), _median(p95s)])
	if _skip_wall():
		print("        (wall-clock asserts skipped by env)")
		return
	var cap: float = float(b["noise_margin"])
	assert_true(_median(avgs) <= float(b["combat"]["avg"]) * cap, "combat avg %.3f" % _median(avgs))
	assert_true(_median(p95s) <= float(b["combat"]["p95"]) * cap, "combat p95 %.3f" % _median(p95s))


func test_equipped_run_is_deterministic() -> void:
	var a := Bench.run_once(5, make_bus(), 120)
	var c := Bench.run_once(5, make_bus(), 120)
	assert_eq(a["hash"], c["hash"], "same seed, same state_hash")
	assert_eq(a["resums"], c["resums"])
	assert_eq(a["combat_resums"], c["combat_resums"])


func _duel(weapon: String, cooldown_override := -1) -> Array:
	var sim := make_sim(3, false, 40, 40, peaceful_defs())
	var col := sim.colonists.spawn(Vector2i(10, 10))
	col.hp = 1.0e6
	col.max_hp = 1.0e6
	var gid := sim.give_gear(col.id, weapon, "common", 0)
	sim.equip(col.id, gid)
	var e: Enemy = sim.threats._spawn("crawler", Vector2i(12, 10))
	e.hp = 1.0e9
	e.max_hp = 1.0e9
	e.damage_mult = 0.0
	return [sim, col, e]


func test_smg_burst_then_cooldown() -> void:
	var s := _duel("smg")
	var sim: Simulation = s[0]
	var col: Colonist = s[1]
	var e: Enemy = s[2]
	sim.ammo.rifle_try_fire(col)  # init pouch
	var ticks: Array = []
	for t in 40:
		sim.tick += 1
		if sim.combat.try_attack(col, e):
			ticks.append(sim.tick)
	assert_true(ticks.size() >= 4, "shots %s" % str(ticks))
	assert_eq(ticks[1] - ticks[0], 1, "gap_ticks inside the burst")
	assert_eq(ticks[2] - ticks[1], 1)
	assert_eq(ticks[3] - ticks[2], 4, "cooldown after the burst")


func test_magazine_empty_reloads() -> void:
	var s := _duel("smg")
	var sim: Simulation = s[0]
	var col: Colonist = s[1]
	var e: Enemy = s[2]
	sim.combat._pattern[col.id] = [0, 1]  # one round left
	var shots: Array = []
	for t in 60:
		sim.tick += 1
		if sim.combat.try_attack(col, e):
			shots.append(sim.tick)
	# shot 1 uses the last round, the next attempt starts a reload (counts as an attempt), then fire resumes
	assert_true(shots.size() >= 3, str(shots))
	var gap := 0
	for i in range(1, shots.size()):
		gap = maxi(gap, shots[i] - shots[i - 1])
	assert_true(gap >= 30, "reload pause >= reload_ticks, got %d" % gap)


func test_crit_uses_one_rng_draw_per_hit() -> void:
	var s := _duel("plasma_blade")
	var sim: Simulation = s[0]
	var col: Colonist = s[1]
	var e: Enemy = s[2]
	assert_true(sim.combat.att_of(col)[StatBlock.CRIT] > 0.0, "blade crit reaches the att vector")
	var att := sim.combat.att_of(col)
	var def := e.def_stats
	var r1 := RandomNumberGenerator.new()
	r1.seed = 99
	var r2 := RandomNumberGenerator.new()
	r2.seed = 99
	sim.rng.seed = 99
	sim.combat.resolve_hit(att, def, 10.0, "energy")
	r2.randf()
	assert_eq(sim.rng.state, r2.state, "exactly one randf per resolved hit")
