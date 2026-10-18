extends Node
## View frame-time probe (needs a display, e.g. xvfb-run; GPU is software there):
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/view_bench.tscn -- --size=250 --enemies=300 --frames=120 --zoom=1.0


func _ready() -> void:
	var size := 250
	var enemies := 300
	var frames := 120
	var zoom := 1.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--size="):
			size = int(a.substr(7))
		elif a.begins_with("--enemies="):
			enemies = int(a.substr(10))
		elif a.begins_with("--frames="):
			frames = int(a.substr(9))
		elif a.begins_with("--zoom="):
			zoom = float(a.substr(7))
	var game := (load("res://view/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	var defs := Defs.get_default().duplicate_defs()
	defs.balance["map"]["width"] = size
	defs.balance["map"]["height"] = size
	defs.balance["threat"]["enabled"] = false
	game.world.unbind()
	game.world3d.unbind()
	game.sim.dispose()
	game.sim = Simulation.new(1, EventBus, defs)
	game.sim.start_new_game()
	game.world.bind(game.sim)
	game._bind_3d()
	game.hud.bind(game.sim)
	game.camera.world_size = game.world.world_size()
	game.camera.focus = WorldView.cell_to_world(game.sim.map_center())
	game.camera.zoom_level = zoom
	var center: Vector2i = game.sim.map_center()
	var kinds := ["crawler", "brute", "spitter", "burrower"]
	for i in enemies:
		var c := center + Vector2i(i % 40 - 20, i / 40 - 4)
		if game.sim.map.is_passable(c):
			game.sim.threats._spawn(kinds[i % 4], c)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for i in 20:
		await get_tree().process_frame
	var t0 := Time.get_ticks_usec()
	for i in frames:
		await get_tree().process_frame
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / frames
	var s0 := Time.get_ticks_usec()
	for i in 30:
		game.world3d._process(0.016)
	var script_ms := float(Time.get_ticks_usec() - s0) / 1000.0 / 30.0
	print("world3d._process script time %.2f ms" % script_ms)
	print("size=%d enemies=%d zoom=%.2f frame=%.2f ms (software GL)" % [size, game.sim.threats.enemies.size(), zoom, ms])
	get_tree().quit()
