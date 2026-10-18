extends SceneTree
## C3 telegraph screenshot:
## xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/c3_shot.gd -- out.png

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
	game.set_speed(0)
	var o := sim.map_center() + Vector2i(8, 8)
	for y in range(-3, 12):
		for x in range(-3, 16):
			var c := o + Vector2i(x, y)
			if sim.map.get_tile(c) != MapGrid.Tile.GROUND and not sim.buildings.occupied(c):
				sim.map.set_tile(c, MapGrid.Tile.GROUND)
	sim.colonists.spawn(o + Vector2i(2, 2))
	sim.colonists.spawn(o + Vector2i(9, 2))
	sim.colonists.spawn(o + Vector2i(2, 8))
	sim.threats._spawn("brute", o + Vector2i(3, 2))
	sim.threats._spawn("spitter", o + Vector2i(14, 2))
	sim.threats._spawn("crawler", o + Vector2i(3, 8))
	sim.threats._spawn("burrower", o + Vector2i(8, 2))
	var n := 0
	for i in 200:
		sim.step()
		n = sim.threats.telegraphs().size()
		if n >= 3:
			break
	print("telegraphs ", n, " tick ", sim.tick)
	game.camera.zoom_level = 2.0
	game.camera.focus = WorldView.cell_to_world(o + Vector2i(7, 5))
	await _wait(30)
	root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	quit()
