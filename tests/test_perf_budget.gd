extends TestCase
## Perf contract (docs/optimization_strategy.md section 3): the REAL Simulation.step() is timed per system
## (sim.profiling) on 250 map / 300 harmless enemies / 12 colonists, median of 3 runs x 300 ticks after warm-up.
## Fails when a system exceeds budget * noise_margin (tests/perf_budget.json). Budgets listed under "waived"
## are printed but not enforced until their owner wave lands.
## Skip on slow machines: PERF_SKIP=1.

const Scenario := preload("res://tools/perf_scenario.gd")
const WARMUP := 100
const TICKS := 300
const RUNS := 3


func _budget() -> Dictionary:
	var f := FileAccess.open("res://tests/perf_budget.json", FileAccess.READ)
	return JSON.parse_string(f.get_as_text())


func _skip() -> bool:
	if OS.get_environment("PERF_SKIP") != "" or OS.get_environment("PERF_SKIP_WALL") != "":
		print("        (perf test skipped by env; run single-process for the budget check)")
		return true
	return false


func _sim(enemies: int, belts: int, warmup: int) -> Simulation:
	var sim := Simulation.new(1, make_bus(), null, {"map_w": 250, "map_h": 250})
	sim.start_new_game()
	_sims.append(sim)
	Scenario.fill_colonists(sim, 12)
	Scenario.lay_belts(sim, belts)
	Scenario.spawn_enemies(sim, enemies)
	for i in warmup:
		sim.step()
	return sim


func _median(a: Array) -> float:
	var b := a.duplicate()
	b.sort()
	return float(b[b.size() / 2])


func _check(b: Dictionary, key: String, value: float, limit: float, rows: Array) -> void:
	var waived: Dictionary = b["waived"]
	var cap: float = limit * float(b["noise_margin"])
	var over := value > cap
	var note := ""
	if over and (waived.has(key) or waived.has(key.get_slice(".", 0))):
		note = "  (waived: %s)" % waived.get(key, waived.get(key.get_slice(".", 0), ""))
		over = false
	rows.append("%-22s %8.3f  limit %7.3f  cap %7.3f%s%s" % [key, value, limit, cap, "  OVER" if over else "", note])
	if over:
		fail("%s %.3f exceeds budget %.3f x %.1f" % [key, value, limit, float(b["noise_margin"])])


func test_step_budgets_300_enemies() -> void:
	if _skip():
		return
	var b := _budget()
	var avgs: Dictionary = {}
	var p95s: Dictionary = {}
	var flows: Array = []
	for r in RUNS:
		var sim := _sim(300, 0, WARMUP)
		var m := Scenario.measure(sim, TICKS)
		assert_eq(sim.colonists.alive_count(), 12, "colonists must stay alive so jobs are measured")
		for k in b["systems"]:
			if not avgs.has(k):
				avgs[k] = []
				p95s[k] = []
			avgs[k].append(Scenario.avg(m[k]))
			p95s[k].append(Scenario.p95(m[k]))
		flows.append(m["flow_builds"])
	# First-tick spike: a fresh sim, no warm-up.
	var first := Scenario.measure(_sim(300, 0, 0), 1)["first_tick_ms"] as float
	var rows: Array = []
	for k in b["systems"]:
		_check(b, k + ".avg", _median(avgs[k]), float(b["systems"][k]["avg"]), rows)
		_check(b, k + ".p95", _median(p95s[k]), float(b["systems"][k]["p95"]), rows)
	_check(b, "first_tick_ms", first, float(b["first_tick_ms"]), rows)
	_check(b, "flow_builds", _median(flows) * 600.0 / TICKS, float(b["flow_builds_per_600"]), rows)
	print("        perf (250 map, 300 enemies, 12 colonists, median of %d x %d ticks, ms/tick):" % [RUNS, TICKS])
	for row in rows:
		print("        " + row)


func test_logistics_budget_8k_belts() -> void:
	if _skip():
		return
	var b := _budget()
	var sim := _sim(0, 8000, 50)
	var m := Scenario.measure(sim, 200)
	var rows: Array = []
	_check(b, "logistics8k.avg", Scenario.avg(m["logistics"]), float(b["systems"]["logistics"]["avg"]), rows)
	_check(b, "logistics8k.p95", Scenario.p95(m["logistics"]), float(b["systems"]["logistics"]["p95"]), rows)
	for row in rows:
		print("        " + row)
