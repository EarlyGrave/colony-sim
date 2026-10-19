class_name MapGenerator
extends RefCounted
## Seeded map generation: ground, rock clusters, essence deposits.
## Uses only the passed RNG, so the same seed always yields the same map.


static func generate(map: MapGrid, rng: RandomNumberGenerator, cfg: Dictionary) -> void:
	var w := map.width
	var h := map.height
	var center := Vector2i(w / 2, h / 2)
	var clear_r: int = int(cfg["clear_radius"])

	map.tiles.fill(MapGrid.Tile.GROUND)
	map.deposit_amount.fill(0)
	map.node_res.fill(0)  # region A1a
	map.node_purity.fill(0)

	# Rock clusters.
	var rs: Array = cfg["rock_cluster_size"]
	for i in int(cfg["rock_clusters"]):
		var start := Vector2i(rng.randi_range(0, w - 1), rng.randi_range(0, h - 1))
		for c in _blob(map, rng, start, rng.randi_range(int(rs[0]), int(rs[1]))):
			map.tiles[map.idx(c)] = MapGrid.Tile.ROCK

	# Essence deposits. The first cluster is placed near the start so the
	# colony always has something to mine.
	var ds: Array = cfg["deposit_cluster_size"]
	var biome := NodeData.biome(String(cfg.get("start_biome", "start")))  # region A1a
	map.biome_id = String(cfg.get("start_biome", "start"))
	var min_dist: int = int(cfg["min_deposit_distance"])
	for i in int(cfg["deposit_clusters"]):
		var start: Vector2i
		if i == 0:
			var angle := rng.randf() * TAU
			var dist := rng.randf_range(min_dist + 1, min_dist + 5)
			start = center + Vector2i(roundi(cos(angle) * dist), roundi(sin(angle) * dist))
		else:
			start = Vector2i(rng.randi_range(2, w - 3), rng.randi_range(2, h - 3))
			if Vector2(start - center).length() < min_dist:
				continue
		var rid := _pick_resource(rng, biome)  # region A1a
		for c in _blob(map, rng, start, rng.randi_range(int(ds[0]), int(ds[1]))):
			var k := map.idx(c)
			map.tiles[k] = MapGrid.Tile.DEPOSIT
			map.deposit_amount[k] = 0
			map.node_res[k] = rid
			map.node_purity[k] = _pick_purity(rng, biome)

	# Clear the landing area.
	for y in range(center.y - clear_r, center.y + clear_r + 1):
		for x in range(center.x - clear_r, center.x + clear_r + 1):
			var c := Vector2i(x, y)
			if map.in_bounds(c) and Vector2(c - center).length() <= clear_r + 0.5:
				map.tiles[map.idx(c)] = MapGrid.Tile.GROUND
				map.deposit_amount[map.idx(c)] = 0
				map.node_res[map.idx(c)] = 0  # region A1a
				map.node_purity[map.idx(c)] = 0

	_open_enclosed_pockets(map, center)
	_convert_extra_nodes(map, rng.seed, biome, cfg)  # region L5
	_guarantee_nodes(map, biome, cfg)  # region Y1


