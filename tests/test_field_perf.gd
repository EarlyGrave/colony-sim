extends TestCase
## Time-sliced contamination field and the single-texture overlay (batch P1/P2).


func _defs(slice_cells: int) -> Defs:
	var d := peaceful_defs()
	d.balance["field_perf"]["slice_cells"] = slice_cells
	return d


func _big(seed_value: int, w: int, h: int, slice_cells := 4096) -> Simulation:
	var sim := make_sim(seed_value, false, w, h, _defs(slice_cells))
	sim.contamination.level = 30.0
	sim.items.add_at(Vector2i(20, 20), "waste", 60)
	sim.items.add_at(Vector2i(w - 10, h - 12), "waste", 30)
	return sim


func test_small_map_is_not_sliced() -> void:
	var sim := make_sim(1, false, 64, 64, peaceful_defs())
	assert_eq(sim.mutation.slices, 1)
	var big := make_sim(1, false, 250, 250, peaceful_defs())
	assert_gt(big.mutation.slices, 1)


func test_field_hash_deterministic_250() -> void:
	var hashes: Array[int] = []
	for i in 2:
		var sim := _big(5, 250, 250)
		sim.run_ticks(500)
		hashes.append(hash(sim.mutation.field))
	assert_eq(hashes[0], hashes[1])
	assert_true(hashes[0] != hash(PackedFloat32Array()), "field not trivially empty")


func test_sliced_converges_to_full_update() -> void:
	var full := _big(7, 96, 96, 1000000)
	var sliced := _big(7, 96, 96, 3000)
	assert_eq(full.mutation.slices, 1)
	assert_gt(sliced.mutation.slices, 1)
	full.run_ticks(4000)
	sliced.run_ticks(4000)
	var mf: float = full.mutation.mean()
	var ms: float = sliced.mutation.mean()
	assert_gt(mf, 0.0)
	assert_lt(absf(mf - ms), mf * 0.15, "means agree")
	var a := Vector2i(20, 20)
	assert_lt(absf(full.mutation.value_at(a) - sliced.mutation.value_at(a)), maxf(full.mutation.value_at(a) * 0.25, 0.02), "hot spot agrees")


func test_overlay_matches_field() -> void:
	var sim := _big(3, 100, 100, 3000)
	sim.run_ticks(1200)
	var wv := WorldView.new()
	wv.sim = sim
	var tex := wv.update_field_texture()  # first call refreshes every row
	var img := tex.get_image()
	assert_eq(img.get_width(), 100)
	assert_eq(img.get_height(), 100)
	var mut := sim.mutation
	var cells: Array[Vector2i] = [Vector2i(20, 20), Vector2i(21, 20), Vector2i(90, 90)]
	for c in cells:
		var v := mut.value_at(c)
		var col := img.get_pixel(c.x, c.y)
		var expect := wv._field_color(v, mut.tainted_threshold(), mut.mutated_threshold())
		assert_lt(absf(col.a - expect.a), 0.01, "alpha at %s" % c)
	assert_gt(img.get_pixel(20, 20).a, 0.0)
	# A later frame with nothing dirty writes no pixels.
	var before := wv.field_pixel_writes
	wv.update_field_texture()
	assert_eq(wv.field_pixel_writes, before)
	# Row budget: a frame never visits more than overlay_rows_per_frame dirty rows.
	sim.mutation.dirty_rows.fill(1)
	wv.update_field_texture()
	var left := 0
	for v in sim.mutation.dirty_rows:
		left += v
	assert_eq(left, 100 - int(sim.defs.balance["field_perf"]["overlay_rows_per_frame"]))
	wv.free()


func test_purify_during_cycle_keeps_edit() -> void:
	var sim := _big(4, 100, 100, 3000)
	sim.run_ticks(41)
	sim.mutation.add_at(Vector2i(5, 5), 1.0)
	assert_gt(sim.mutation.value_at(Vector2i(5, 5)), 0.9)
	sim.run_ticks(60)
	assert_gt(sim.mutation.value_at(Vector2i(5, 5)), 0.3, "edit survives buffer swaps")
