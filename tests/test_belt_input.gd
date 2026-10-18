extends TestCase


func _free_cells(sim: Simulation, n: int) -> Array[Vector2i]:
	# A straight run of n passable, unoccupied cells in one row.
	for y in sim.map.height:
		var run: Array[Vector2i] = []
		for x in sim.map.width:
			var c := Vector2i(x, y)
			if sim.can_belt_cell_error(c) == "":
				run.append(c)
				if run.size() == n:
					return run
			else:
				run.clear()
	return []


func test_extend_path_manhattan() -> void:
	var p: Array[Vector2i] = [Vector2i(2, 2)]
	AutomationPanel.extend_path(p, Vector2i(4, 3))
	assert_eq(p.size(), 4)
	assert_eq(p[1], Vector2i(3, 2))
	assert_eq(p[3], Vector2i(4, 3))
	for i in p.size() - 1:
		assert_eq((p[i + 1] - p[i]).abs().x + (p[i + 1] - p[i]).abs().y, 1)


func test_extend_path_backtrack_pops() -> void:
	var p: Array[Vector2i] = [Vector2i(0, 0)]
	AutomationPanel.extend_path(p, Vector2i(3, 0))
	AutomationPanel.extend_path(p, Vector2i(1, 0))
	assert_eq(p.size(), 2)
	assert_eq(AutomationPanel.path_last_dir(p, 0), 1)


func test_last_dir() -> void:
	var p: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1)]
	assert_eq(AutomationPanel.path_last_dir(p, 3), 2)
	assert_eq(AutomationPanel.path_last_dir([Vector2i(0, 0)] as Array[Vector2i], 3), 3)


func test_panel_buttons_touch_size() -> void:
	var panel := AutomationPanel.new()
	_owned_nodes.append(panel)
	var stack: Array[Node] = [panel]
	var n := 0
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Button:
			n += 1
			assert_true((node as Button).custom_minimum_size.y >= 64.0)
		stack.append_array(node.get_children())
	assert_gt(n, 8)


func test_painted_path_places_belt() -> void:
	var sim := make_sim(11)
	var cells := _free_cells(sim, 5)
	assert_eq(cells.size(), 5)
	var p: Array[Vector2i] = [cells[0]]
	AutomationPanel.extend_path(p, cells[4])
	assert_true(sim.place_belt(p, AutomationPanel.path_last_dir(p, 1)))
	assert_eq(sim.logistics.dir_at(cells[0]), 1)