## Compact blob of up to `size` cells grown from `start` (each step extends
## from a random cell already in the blob).
static func _blob(map: MapGrid, rng: RandomNumberGenerator, start: Vector2i, size: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if not map.in_bounds(start):
		return cells
	var seen := {start: true}
	cells.append(start)
	var guard := size * 10
	while cells.size() < size and guard > 0:
		guard -= 1
		var n := cells[rng.randi_range(0, cells.size() - 1)] + MapGrid.NEIGHBORS_4[rng.randi_range(0, 3)]
		if map.in_bounds(n) and not seen.has(n):
			seen[n] = true
			cells.append(n)
	return cells


## Ground pockets unreachable from the landing site become rock so every
## open tile on the map is meaningful (and enemies never spawn sealed in).
static func _open_enclosed_pockets(map: MapGrid, center: Vector2i) -> void:
	var reach := PackedByteArray()
	reach.resize(map.width * map.height)
	reach.fill(0)
	var queue: Array[Vector2i] = [center]
	reach[map.idx(center)] = 1
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		for d in MapGrid.NEIGHBORS_4:
			var n := c + d
			if map.is_passable(n) and reach[map.idx(n)] == 0:
				reach[map.idx(n)] = 1
				queue.append(n)
	for i in map.tiles.size():
		if map.tiles[i] == MapGrid.Tile.GROUND and reach[i] == 0:
			map.tiles[i] = MapGrid.Tile.ROCK


# region A1a
## Weighted pick over the biome's resources (sorted ids, deterministic). Returns a resource byte.
static func _pick_resource(rng: RandomNumberGenerator, biome: Dictionary) -> int:
	var w: Dictionary = biome.get("resources", {"essence_ore": 1})
	var ids: Array = w.keys()
	ids.sort()
	var total := 0
	for k in ids:
		total += int(w[k])
	var r := rng.randi_range(0, maxi(0, total - 1))
	for k in ids:
		r -= int(w[k])
		if r < 0:
			return NodeData.res_index(String(k))
	return NodeData.res_index(String(ids[0]))


static func _pick_purity(rng: RandomNumberGenerator, biome: Dictionary) -> int:
	var w: Dictionary = biome.get("purity_weights", {"normal": 1})
	var total := 0
	for p in range(1, 4):
		total += int(w.get(NodeData.PURITY_IDS[p], 0))
	var r := rng.randi_range(0, maxi(0, total - 1))
	for p in range(1, 4):
		r -= int(w.get(NodeData.PURITY_IDS[p], 0))
		if r < 0:
			return p
	return 2
# endregion


# region L5
## Extra resources of a biome (`extra_resources`, e.g. coal on the start biome): converts a share of the
## non-first deposit cells that are not near the start. Uses its OWN generator seeded from the map seed and
## never touches `rng`; only node_res changes (tiles identical), so existing map hashes stay identical.
## Share comes from cfg `extra_share` (0 = off).
static func _convert_extra_nodes(map: MapGrid, seed_value: int, biome: Dictionary, cfg: Dictionary) -> void:
	var share := float(cfg.get("extra_share", 0.0))
	var extra: Dictionary = biome.get("extra_resources", {})
	if share <= 0.0 or extra.is_empty():
		return
	var ids: Array = extra.keys()
	ids.sort()
	var r2 := RandomNumberGenerator.new()
	r2.seed = seed_value ^ 0x5C0A1
	var center := Vector2i(map.width / 2, map.height / 2)
	var min_d := float(cfg.get("extra_min_distance", int(cfg.get("min_deposit_distance", 7)) + 6))  # region LX: keeps the near ore essence
	var done := {}
	for k in map.node_res.size():
		if map.tiles[k] != MapGrid.Tile.DEPOSIT or map.node_res[k] == 0 or done.has(k):
			continue
		var c := Vector2i(k % map.width, k / map.width)
		if Vector2(c - center).length() < min_d:
			continue
		# one roll per blob (flood fill of the same resource), so coal comes as a cluster and the share is per cluster
		var rid := int(map.node_res[k])
		var blob: Array[int] = []
		var stack: Array[int] = [k]
		var seen := {k: true}
		while not stack.is_empty():
			var q: int = stack.pop_back()
			blob.append(q)
			var qc := Vector2i(q % map.width, q / map.width)
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = qc + d
				if map.in_bounds(n):
					var ni := map.idx(n)
					if not seen.has(ni) and map.tiles[ni] == MapGrid.Tile.DEPOSIT and int(map.node_res[ni]) == rid:
						seen[ni] = true
						stack.append(ni)
		var near := false
		for q in blob:
			done[q] = true
			if Vector2(Vector2i(q % map.width, q / map.width) - center).length() < min_d:
				near = true
		if near or r2.randf() >= share:
			continue
		var coal := NodeData.res_index(String(ids[r2.randi_range(0, ids.size() - 1)]))
		for q in blob:
			map.node_res[q] = coal
# endregion


# region Y1
## Biome `guaranteed_nodes` ({resource: count}): converts the farthest not-near-start deposit blobs (not coal, not
## already guaranteed) so e.g. nitrogen exists on the home map. No rng use; only node_res changes.
static func _guarantee_nodes(map: MapGrid, biome: Dictionary, cfg: Dictionary) -> void:
	var want: Dictionary = biome.get("guaranteed_nodes", {})
	if want.is_empty():
		return
	var center := Vector2i(map.width / 2, map.height / 2)
	var min_d := float(cfg.get("extra_min_distance", int(cfg.get("min_deposit_distance", 7)) + 6))
	var coal := NodeData.res_index("coal")
	var blobs: Array = []  # [dist, first_cell, cells]
	var done := {}
	for k in map.node_res.size():
		if map.tiles[k] != MapGrid.Tile.DEPOSIT or map.node_res[k] == 0 or done.has(k):
			continue
		var rid := int(map.node_res[k])
		var cells: Array[int] = []
		var stack: Array[int] = [k]
		var seen := {k: true}
		var dmin := 1.0e9
		while not stack.is_empty():
			var q: int = stack.pop_back()
			cells.append(q)
			done[q] = true
			var qc := Vector2i(q % map.width, q / map.width)
			dmin = minf(dmin, Vector2(qc - center).length())
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = qc + d
				if map.in_bounds(n):
					var ni := map.idx(n)
					if not seen.has(ni) and map.tiles[ni] == MapGrid.Tile.DEPOSIT and int(map.node_res[ni]) == rid:
						seen[ni] = true
						stack.append(ni)
		if dmin >= min_d and rid != coal:
			blobs.append([dmin, k, cells, rid])
	var ess := NodeData.res_index("essence_ore")
	var cnt := {}  # blobs per resource
	for b in blobs:
		cnt[int(b[3])] = int(cnt.get(int(b[3]), 0)) + 1
	var ids: Array = want.keys()
	ids.sort()
	var wi := {}  # resource index -> guaranteed count: a blob is never taken once it is down to that count
	for id in ids:
		wi[NodeData.res_index(String(id))] = int(want[id])
	for id in ids:
		var res := NodeData.res_index(String(id))
		var n: int = int(want[id]) - int(cnt.get(res, 0))
		while n > 0:
			# YX: spare the LAST blob of iron/copper (and keep 2 essence blobs): pass 0 only takes from resources with spare
			# blobs, pass 1 (nothing spare) falls back to any blob. Iron/copper first, then farthest from HQ.
			var best := -1
			for pass_i in 2:
				for k in blobs.size():
					var b: Array = blobs[k]
					var r: int = int(b[3])
					if r == res or (wi.has(r) and int(cnt[r]) <= int(wi[r])) or (r == ess and int(cnt[r]) <= 2):
						continue  # essence keeps 2 far blobs for the start chains
					if pass_i == 0 and int(cnt[r]) < 2:
						continue
					if best < 0:
						best = k
						continue
					var o: Array = blobs[best]
					var eb: int = 1 if r == ess else 0
					var eo: int = 1 if int(o[3]) == ess else 0
					if eb != eo:
						if eb < eo:
							best = k
					elif int(cnt[r]) != int(cnt[int(o[3])]):
						if int(cnt[r]) > int(cnt[int(o[3])]):
							best = k
					elif b[0] > o[0] or (b[0] == o[0] and b[1] < o[1]):
						best = k
				if best >= 0:
					break
			if best < 0:
				break
			var pick: Array = blobs[best]
			for q in pick[2]:
				map.node_res[q] = res
			cnt[int(pick[3])] = int(cnt[int(pick[3])]) - 1
			cnt[res] = int(cnt.get(res, 0)) + 1
			blobs[best][3] = res
			n -= 1
# endregion
