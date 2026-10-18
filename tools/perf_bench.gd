extends Node
## Perf bench.
## godot --headless --path . res://tools/perf_bench.tscn -- --size=250 --enemies=300 --ticks=600 --seed=1 --view=0
## Prints per-system ms/tick (avg, p95). Mirrors Simulation.step() order to time each part.
## jobs and combat run inside the colonists/threats ticks, so they are part of those lines.
## --view=1 (needs a display, e.g. xvfb-run) runs the real game scene at 3x speed instead and
## prints view ms/frame (process + draw) for `ticks` frames.

const SYSTEMS: Array[String] = ["buildings", "colonists", "threats", "contamination", "mutation", "storyteller"]


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
	var bus: Node = load("res://autoload/event_bus.gd").new()
	var t0 := Time.get_ticks_usec()
	var sim := Simulation.new(seed_value, bus, null, opts)
	sim.start_new_game()
	var gen_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var spawned := _spawn_enemies(sim, n_enemies)
	print("bench size=%d enemies=%d/%d ticks=%d seed=%d gen=%.0fms" % [size, spawned, n_enemies, ticks, seed_value, gen_ms])
	var samples: Dictionary = {}
	for s in SYSTEMS + ["total"]:
		samples[s] = []
	for i in ticks:
		var t := Time.get_ticks_usec()
		var p := t
		sim.tick += 1
		sim.crafting.tick()
		sim.needs.tick()
		sim.farming.tick()
		p = _lap(samples, "buildings", p)
		sim.colonists.tick()
		sim.perks.tick()
		sim.health.tick()
		sim.debt.tick()
		sim.mood.tick()
		p = _lap(samples, "colonists", p)
		sim.threats.tick()
		p = _lap(samples, "threats", p)
		sim.contamination.tick()
		p = _lap(samples, "contamination", p)
		sim.mutation.tick()
		p = _lap(samples, "mutation", p)
		sim.crises.tick()
		sim.storyteller.tick()
		p = _lap(samples, "storyteller", p)
		(samples["total"] as Array).append((p - t) / 1000.0)
		bus.tick_advanced.emit(sim.tick)
	for s in SYSTEMS + ["total"]:
		print("%-14s avg %.3f ms  p95 %.3f ms" % [s, _avg(samples[s]), _p95(samples[s])])
	print("%-14s (included in colonists)" % "jobs")
	print("%-14s (included in colonists/threats)" % "combat")
	print("alive enemies=%d colonists=%d" % [sim.threats.enemies.size(), sim.colonists.alive_count()])
	sim.dispose()
	bus.free()
	get_tree().quit(0)


func _run_view(seed_value: int, opts: Dictionary, n_enemies: int, frames: int) -> void:
	var game: Node = (load("res://view/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	game.new_game(seed_value, opts)
	var spawned := _spawn_enemies(game.sim, n_enemies)
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


## Spawns creatures on random reachable ground (sim.rng only) and keeps the wave "active"
## so they are neither culled nor joined by a new wave.
func _spawn_enemies(sim: Simulation, n: int) -> int:
	if n <= 0:
		return 0
	var ids: Array = sim.defs.enemies.keys()
	ids.sort()
	sim.threats.wave_active = true
	sim.threats.wave_end_tick = 1 << 30
	var center := sim.map_center()
	var count := 0
	var guard := n * 50
	while count < n and guard > 0:
		guard -= 1
		var c := Vector2i(sim.rng.randi_range(0, sim.map.width - 1), sim.rng.randi_range(0, sim.map.height - 1))
		var pick := sim.rng.randi_range(0, ids.size() - 1)
		if Vector2(c - center).length() < 12.0 or not sim.map.is_passable(c) \
				or not sim.pathfinder.reachable_terrain(c, center):
			continue
		sim.threats._spawn(str(ids[pick]), c)
		count += 1
	return count


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
