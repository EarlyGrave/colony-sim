extends RefCounted
## Shared scenario builders for balance tests and tools/balance_report.gd.
## A "standard colony" is what a sensible player sets up in the first minutes:
## refinery next to the capsule, a waste dump, mining designated nearby.


static func standard_colony(sim: Simulation, turrets: int) -> void:
	var center := sim.map_center()
	var ref := find_spot(sim, "refinery", center, 3)
	sim.buildings.place("refinery", ref, false)
	var dump := find_zone_spot(sim, center + Vector2i(-6, 0), Vector2i(3, 3))
	for y in 3:
		for x in 3:
			sim.set_zone(dump + Vector2i(x, y), "waste_dump")
	designate_nearest_deposits(sim, 10)
	# region needs
	# A sensible player also sleeps and eats: beds and a food reserve (the
	# farming loop has its own tests, here it would only steal labour).
	for i in 3:
		sim.buildings.place("bed", find_spot(sim, "bed", center + Vector2i(-3 + i, 8), 0), false)
	var food_at := center + Vector2i(3, -1)
	sim.ledger.record_produced("raw_food", 100, "test")
	sim.items.drop(food_at, "raw_food", 100)
	# endregion
	# Turrets in a ring around the capsule and refinery.
	for i in turrets:
		var angle := TAU * i / maxi(turrets, 1)
		var want := center + Vector2i(roundi(cos(angle) * 4.0), roundi(sin(angle) * 4.0))
		var spot := find_spot(sim, "turret", want, 0)
		sim.buildings.place("turret", spot, false)


## Nearest valid placement to `near`, at least `min_dist` cells away.
static func find_spot(sim: Simulation, def_id: String, near: Vector2i, min_dist: int) -> Vector2i:
	for r in range(0, 20):
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if maxi(absi(x), absi(y)) != r:
					continue
				var c := near + Vector2i(x, y)
				if Vector2(c - near).length() < min_dist:
					continue
				if sim.buildings.placement_error(def_id, c, false) == "":
					return c
	return near


static func find_zone_spot(sim: Simulation, near: Vector2i, size: Vector2i) -> Vector2i:
	for r in range(0, 20):
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				var o := near + Vector2i(x, y)
				var ok := true
				for yy in size.y:
					for xx in size.x:
						var c := o + Vector2i(xx, yy)
						if not sim.map.is_passable(c) or sim.buildings.occupied(c) or sim.map.get_zone(c) != "" or sim.items.stacks.has(c):
							ok = false
				if ok:
					return o
	return near


static func _purity_rank(sim: Simulation, c: Vector2i) -> int:
	if not sim.map.is_node(c):
		return 1
	return NodeData.PURITY_IDS.find(sim.map.node_purity_id(c))


## Designates the `n` nearest ESSENCE nodes (the refinery's input). The
## designation stays on infinite nodes, so colonists keep mining them.
## Falls back to legacy finite deposits when the map has no essence node.
static func designate_nearest_deposits(sim: Simulation, n: int) -> void:
	var center := sim.map_center()
	var cells: Array[Vector2i] = []
	for y in sim.map.height:
		for x in sim.map.width:
			var c := Vector2i(x, y)
			if not sim.map.is_deposit(c) or not sim.map.is_adjacent_to_passable(c):
				continue
			if sim.map.is_node(c) and sim.map.node_resource(c) != "essence_ore":
				continue
			cells.append(c)
	# A sensible player takes the purest nodes (yield x0.5 / x1 / x2) near the capsule.
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_squared_to(center) < b.distance_squared_to(center))
	var near_cells := cells.slice(0, mini(cells.size(), n * 2))
	near_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var pa := _purity_rank(sim, a)
		var pb := _purity_rank(sim, b)
		if pa != pb:
			return pa > pb
		return a.distance_squared_to(center) < b.distance_squared_to(center))
	cells.assign(near_cells)
	for i in mini(n, cells.size()):
		sim.designate_mine(cells[i], true)


