extends SceneTree
## W1a bench: ThreatSystem.tick() with ~8k belt cells + N enemies on a SIZE x SIZE map, built via Simulation commands.
## godot --headless --path . -s tools/perf_threat_belts.gd -- --n=300 --size=250 --belts=1 --ticks=600
const TestCase := preload("res://tests/test_case.gd")


func _arg(name: String, def: int) -> int:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return int(a.split("=")[1])
	return def


func _init() -> void:
	var n := _arg("n", 300)
	var size := _arg("size", 250)
	var ticks := _arg("ticks", 600)
	var bus: Node = load("res://autoload/event_bus.gd").new()
	var sim := Simulation.new(7, bus, TestCase.peaceful_defs())
	sim.start_empty(size, size)
	var c := sim.map_center()
	for i in 6:
		sim.buildings.place("bed", c + Vector2i(i * 2, 0), false)
	sim.buildings.place("refinery", c + Vector2i(-6, 4), false)
	for i in 3:
		sim.buildings.place("turret", c + Vector2i(-4 + i * 2, -4), false)
	for i in 4:
		sim.colonists.spawn(c + Vector2i(i, 3))
	if _arg("belts", 1) == 1:
		var row := 0
		for y in range(4, size - 4, 3):  # serpentine rows, 3 apart
			var cells: Array = []
			for x in range(4, size - 4):
				cells.append(Vector2i(x if row % 2 == 0 else size - 1 - x, y))
			if sim.place_belt(cells, 0):
				row += 1
			if sim.logistics.belts.belt_count >= 8000:
				break
	print("belts=%d" % sim.logistics.belts.belt_count)
	for i in n:
		sim.threats._spawn("crawler", Vector2i(1 + sim.rng.randi_range(0, 3), 1 + (i * 7) % (size - 2)))
	var times: Array[int] = []
	for t in ticks:
		sim.tick += 1
		var t0 := Time.get_ticks_usec()
		sim.threats.tick()
		times.append(Time.get_ticks_usec() - t0)
		sim.colonists.tick()
	var sorted := times.duplicate()
	sorted.sort()
	var sum := 0
	for x in times:
		sum += x
	print("n=%d size=%d belts=%d alive=%d avg=%.2fms p95=%.2fms max=%.2fms hash=%d" % [n, size, sim.logistics.belts.belt_count, sim.threats.enemies.size(),
		sum / 1000.0 / times.size(), sorted[int(sorted.size() * 0.95)] / 1000.0, times.max() / 1000.0, SaveGame.state_hash(sim)])
	sim.dispose()
	quit()
