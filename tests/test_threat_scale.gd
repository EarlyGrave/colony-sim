extends TestCase
## Creatures at scale: shared flow fields, staggered re-targeting, spatial hash.


func _scene(w := 40, h := 40) -> Simulation:
	return make_sim(5, false, w, h, peaceful_defs())


func test_flow_step_reduces_distance_every_move() -> void:
	var sim := _scene()
	for y in range(5, 30):
		sim.pathfinder.set_blocked(Vector2i(20, y), true)  # a wall with gaps at both ends
	var f := sim.pathfinder.flow_to(1, [Vector2i(35, 20)] as Array[Vector2i])
	f.expand(-1)
	var walk := sim.pathfinder.walk_grid()
	var c := Vector2i(3, 20)
	var d := f.dist_at(c)
	assert_gt(d, 0, "start must be reached")
	var guard := 0
	while d > 0 and guard < 500:
		var n := f.next_step(c, walk)
		assert_true(n.x >= 0, "a step exists")
		assert_true(sim.pathfinder.is_walkable(n), "step is walkable")
		assert_lt(f.dist_at(n), d, "each step gets closer")
		c = n
		d = f.dist_at(c)
		guard += 1
	assert_eq(c, Vector2i(35, 20))


func test_retarget_is_staggered_once_per_period() -> void:
	var sim := _scene()
	sim.buildings.place("bed", Vector2i(20, 20), false)
	var n: int = int(sim.threats.cfg["retarget_ticks"])
	for i in n:
		sim.threats._spawn("crawler", Vector2i(2, 2 + i))
	sim.run_ticks(n)  # first choice for everyone
	var worst := 0
	var total0: int = sim.threats.retarget_count
	for t in n * 2:
		var before: int = sim.threats.retarget_count
		sim.run_ticks(1)
		worst = maxi(worst, sim.threats.retarget_count - before)
	assert_lt(worst, 3, "re-targets are spread over the period, not bursty")
	var per_enemy := float(sim.threats.retarget_count - total0) / float(n * 2)
	assert_near(per_enemy, 1.0, 0.1, "about one re-target per enemy per period")


func test_spatial_hash_matches_brute_force() -> void:
	var sim := _scene(60, 60)
	var h := SpatialHash.new(8)
	var all: Array[Enemy] = []
	for i in 150:
		var e := Enemy.new(i, "crawler", sim.defs.enemies["crawler"], Vector2i(sim.rng.randi_range(0, 59), sim.rng.randi_range(0, 59)))
		all.append(e)
		h.insert(e)
	for i in 50:  # some move
		var e := all[sim.rng.randi_range(0, all.size() - 1)]
		e.cell = Vector2i(sim.rng.randi_range(0, 59), sim.rng.randi_range(0, 59))
		h.update(e)
	for i in 40:
		var pos := Vector2(sim.rng.randf_range(-5, 65), sim.rng.randf_range(-5, 65))
		var r := sim.rng.randf_range(0.5, 20.0)
		var want: Array[int] = []
		for e in all:
			if Vector2(e.cell).distance_to(pos) <= r:
				want.append(e.id)
		var got: Array[int] = []
		for e: Enemy in h.query(pos, r):
			got.append(e.id)
		want.sort()
		got.sort()
		assert_eq(got, want, "query at %s r=%.1f" % [pos, r])


func test_flow_cache_invalidated_by_wall() -> void:
	var sim := _scene()
	var pf := sim.pathfinder
	pf.flow_to(7, [Vector2i(30, 20)] as Array[Vector2i])
	assert_true(pf.flow_cached(7) != null, "cached")
	var builds := pf.flow_builds
	pf.flow_to(7, [Vector2i(30, 20)] as Array[Vector2i])
	assert_eq(pf.flow_builds, builds, "second request is a cache hit")
	assert_true(sim.buildings.place("wall", Vector2i(15, 20), false) != null, "wall placed")
	assert_true(pf.flow_cached(7) == null, "wall placement drops the cache")
	var f := pf.flow_to(7, [Vector2i(30, 20)] as Array[Vector2i])
	f.expand(-1)
	assert_eq(f.dist_at(Vector2i(15, 20)), -1, "wall cell is not walkable in the new field")