## Runs until game over or `max_waves` waves have ended. Returns a summary.
## `intervene`: emulate an attentive player who, after every wave, rebuilds
## lost turrets and adds one more (paying the real cost from storage).
static func run_waves(sim: Simulation, max_waves: int, intervene := false, max_ticks := 60000) -> Dictionary:
	var log: Array = []
	var built := [0]
	if intervene:
		var base := sim.buildings.count_of("turret")
		var player_rng := RandomNumberGenerator.new()
		player_rng.seed = sim.seed_value
		sim.bus.wave_ended.connect(func(i: int) -> void:
			var want := base + i
			while sim.buildings.count_of("turret") < want:
				var angle := player_rng.randf() * TAU
				var near := sim.map_center() + Vector2i(roundi(cos(angle) * 5.0), roundi(sin(angle) * 5.0))
				var spot := find_spot(sim, "turret", near, 0)
				if sim.place_instant("turret", spot) == null:
					break
				built[0] += 1)
	var broken := [0]
	sim.bus.building_broken.connect(func(_id: int) -> void: broken[0] += 1)
	sim.bus.wave_started.connect(func(i: int, s: float) -> void:
		log.append({"wave": i, "strength": s, "enemies": sim.threats.enemies.size()}))
	sim.bus.wave_ended.connect(func(i: int) -> void:
		var hq := 0.0
		for b in sim.buildings.list:
			if b.def_id == "hq":
				hq = b.hp
		log[-1]["hq_hp"] = hq
		log[-1]["refineries"] = sim.buildings.count_of("refinery")
		log[-1]["turrets"] = sim.buildings.count_of("turret")
		log[-1]["colonists"] = sim.colonists.alive_count()
		log[-1]["kills"] = sim.threats.kills)
	var guard := 0
	while sim.game_over_reason == "" and guard < max_ticks:
		sim.step()
		guard += 1
		if sim.threats.wave_index >= max_waves and not sim.threats.wave_active:
			break
	return {
		"game_over": sim.game_over_reason,
		"died_on_wave": sim.threats.wave_index if sim.game_over_reason != "" else 0,
		"waves": sim.threats.wave_index,
		"ticks": sim.tick,
		"breakdowns": broken[0],
		"turrets_built": built[0],
		"log": log,
		"batches": sim.buildings.refined_batches,
		"contamination": sim.contamination.level,
	}


## Automation chain on an essence node near the capsule: miner -> 4 belts ->
## smelter -> 4 belts -> storage_in, all on one row. Belts go in through
## Simulation.place_belt. `blueprints`: miner/smelter via place_building
## (colonists haul and build) instead of instant placement. `force_normal` sets the
## node purity to "normal". Returns {miner, smelter, store} (blueprint mode: the
## store only) or {} when nothing fits.
static func build_chain(sim: Simulation, blueprints := false, force_normal := false) -> Dictionary:
	var center := sim.map_center()
	var nodes: Array[Vector2i] = []
	for c in sim.map.node_cells():
		if sim.map.node_resource(c) == "essence_ore":
			nodes.append(c)
	nodes.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_squared_to(center) < b.distance_squared_to(center))
	for n in nodes:
		for t: Vector2i in [n, n + Vector2i(-1, 0), n + Vector2i(0, -1), n + Vector2i(-1, -1)]:
			var r := _try_chain(sim, t, blueprints, force_normal)
			if not r.is_empty():
				return r
	return {}


static func _try_chain(sim: Simulation, t: Vector2i, blueprints: bool, force_normal: bool) -> Dictionary:
	var s := t + Vector2i(6, 0)
	var st := t + Vector2i(12, 0)
	if sim.buildings.placement_error("miner", t, false) != "" or sim.buildings.placement_error("smelter", s, false) != "" \
			or sim.buildings.placement_error("storage_in", st, false) != "":
		return {}
	var cells: Array = []
	for x in range(t.x + 2, t.x + 6):
		cells.append(Vector2i(x, t.y))
	for x in range(t.x + 8, t.x + 12):
		cells.append(Vector2i(x, t.y))
	for c: Vector2i in cells:
		if sim.can_belt_cell_error(c) != "":
			return {}
	if force_normal:
		for y in 2:
			for x in 2:
				if sim.map.is_node(t + Vector2i(x, y)):
					sim.map.node_purity[sim.map.idx(t + Vector2i(x, y))] = 2
	var out := {}
	if blueprints:
		if sim.place_building("miner", t) == null or sim.place_building("smelter", s) == null:
			return {}
	else:
		out["miner"] = sim.buildings.place("miner", t, false)
		out["smelter"] = sim.buildings.place("smelter", s, false)
	if blueprints:
		if sim.place_building("storage_in", st) == null:
			return {}
	else:
		out["store"] = sim.buildings.place("storage_in", st, false)
	sim.place_belt(cells.slice(0, 4), 1)
	sim.place_belt(cells.slice(4, 8), 1)
	return out
