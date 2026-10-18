extends SceneTree
## Creature-scale micro benchmark: N enemies on a W x H map, times ThreatSystem.tick() only.
## godot --headless --path . -s tools/perf_threat.gd -- --n=300 --size=250 --turrets=0 --ticks=600
const TestCase := preload("res://tests/test_case.gd")


func _arg(name: String, def: int) -> int:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return int(a.split("=")[1])
	return def


func _init() -> void:
	var n := _arg("n", 300)
	var size := _arg("size", 250)
	var turrets := _arg("turrets", 0)
	var ticks := _arg("ticks", 600)
	var bus: Node = load("res://autoload/event_bus.gd").new()
	var sim := Simulation.new(7, bus, TestCase.peaceful_defs())
	sim.start_empty(size, size)
	sim.threats.threat_v2 = _arg("v2", 0) == 1
	var c := sim.map_center()
	for i in 6:
		sim.buildings.place("bed", c + Vector2i(i * 2, 0), false)
	sim.buildings.place("refinery", c + Vector2i(-6, 4), false)
	for i in turrets:
		sim.buildings.place("turret", c + Vector2i(-4 + i * 2, -4), false)
	for i in 4:
		sim.colonists.spawn(c + Vector2i(i, 3))
	for i in n:
		sim.threats._spawn("crawler", Vector2i(1 + sim.rng.randi_range(0, 3), 1 + (i * 7) % (size - 2)))
	var times: Array[int] = []
	
	print("setup done")
	for t in ticks:
		sim.tick += 1
		var t0 := Time.get_ticks_usec()
		sim.threats.tick()
		times.append(Time.get_ticks_usec() - t0)
		sim.colonists.tick()
	var warm := mini(150, times.size() / 2)
	var steady := times.slice(warm)
	var ssum := 0
	for x in steady:
		ssum += x
	print("steady (after tick %d): avg=%.2fms" % [warm, ssum / 1000.0 / steady.size()])
	var sorted := steady.duplicate()
	sorted.sort()
	var sum := 0
	for x in times:
		sum += x
	print("n=%d size=%d turrets=%d alive=%d avg=%.2fms steady_p95=%.2fms max=%.2fms astar_calls=%s" % [n, size, turrets, sim.threats.enemies.size(),
		sum / 1000.0 / times.size(), sorted[int(sorted.size() * 0.95)] / 1000.0, times.max() / 1000.0, str(sim.pathfinder.get("astar_calls"))])
	sim.dispose()
	quit()
