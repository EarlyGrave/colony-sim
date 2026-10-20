extends TestCase
## F10W2: late-game perf scenario (tools/perf_scenario.gd late_game): metro drone raid, 10 fully equipped inmates,
## quests, petition alt, wear ON. Median of 3 x 300 ticks per bucket vs "late" in tests/perf_budget.json x noise_margin.
## Wall-clock asserts are skipped with PERF_SKIP / PERF_SKIP_WALL; the scenario sanity checks always run.

const Scenario := preload("res://tools/perf_scenario.gd")
const WARMUP := 100
const TICKS := 300
const RUNS := 3


func _skip() -> bool:
	return OS.get_environment("PERF_SKIP") != "" or OS.get_environment("PERF_SKIP_WALL") != ""


func _median(a: Array) -> float:
	var b := a.duplicate()
	b.sort()
	return float(b[b.size() / 2])


func _build() -> Array:
	var sim := Scenario.late_sim(1, make_bus())
	_sims.append(sim)
	var info := Scenario.late_game(sim)
	for i in WARMUP:
		sim.step()
	return [sim, info]


func test_late_scenario_contents() -> void:
	var r := _build()
	var sim: Simulation = r[0]
	var info: Dictionary = r[1]
	assert_eq(int(info["inmates"]), 10)
	assert_true(int(info["gear"]) >= 60, "gear %d" % int(info["gear"]))
	assert_eq(int(info["quests"]), 2)
	assert_true(bool(info["alt"]), "petition alt available")
	assert_true(str(info["raid"]) != "", "a drone raid was started")
	assert_true(sim.threats.wave_active, "raid / wave active")
	assert_true(sim.equipment.wear_enabled(), "wear forced ON in the copy")
	assert_false(bool(Defs.get_default().equipment["durability"]["wear_enabled"]), "shared Defs untouched")
	assert_eq(sim.colonists.alive_count(), sim.colonists.list.size(), "nobody died in warm-up")


func test_late_budgets() -> void:
	var f := FileAccess.open("res://tests/perf_budget.json", FileAccess.READ)
	var b: Dictionary = JSON.parse_string(f.get_as_text())
	var late: Dictionary = b["late"]
	var avgs := {}
	var p95s := {}
	for r in RUNS:
		var sim: Simulation = _build()[0]
		var m := Scenario.measure(sim, TICKS)
		for k in Scenario.LATE_BUCKETS:
			var arr: Array = m.get(k, [0.0])
			if not avgs.has(k):
				avgs[k] = []
				p95s[k] = []
			avgs[k].append(Scenario.avg(arr))
			p95s[k].append(Scenario.p95(arr))
	var cap := float(b["noise_margin"])
	print("        late-game perf (median of %d x %d ticks, ms/tick):" % [RUNS, TICKS])
	for k in Scenario.LATE_BUCKETS:
		var av := _median(avgs[k])
		var p9 := _median(p95s[k])
		print("        %-14s avg %.3f (limit %.3f)  p95 %.3f (limit %.3f)" % [k, av, float(late[k]["avg"]), p9, float(late[k]["p95"])])
		if _skip():
			continue
		assert_true(av <= float(late[k]["avg"]) * cap, "late %s avg %.3f" % [k, av])
		assert_true(p9 <= float(late[k]["p95"]) * cap, "late %s p95 %.3f" % [k, p9])
