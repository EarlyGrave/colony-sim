extends TestCase


func _make_cam() -> CameraController:
	var tree := Engine.get_main_loop() as SceneTree
	var host: Node = tree.current_scene if tree.current_scene != null else tree.root.get_child(tree.root.get_child_count() - 1)
	var vp := SubViewport.new()
	vp.size = Vector2i(800, 600)
	host.add_child(vp)
	_owned_nodes.append(vp)
	var cam := CameraController.new()
	vp.add_child(cam)
	cam.world_size = Vector2(2048, 2048)
	cam.focus = Vector2(1024, 1024)
	return cam


func test_round_trip_screen_world() -> void:
	var cam := _make_cam()
	for z in [0.5, 1.0, 2.5]:
		cam.zoom_level = z
		for sp: Vector2 in [Vector2(400, 300), Vector2(100, 400), Vector2(700, 500), Vector2(300, 250), Vector2(600, 350)]:
			var w := cam.screen_to_world(sp)
			var back := cam.cell_to_screen(Vector3(w.x / WorldView.TILE, 0.0, w.y / WorldView.TILE))
			var cells := back.distance_to(sp) / 20.0  # ~px per cell is far larger than 20; this is conservative
			assert_lt(cells, 0.05, "round trip z=%s sp=%s back=%s" % [z, sp, back])


func test_zoom_clamps() -> void:
	var cam := _make_cam()
	for i in 200:
		cam.zoom_at(Vector2(400, 300), 1.15)
	assert_near(cam.zoom_level, CameraController.MAX_ZOOM, 0.0001)
	for i in 400:
		cam.zoom_at(Vector2(400, 300), 1.0 / 1.15)
	assert_near(cam.zoom_level, CameraController.MIN_ZOOM, 0.0001)


func test_pan_clamp_and_inertia() -> void:
	var cam := _make_cam()
	cam.focus = Vector2(99999, -99999)
	var m := CameraController.PAN_MARGIN
	assert_near(cam.focus.x, 2048 + m, 0.01)
	assert_near(cam.focus.y, -m, 0.01)
	cam.focus = Vector2(1000, 1000)
	cam._vel = Vector2(5000, 0)
	for i in 600:
		cam.step_inertia(0.016, false)
	assert_true(cam.focus.x <= 2048 + m + 0.01, "inertia stays in bounds")
	assert_eq(cam._vel, Vector2.ZERO, "inertia stops")