func test_no_astar_for_creatures_in_steady_state() -> void:
	var sim := _scene()
	sim.buildings.place("bed", Vector2i(30, 30), false)
	for i in 30:
		sim.threats._spawn("crawler", Vector2i(2, 2 + i))
	sim.run_ticks(60)  # warm-up: fields get built
	var calls: int = sim.pathfinder.astar_calls
	sim.run_ticks(200)
	assert_eq(sim.pathfinder.astar_calls, calls, "no A* searches for creature movement")
	var moved := false
	for e in sim.threats.enemies:
		if e.cell.x > 3:
			moved = true
	assert_true(moved, "creatures are walking")


func test_creatures_route_around_a_new_wall() -> void:
	var sim := _scene()
	var bed := sim.buildings.place("bed", Vector2i(30, 20), false)
	for y in range(8, 33):
		sim.buildings.place("wall", Vector2i(15, y), false)
	var e := sim.threats._spawn("crawler", Vector2i(5, 20))
	sim.run_ticks(900)
	assert_true(e.cell.x > 15 or bed.hp < bed.max_hp or sim.buildings.at(Vector2i(30, 20)) == null, "went around or chewed through")


# region W1a
## Reference: the pre-cache algorithm (scan every candidate in index order, strict >, first max wins, stickiness).
func _brute_pick(m: ThreatModel, e: Enemy) -> Dictionary:
	m.refresh()
	var best := -1
	var best_s := 0.0
	var cur := -1
	var cur_s := -1.0
	for i in m._val.size():
		var s := m.score(i, e)
		if s <= 0.0:
			continue
		var ek := 0 if e.target_kind == Enemy.Target.BUILDING else (2 if e.target_kind == Enemy.Target.BELT else 1)
		if m._kind[i] == ek and m._id[i] == e.target_id and e.target_kind != Enemy.Target.NONE:
			cur = i
			cur_s = s
		if s > best_s:
			best_s = s
			best = i
	if best < 0:
		return {}
	if cur >= 0 and cur != best:
		var pr: Dictionary = m.cfg["pull_ratio"]
		var pull := float(pr["ranged"] if e.def.get("ranged", false) else pr["melee"])
		if cur_s >= float(m.cfg["stick"]) * best_s or best_s <= pull * cur_s:
			best = cur
	if m._kind[best] == 2:
		return {"kind": "belt", "id": m._id[best], "cell": m._ref[best]}
	return {"kind": "building" if m._kind[best] == 0 else "colonist", "id": m._id[best]}


func test_pick_matches_brute_force_with_belts_and_destruction() -> void:
	var sim := make_sim(11, false, 96, 96, peaceful_defs())
	sim.buildings.place("bed", Vector2i(48, 48), false)
	sim.buildings.place("refinery", Vector2i(60, 40), false)
	sim.colonists.spawn(Vector2i(30, 50))
	for y in range(6, 90, 3):
		var cells: Array = []
		for x in range(6, 90):
			cells.append(Vector2i(x, y))
		sim.place_belt(cells, 0)
	var kinds := ["crawler", "spitter", "brute", "burrower"]
	var mismatches := 0
	for round in 6:
		sim.tick += 10
		for k in 40:
			var e: Enemy = sim.threats._spawn(kinds[k % 4], Vector2i((k * 37 + round * 11) % 94 + 1, (k * 53 + round * 7) % 94 + 1))
			var got := sim.threats.model.pick(e)
			if got != _brute_pick(sim.threats.model, e):
				mismatches += 1
			if k % 3 == 0 and not got.is_empty():  # sticky current target on the next pick
				e.target_kind = Enemy.Target.BELT if got["kind"] == "belt" else (Enemy.Target.BUILDING if got["kind"] == "building" else Enemy.Target.COLONIST)
				e.target_id = int(got["id"])
				if got["kind"] == "belt":
					e.target_cell = got["cell"]
				if sim.threats.model.pick(e) != _brute_pick(sim.threats.model, e):
					mismatches += 1
		var cut: Array = []  # remove belts between rounds; candidates stay stale until the next belt rebuild
		for x in range(6, 90):
			cut.append(Vector2i(x, 6 + round * 12))
		sim.remove_belt(cut)
	assert_eq(mismatches, 0, "pick == brute force")
# endregion
