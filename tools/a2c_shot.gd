extends SceneTree
## Screenshot of a belt loop + machines placed through Simulation commands:
## xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/a2c_shot.gd -- out.png

var game: Node


func _initialize() -> void:
	game = load("res://view/game.tscn").instantiate()
	root.add_child(game)
	root.size = Vector2i(1100, 700)


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _wait(5)
	var sim: Simulation = game.sim
	var o := sim.map_center() + Vector2i(6, 6)
	for y in range(-1, 13):
		for x in range(-1, 22):
			var c := o + Vector2i(x, y)
			if sim.map.get_tile(c) != MapGrid.Tile.GROUND and not sim.buildings.occupied(c):
				sim.map.set_tile(c, MapGrid.Tile.GROUND)
	var loop: Array = []
	for x in 6:
		loop.append(o + Vector2i(x, 0))
	for y in range(1, 4):
		loop.append(o + Vector2i(5, y))
	for x in range(4, -1, -1):
		loop.append(o + Vector2i(x, 3))
	for y in range(2, 0, -1):
		loop.append(o + Vector2i(0, y))
	print("loop ", sim.place_belt(loop, 1))
	var line: Array = []
	for x in range(8, 20):
		line.append(o + Vector2i(x, 7))
	print("line ", sim.place_belt(line, 1))
	print(sim.buildings.place("miner", o + Vector2i(5, 6), false) != null)
	print(sim.buildings.place("smelter", o + Vector2i(9, 5), false) != null)
	print(sim.buildings.place("assembler", o + Vector2i(14, 9), false) != null)
	print(sim.buildings.place("storage_in", o + Vector2i(12, 2), false) != null)
	print(sim.buildings.place("storage_out", o + Vector2i(14, 2), false) != null)
	for i in 6:
		sim.logistics.insert_item(loop[i * 3], "essence_ore")
		sim.logistics.insert_item(line[i * 2], "refined_essence")
	for i in 12:
		sim.step()
	game.camera.focus = WorldView.cell_to_world(o + Vector2i(10, 5))
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		game.camera.zoom_level = float(args[1])
		game.camera.focus = WorldView.cell_to_world(o + Vector2i(10, 5) + Vector2i(int(args[2]), int(args[3])))
	await _wait(30)
	root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	var bl: BeltLayer = game.world3d._belt_layer
	print("belts ", bl.belt_instance_total(), " items ", bl.item_instance_total(), " draws ", bl.draw_calls())
	quit()
