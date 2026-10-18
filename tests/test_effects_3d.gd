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


func test_mining_dust_spawn_and_free() -> void:
	var fx := _make_fx()
	fx.sim.bus.item_mined.emit(Vector2i(3, 3), "ore", 1)
	assert_eq(fx.spawned, 3)
	assert_eq(fx.active_count(), 3)
	for i in 50:
		fx.tick(0.1)  # 5 s
	assert_eq(fx.active_count(), 0)
	assert_eq(fx.get_child_count() - fx.get_children().filter(func(n: Node) -> bool: return n.is_queued_for_deletion()).size(), 0)


func test_kill_puff_and_tracer() -> void:
	var fx := _make_fx()
	fx.sim.bus.enemy_killed.emit(99)
	assert_eq(fx.spawned, 4)
	fx.spawn_tracer(Vector2(1, 1), Vector2(5, 3))
	fx.spawn_spark(Vector2(5, 3))
	assert_eq(fx.spawned, 6)
	for i in 50:
		fx.tick(0.1)
	assert_eq(fx.active_count(), 0)


func test_effect_cap() -> void:
	var fx := _make_fx()
	for i in 200:
		fx.spawn_spark(Vector2(1, 1))
	assert_true(fx.active_count() <= Effects3D.MAX_EFFECTS)
