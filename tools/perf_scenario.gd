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


# region F10W2
## Late-game load (F10): metro drone raid active, inmates fully equipped (6 slots, rare+ affixes, sockets, spare loot in
## their packs), 2 r4/q14 quests active, petition alt available, gear wear ON. Deterministic (sim.rng only).
## Use `late_sim()` so wear is switched on in a defs COPY (shared Defs stay untouched).
const LATE_LOADOUT: Array = [["plasma_blade", "ap_rounds"], ["kevlar_vest", "kevlar_plate"], ["helmet", ""], ["work_gloves", ""], ["greaves", ""], ["underlay", ""]]
const LATE_BUCKETS: Array[String] = ["threats", "colonists", "contamination", "logistics", "mutation", "combat", "total"]
const LATE_SPARE: Array = ["smg", "helmet", "greaves", "work_gloves"]
const LATE_QUESTS: Array = ["r4_good_behaviour", "q14_three_forms"]


static func late_defs() -> Defs:
	var defs := Defs.get_default().duplicate_defs()
	defs.equipment["durability"]["wear_enabled"] = true
	return defs


static func late_sim(seed_value: int, bus: Node, opts := {}) -> Simulation:
	var o := {"map_w": 250, "map_h": 250}
	o.merge(opts, true)
	var sim := Simulation.new(seed_value, bus, late_defs(), o)
	sim.start_new_game()
	return sim


## Fills `sim` (from late_sim) with the late-game load; returns counts for sanity asserts.
static func late_game(sim: Simulation, opts := {}) -> Dictionary:
	var inmates := int(opts.get("inmates", 10))
	fill_colonists(sim, maxi(12, inmates))
	var gear := 0
	var rarities: Array = ["rare", "epic", "legendary"]
	var n := 0
	for c in sim.colonists.list:
		c.max_hp = 1.0e6  # raids must not thin the sample out
		c.hp = 1.0e6
		if n >= inmates:
			continue
		for slot in LATE_LOADOUT:
			var gid := sim.give_gear(c.id, slot[0], rarities[(n + gear) % 3], 12)
			if gid < 0:
				continue
			gear += 1
			if slot[1] != "":
				sim.defs.upgrades[slot[1]]["cost"] = {}
				sim.socket(gid, slot[1])
			sim.equip(c.id, gid)
		for base in LATE_SPARE:  # loot picked up and carried, not worn
			if sim.give_gear(c.id, base, "rare", 8) >= 0:
				gear += 1
		n += 1
	# petition alt: terminal + tier 2 + volunteers + site
	sim.buildings.place("warden_terminal", sim.map_center() + Vector2i(6, -6), false)
	if not sim.milestones.is_tier_done(2):
		sim.milestones.done_tiers.append(2)
	var quests := 0
	for q in LATE_QUESTS:
		if sim.quests.start(q):
			quests += 1
	# a drone raid in progress
	sim.threats.awakened = true
	sim.threats.metro().defiance = 60.0
	var rid: String = sim.threats.metro().pick_raid()
	if rid != "":
		sim.threats.set_meta("metro_points", sim.threats.metro().points())
		sim.threats.force_raid_id = rid
		sim.threats.start_wave()
		sim.threats.force_raid_id = ""
		sim.threats.remove_meta("metro_points")
	spawn_enemies(sim, int(opts.get("enemies", 60)))  # harmless creatures roaming; also keeps the wave open
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0)]
	var contact := 0
	for i in mini(inmates, sim.colonists.list.size()):  # a few in melee contact so the combat bucket is exercised
		var cell: Vector2i = sim.colonists.list[i].cell + dirs[i % 2]
		if sim.map.is_passable(cell) and not sim.buildings.occupied(cell):
			var e := sim.threats._spawn("crawler", cell)
			e.damage_mult = 0.0
			e.hp = 1.0e9
			e.max_hp = 1.0e9
			contact += 1
	return {"gear": gear, "quests": quests, "raid": rid, "enemies": sim.threats.enemies.size(), "contact": contact,
		"alt": sim.petition.alt_available(sim.petition.next_phase()), "inmates": n}
# endregion
