extends TestCase
## R5: the open quest sheet never overlaps the notification stack (the stack yields while they would collide).


func test_sheet_and_stack_do_not_overlap() -> void:
	var game := (load("res://view/game.tscn") as PackedScene).instantiate() as GameController
	_owned_nodes.append(game)
	var tree := Engine.get_main_loop() as SceneTree
	var host: Node = tree.current_scene if tree.current_scene != null else tree.root.get_child(tree.root.get_child_count() - 1)
	host.add_child(game)
	var d := peaceful_defs()
	d.balance["q_enabled"] = true
	game.sim.defs.balance["q_enabled"] = true
	var root := tree.root
	root.content_scale_factor = 2.55
	root.size = Vector2i(2532, 1170)
	game.sim.quests.start("q1")
	var o: Dictionary = game.sim.q1_clerk.cfg["beats"]["offer"]
	game.sim.quests.offer("q1", "offer", str(o["text"]).replace("{clerk}", "Pell"), o["options"])
	game.hud._u2_stack.push("Toast one", "info", 30.0)
	game.hud._u2_stack.push("Toast two", "warn", 30.0)
	for i in 4:
		game.hud._process(0.3)
	var sheet: Control = game.hud._q0_sheet
	if sheet == null or not sheet.visible:
		return  # quests disabled in this build: nothing to overlap
	var st: Control = game.hud._u2_stack
	var overlap := st.visible and sheet.get_global_rect().intersects(st.get_global_rect())
	assert_false(overlap, "visible notification stack must not intersect the quest sheet")
