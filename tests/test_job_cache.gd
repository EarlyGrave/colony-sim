extends TestCase


func _brute(m: MapGrid) -> Array[int]:
	var out: Array[int] = []
	for i in m.mine_designated.size():
		if m.mine_designated[i] != 0:
			out.append(i)
	return out


func _same(m: MapGrid) -> bool:
	var a := m.mine_indices()
	var b := _brute(m)
	if a.size() != b.size():
		return false
	for k in a.size():
		if a[k] != b[k]:
			return false
	return true


func test_mine_cache_matches_brute_force_after_changes() -> void:
	var sim := make_sim(5)
	var m := sim.map
	var deposits: Array[Vector2i] = []
	for i in m.tiles.size():
		if m.tiles[i] == MapGrid.Tile.DEPOSIT:
			deposits.append(Vector2i(i % m.width, i / m.width))
	assert_gt(deposits.size(), 6, "need deposits")
	for k in 6:
		var c := deposits[sim.rng.randi_range(0, deposits.size() - 1)]
		m.set_mine_designated(c, true)
		assert_true(_same(m), "after add")
	# Remove one (cache invalidated on removal).
	var first := Vector2i(m.mine_indices()[0] % m.width, m.mine_indices()[0] / m.width)
	m.set_mine_designated(first, false)
	assert_true(_same(m), "after remove")
	# Tile turned to ground clears the designation and the cache.
	var second := Vector2i(m.mine_indices()[0] % m.width, m.mine_indices()[0] / m.width)
	m.set_tile(second, MapGrid.Tile.GROUND)
	assert_true(_same(m), "after set_tile")
