extends TestCase
## Y1: nitrogen vent nodes exist on the home map (guaranteed_nodes), deterministic, reachable from HQ.


func _gen(seed_value: int) -> MapGrid:
	var cfg: Dictionary = Defs.get_default().balance["map"].duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var map := MapGrid.new(int(cfg["width"]), int(cfg["height"]), make_bus())
	MapGenerator.generate(map, rng, cfg)
	return map


func _blobs(map: MapGrid, res: int) -> int:
	var seen := {}
	var n := 0
	for k in map.node_res.size():
		if int(map.node_res[k]) != res or seen.has(k):
			continue
		n += 1
		var st: Array[int] = [k]
		seen[k] = true
		while not st.is_empty():
			var q: int = st.pop_back()
			var c := Vector2i(q % map.width, q / map.width)
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var m: Vector2i = c + d
				if map.in_bounds(m) and int(map.node_res[map.idx(m)]) == res and not seen.has(map.idx(m)):
					seen[map.idx(m)] = true
					st.append(map.idx(m))
	return n


func test_nitrogen_nodes_per_seed() -> void:
	var nit := NodeData.res_index("nitrogen")
	for s in range(1, 6):
		var m := _gen(s)
		var b := _blobs(m, nit)
		assert_true(b >= 1 and b <= 2, "seed %d nitrogen nodes %d" % [s, b])
		assert_eq(_gen(s).node_res, m.node_res, "deterministic seed %d" % s)


func test_nitrogen_reachable_from_hq() -> void:
	var nit := NodeData.res_index("nitrogen")
	for s in range(1, 6):
		var m := _gen(s)
		var start := Vector2i(m.width / 2, m.height / 2)
		var seen := {m.idx(start): true}
		var st: Array[Vector2i] = [start]
		var ok := false
		while not st.is_empty() and not ok:
			var c: Vector2i = st.pop_back()
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + d
				if not m.in_bounds(n) or seen.has(m.idx(n)):
					continue
				seen[m.idx(n)] = true
				if int(m.node_res[m.idx(n)]) == nit:
					ok = true
				elif m.tiles[m.idx(n)] != MapGrid.Tile.ROCK:
					st.append(n)
		assert_true(ok, "nitrogen adjacent to walkable region seed %d" % s)
