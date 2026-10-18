extends TestCase


func _host() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.current_scene if tree.current_scene != null else tree.root.get_child(tree.root.get_child_count() - 1)


func test_chunk_mapping() -> void:
	assert_eq(ChunkLayer.chunk_of(Vector2i(0, 0)), Vector2i(0, 0))
	assert_eq(ChunkLayer.chunk_of(Vector2i(31, 31)), Vector2i(0, 0))
	assert_eq(ChunkLayer.chunk_of(Vector2i(32, 63)), Vector2i(1, 1))
	assert_eq(ChunkLayer.chunk_count(250), 8)
	assert_eq(ChunkLayer.chunk_cells(Vector2i(7, 7), 250, 250), Rect2i(224, 224, 26, 26))
	# no chunk texture is wider than one chunk
	assert_lt(ChunkLayer.CHUNK * ChunkLayer.PX, 513)


func test_dirty_set_at_border() -> void:
	assert_eq(ChunkLayer.chunks_for_change(Vector2i(10, 10), 64, 64).size(), 1)
	# bottom row of chunk (0,0): shading of the row below dirties chunk (0,1) too
	var a := ChunkLayer.chunks_for_change(Vector2i(10, 31), 64, 64)
	assert_eq(a.size(), 2)
	assert_true(a.has(Vector2i(0, 0)) and a.has(Vector2i(0, 1)))
	# top row of chunk (0,1) marks (0,0) as well
	var b := ChunkLayer.chunks_for_change(Vector2i(10, 32), 64, 64)
	assert_true(b.has(Vector2i(0, 0)) and b.has(Vector2i(0, 1)))
	# map edge never yields out-of-range chunks
	assert_eq(ChunkLayer.chunks_for_change(Vector2i(0, 0), 64, 64).size(), 1)


func test_culling_predicate() -> void:
	var r := Rect2(10, 10, 20, 12)
	assert_true(ChunkLayer.cell_visible(Vector2(15, 15), r, 3.0))
	assert_true(ChunkLayer.cell_visible(Vector2(8, 10), r, 3.0))
	assert_false(ChunkLayer.cell_visible(Vector2(200, 200), r, 3.0))
	assert_false(ChunkLayer.cell_visible(Vector2(5, 15), r, 3.0))
	var ch := ChunkLayer.chunks_in_rect(Rect2(10, 10, 20, 12), 250, 250)
	assert_eq(ch.size(), 1)
	assert_eq(ChunkLayer.chunks_in_rect(Rect2(-50, -50, 1000, 1000), 250, 250).size(), 64)


func test_single_tile_touches_one_chunk() -> void:
	var sim := make_sim(3)
	var wv := WorldView.new()
	_host().add_child(wv)
	_owned_nodes.append(wv)
	wv.flat = true
	wv.bind(sim)
	var before := wv.chunk_updates
	sim.bus.tile_changed.emit(Vector2i(10, 10))
	assert_eq(wv.chunk_updates - before, 1)
	before = wv.chunk_updates
	sim.bus.tile_changed.emit(Vector2i(10, 31))
	assert_eq(wv.chunk_updates - before, 2)
	wv.unbind()


func test_block_chunks_cover_solid_tiles_once() -> void:
	var sim := make_sim(5)
	var w3 := WorldView3D.new()
	_host().add_child(w3)
	_owned_nodes.append(w3)
	w3.bind(sim, World2D.new())
	var expect := 0
	for y in sim.map.height:
		for x in sim.map.width:
			var t := sim.map.get_tile(Vector2i(x, y))
			if t == MapGrid.Tile.ROCK or t == MapGrid.Tile.DEPOSIT:
				expect += 1
	for b: Building in sim.buildings.list:
		if b.def_id == "wall":
			expect += 1
	w3._process(0.016)
	assert_eq(w3.block_instance_total(), expect)
	assert_eq(w3.block_rebuilds, w3.chunks.viewports.size())
	# a tile edit rebuilds only its chunk
	var before := w3.block_rebuilds
	sim.bus.tile_changed.emit(Vector2i(10, 10))
	w3._process(0.016)
	assert_eq(w3.block_rebuilds - before, 1)
	w3.unbind()
