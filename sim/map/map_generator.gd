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
