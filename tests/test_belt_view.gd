extends TestCase
## Belt layer batching (MultiMesh per chunk) and A2c building models.


func _layer(sim: Simulation) -> BeltLayer:
	var l := BeltLayer.new()
	l.bind(sim)
	return l


func _fill_belts(sim: Simulation, n: int) -> void:
	var g := sim.logistics.belts
	var placed := 0
	for y in range(0, g.height, 2):
		for x in g.width:
			if placed >= n:
				return
			if g.set_belt(Vector2i(x, y), 1):
				placed += 1


func test_2000_belts_at_most_one_belt_multimesh_per_chunk() -> void:
	var sim := make_sim(1, false, 250, 250)
	_fill_belts(sim, 2000)
	var l := _layer(sim)
	var all: Array[Vector2i] = []
	for cy in l.rows:
		for cx in l.cols:
			all.append(Vector2i(cx, cy))
	l.sync(0.1, Color.WHITE, all)
	assert_eq(l.belt_instance_total(), 2000)
	var with_belts := 0
	for m in l.belt_mms:
		if m.multimesh.instance_count > 0:
			with_belts += 1
	assert_true(with_belts <= l.cols * l.rows, "one belt MultiMesh per chunk")
	assert_true(l.draw_calls() <= l.cols * l.rows, "no items yet: <= 1 draw call per chunk")
	l.free()


func test_items_are_instances_and_follow_belts() -> void:
	var sim := make_sim(1, false, 40, 40)
	for x in 5:
		sim.logistics.belts.set_belt(Vector2i(x, 3), 1)
	sim.logistics.insert_item(Vector2i(0, 3), "essence_ore")
	var l := _layer(sim)
	l.sync(0.1, Color.WHITE, [Vector2i(0, 0)] as Array[Vector2i])
	assert_eq(l.item_instance_total(), 1)
	var g := sim.logistics.belts
	var p0 := BeltLayer.item_position(Vector2i(0, 3), 1, g.progress[3 * g.width], g.ticks_per_cell)
	var p1 := BeltLayer.item_position(Vector2i(1, 3), 1, 2, g.ticks_per_cell)
	assert_gt(p1.x, p0.x)
	assert_eq(p1.z, p0.z)
	for i in 12:
		sim.logistics.tick()
	l.sync(0.1, Color.WHITE, [Vector2i(0, 0)] as Array[Vector2i])
	assert_eq(l.item_instance_total(), 1, "item still on a belt")
	l.free()


func test_belt_change_rebuilds_only_its_chunk() -> void:
	var sim := make_sim(1, false, 80, 80)
	var l := _layer(sim)
	var all: Array[Vector2i] = [Vector2i(0, 0), Vector2i(2, 2)]
	l.sync(0.1, Color.WHITE, all)
	var before := l.rebuilds
	sim.logistics.belts.set_belt(Vector2i(70, 70), 2)
	l.sync(0.1, Color.WHITE, all)
	assert_eq(l.rebuilds - before, 1)
	l.sync(0.1, Color.WHITE, all)
	assert_eq(l.rebuilds - before, 1, "no rebuild when unchanged")
	l.free()


func test_port_arrows_follow_dirs() -> void:
	assert_eq(Building3D.port_arrow_dir(1, "out"), 1)
	assert_eq(Building3D.port_arrow_dir(3, "in"), 1)
	assert_eq(Building3D.arrow_rotation(1), 0.0)
	assert_eq(Building3D.arrow_rotation(2), -PI / 2)


func test_machines_have_3d_models() -> void:
	for id in ["miner", "smelter", "assembler", "storage_in", "storage_out"]:
		assert_true(Building3D.is_3d(id), id)
		assert_true(Building3D.TOP_ART.has(id), id)
