extends TestCase
## QA: restarting a game through the real GameController must not leak EventBus connections.


func _count() -> int:
	var bus: Node = Engine.get_main_loop().root.get_node("EventBus")
	var n := 0
	for s in bus.get_signal_list():
		n += bus.get_signal_connection_list(s["name"]).size()
	return n


func test_new_game_5x_no_connection_growth() -> void:
	var game := (load("res://view/game.tscn") as PackedScene).instantiate() as GameController
	_owned_nodes.append(game)
	var tree := Engine.get_main_loop() as SceneTree
	var host: Node = tree.current_scene if tree.current_scene != null else tree.root.get_child(tree.root.get_child_count() - 1)
	host.add_child(game)
	game.new_game(1)
	var base := _count()
	for i in 5:
		game.new_game(100 + i)
		game.sim.run_ticks(60)
		game.hud._process(0.1)
		game.world._process(0.1)
	assert_eq(_count(), base, "EventBus connections grew across restarts")
	assert_true(game.sim.tick > 0)
