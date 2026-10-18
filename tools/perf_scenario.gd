extends RefCounted
## Shared perf scenario (tools/perf_bench.gd + tests/test_perf_budget.gd): §3 of docs/optimization_strategy.md.
## Deterministic: placement uses sim.rng only. Enemies are harmless (damage_mult 0) so colonists stay alive
## and the jobs system is measured under load.

const TOP_BUDGET_KEYS: Array[String] = ["threats", "logistics", "colonists", "contamination", "mutation", "total"]


## Adds colonists up to `n` next to the HQ.
static func fill_colonists(sim: Simulation, n: int) -> void:
	var c := sim.map_center()
	var i := 0
	while sim.colonists.list.size() < n and i < 200:
		var cell := c + Vector2i(-4 + i % 9, 5 + i / 9)
		if sim.map.is_passable(cell) and not sim.buildings.occupied(cell):
			sim.colonists.spawn(cell)
		i += 1


## Lays belts on passable free ground in horizontal runs (alternating direction) until `n` exist.
static func lay_belts(sim: Simulation, n: int) -> int:
	var placed := 0
	var y := 4
	while placed < n and y < sim.map.height - 4:
		var d := 0 if (y / 2) % 2 == 0 else 2
		for x in range(4, sim.map.width - 4):
			if placed >= n:
				break
			var cell := Vector2i(x, y)
			if sim.cell_free_for_items(cell) and sim.logistics.place_belt_cell(cell, d):
				placed += 1
		y += 2
	return placed


## Spawns n harmless creatures on random reachable ground (sim.rng only) and keeps the wave "active".
static func spawn_enemies(sim: Simulation, n: int) -> int:
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
		sim.threats._spawn(str(ids[pick]), c).damage_mult = 0.0
		count += 1
	return count


## Runs `ticks` real steps with profiling on; returns {system: Array[ms]} plus "total", "first_tick_ms", "flow_builds".
static func measure(sim: Simulation, ticks: int) -> Dictionary:
	var samples: Dictionary = {}
	sim.profiling = true
	var fb0: int = sim.pathfinder.flow_builds
	for i in ticks:
		sim.profile.clear()
		var t := Time.get_ticks_usec()
		sim.step()
		var dt := (Time.get_ticks_usec() - t) / 1000.0
		if i == 0:
			samples["first_tick_ms"] = dt
		for k in sim.profile:
			if not samples.has(k):
				samples[k] = []
			(samples[k] as Array).append(sim.profile[k] / 1000.0)
		if not samples.has("total"):
			samples["total"] = []
		(samples["total"] as Array).append(dt)
	sim.profiling = false
	samples["flow_builds"] = sim.pathfinder.flow_builds - fb0
	return samples


static func avg(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for v in a:
		s += v
	return s / a.size()


static func p95(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var b: Array = a.duplicate()
	b.sort()
	return b[mini(b.size() - 1, int(b.size() * 0.95))]
