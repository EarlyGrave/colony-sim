extends TestCase


func _make_fx() -> Effects3D:
	var sim := make_sim(5, false, 24, 24, TestCase.peaceful_defs())
	var tree := Engine.get_main_loop() as SceneTree
	var host: Node = tree.current_scene if tree.current_scene != null else tree.root.get_child(tree.root.get_child_count() - 1)
	var fx := Effects3D.new()
	host.add_child(fx)
	_owned_nodes.append(fx)
	fx.bind(sim)
	return fx


func test_caps_and_constant_pools() -> void:
	var fx := _make_fx()
	var j := fx.juice
	var sizes0: Array = j.pool_sizes()
	var children0 := j.get_child_count()
	for i in 500:
		fx.sim.bus.enemy_killed.emit(1000 + i)
		assert_true(j.live_particles() <= 64)
		assert_true(j.live_decals() <= 40)
		if i % 7 == 0:
			fx.tick(0.1)
	assert_eq(j.pool_sizes(), sizes0)
	assert_eq(j.get_child_count(), children0)
	assert_true(j.live_particles() <= 64 and j.live_decals() <= 40)
	for i in 400:
		fx.tick(0.1)  # 40 s: everything faded
	assert_eq(j.live_particles(), 0)
	assert_eq(j.live_decals(), 0)


func test_splat_colour_greener_with_taint() -> void:
	var fx := _make_fx()
	var lo := fx.juice.splat_color(0.1)
	var hi := fx.juice.splat_color(0.9)
	assert_gt(hi.g - lo.g, 0.15)


func test_brute_double_burst_and_tint() -> void:
	var fx := _make_fx()
	var j := fx.juice
	j._kinds[7] = "brute"
	j.on_kill(7, Vector2(5, 5))
	assert_gt(float(j.live_particles()), 15.0)
	assert_gt(j.shake_px, 1.9)
	assert_eq(j.live_decals(), 0, "brutes leave no splat")
	j.reset()
	j._kinds[8] = "spitter"
	j.on_kill(8, Vector2(5, 5))
	assert_true(j.live_particles() >= 8 and j.live_particles() <= 12)
	fx.tick(0.016)
	assert_eq(j.live_decals(), 1)


func test_audited_label_pooled_max_three() -> void:
	var fx := _make_fx()
	var j := fx.juice
	for i in 8:
		j.trigger_audited(Vector3(3, 1, 3))
	assert_eq(j.live_labels(), 3)
	for i in 40:
		fx.tick(0.1)
	assert_eq(j.live_labels(), 0)


func test_disabled_does_nothing() -> void:
	var fx := _make_fx()
	var j := fx.juice
	j.enabled = false
	fx.sim.bus.enemy_killed.emit(5)
	assert_eq(j.live_particles(), 0)
	assert_eq(j.live_decals(), 0)
	j.trigger_audited(Vector3.ZERO)
	assert_eq(j.live_labels(), 0)
