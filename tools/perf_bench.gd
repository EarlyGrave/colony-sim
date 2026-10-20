extends Node
## Perf bench.
## godot --headless --path . res://tools/perf_bench.tscn -- --size=250 --enemies=300 --ticks=600 --seed=1 --view=0
## Prints per-system ms/tick (avg, p95). Runs the real Simulation.step() with sim.profiling = true (per-system laps).
## jobs and combat run inside the colonists/threats ticks, so they are part of those lines.
## --view=1 (needs a display, e.g. xvfb-run) runs the real game scene at 3x speed instead and
## prints view ms/frame (process + draw) for `ticks` frames.
## --colonists=12 --belts=8000 set the §3 perf-contract load.

const Scenario := preload("res://tools/perf_scenario.gd")


func _ready() -> void:
	var a := _args()
	var size := int(a.get("size", 64))
	var n_enemies := int(a.get("enemies", 0))
	var ticks := int(a.get("ticks", 600))
	var seed_value := int(a.get("seed", 1))
	var opts := {"map_w": size, "map_h": size}
	if int(a.get("view", 0)) == 1:
		await _run_view(seed_value, opts, n_enemies, ticks)
		get_tree().quit(0)
		return
	if int(a.get("late", 0)) == 1:  # region F10W2
		_run_late(seed_value, int(a.get("ticks", 300)), int(a.get("runs", 3)))
		get_tree().quit(0)
		return
	var bus: Node = load("res://autoload/event_bus.gd").new()
	var t0:= Time.get_ticks_usec()
	var sim := Simulation.new(seed_value, bus, null, opts)
	sim.start_new_game()
	var gen_ms := (Time.get_ticks_usec() - t0) / 1000.0
	Scenario.fill_colonists(sim, int(a.get("colonists", 12)))
	var belts := Scenario.lay_belts(sim, int(a.get("belts", 0)))
	var spawned := Scenario.spawn_enemies(sim, n_enemies)
	print("bench belts=%d size=%d enemies=%d/%d ticks=%d seed=%d gen=%.0fms" % [belts, size, spawned, n_enemies, ticks, seed_value, gen_ms])
	var samples := Scenario.measure(sim, ticks)
	var keys: Array = samples.keys()
	keys.sort()
	for k in keys:
		if k == "first_tick_ms" or k == "flow_builds":
			continue
		print("%-14s avg %.3f ms  p95 %.3f ms" % [k, _avg(samples[k]), _p95(samples[k])])
	print("first-tick %.2f ms  flow_builds %d  colonists alive %d/%d" % [samples["first_tick_ms"], samples["flow_builds"],
		sim.colonists.alive_count(), sim.colonists.list.size()])
	print("jobs/combat run inside the colonists/threats lines")
	get_tree().quit(0)


# region F10W2
## --late=1 [--runs=3 --ticks=300 --seed=1]: late-game scenario (Scenario.late_game), median of `runs`, table vs the "late" budget.
func _run_late(seed_value: int, ticks: int, runs: int) -> void:
	var f := FileAccess.open("res://tests/perf_budget.json", FileAccess.READ)
	var b: Dictionary = JSON.parse_string(f.get_as_text())
	var late: Dictionary = b.get("late", {})
	var avgs := {}
	var p95s := {}
	var info := {}
	for r in runs:
		var bus: Node = load("res://autoload/event_bus.gd").new()
		var sim := Scenario.late_sim(seed_value, bus)
		info = Scenario.late_game(sim)
		for i in 100:
			sim.step()
		var m := Scenario.measure(sim, ticks)
		for k in Scenario.LATE_BUCKETS:
			var arr: Array = m.get(k, [0.0])
			if not avgs.has(k):
				avgs[k] = []
				p95s[k] = []
			avgs[k].append(Scenario.avg(arr))
			p95s[k].append(Scenario.p95(arr))
		bus.free()
	print("late-game %s (median of %d x %d ticks, ms/tick)" % [str(info), runs, ticks])
	print("%-14s %8s %8s %8s %8s" % ["bucket", "avg", "p95", "budget.avg", "budget.p95"])
	for k in Scenario.LATE_BUCKETS:
		var av := _median(avgs[k])
		var p9 := _median(p95s[k])
		var lim: Dictionary = late.get(k, {})
		print("%-14s %8.3f %8.3f %8s %8s  (delta avg %s, p95 %s)" % [k, av, p9, str(lim.get("avg", "-")), str(lim.get("p95", "-")),
			("%+.3f" % (av - float(lim["avg"]))) if lim.has("avg") else "-", ("%+.3f" % (p9 - float(lim["p95"]))) if lim.has("p95") else "-"])


func _median(a: Array) -> float:
	var s: Array = a.duplicate()
	s.sort()
	return float(s[s.size() / 2])
# endregion


func _run_view(seed_value: int, opts: Dictionary, n_enemies: int, frames: int) -> void:
	var game: Node = (load("res://view/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	game.new_game(seed_value, opts)
	var spawned := Scenario.spawn_enemies(game.sim, n_enemies)
	game.set_speed(3)
	var s: Array = []
	for i in frames:
		var f0 := Time.get_ticks_usec()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		s.append((Time.get_ticks_usec() - f0) / 1000.0)
	print("view size=%s enemies=%d frames=%d tick=%d" % [opts["map_w"], spawned, frames, game.sim.tick])
	print("%-14s avg %.3f ms  p95 %.3f ms" % ["view/frame", _avg(s), _p95(s)])


func _lap(samples: Dictionary, key: String, prev: int) -> int:
	var now := Time.get_ticks_usec()
	(samples[key] as Array).append((now - prev) / 1000.0)
	return now


func _avg(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for v in a:
		s += v
	return s / a.size()


func _p95(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var b: Array = a.duplicate()
	b.sort()
	return b[mini(b.size() - 1, int(b.size() * 0.95))]


func _args() -> Dictionary:
	var d := {}
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--") and "=" in s:
			var kv := s.substr(2).split("=", true, 1)
			d[kv[0]] = kv[1]
	return d
