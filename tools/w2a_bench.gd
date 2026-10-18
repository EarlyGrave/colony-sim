extends Node
## View frame-time probe (needs a display, e.g. xvfb-run; GPU is software there):
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/view_bench.tscn -- --size=250 --enemies=300 --frames=120 --zoom=1.0


func _cpu_ms() -> float:
	var st := FileAccess.open("/proc/self/stat", FileAccess.READ).get_line()
	var f := st.substr(st.rfind(")") + 2).split(" ")
	return (float(f[11]) + float(f[12])) * 10.0  # utime + stime, 100 Hz ticks


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
	game.campaign = null
	game.hud.bind_campaign(null)
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
	var modes := {}
	for n in get_tree().root.find_children("*", "SubViewport", true, false):
		var k := "%s:%d" % [n.get_parent().name if n.get_parent() != null else "", (n as SubViewport).render_target_update_mode]
		modes[k] = int(modes.get(k, 0)) + 1
	print("subviewports ", modes)
	var u0: int = game.world3d.chunks.update_calls
	var r0: int = game.world.chunk_redraws
	var vps: Array = [get_viewport()]
	vps.append_array(get_tree().root.find_children("*", "SubViewport", true, false))
	for v in vps:
		RenderingServer.viewport_set_measure_render_time((v as Viewport).get_viewport_rid(), true)
	var c0 := _cpu_ms()
	var t0 := Time.get_ticks_usec()
	var pt := 0.0
	var pmax := 0.0
	for i in frames:
		await get_tree().process_frame
		var v := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		pt += v
		pmax = maxf(pmax, v)
	print("TIME_PROCESS mean %.1f max %.1f ms" % [pt / frames, pmax])
	for v in vps:
		print("  vp %s cpu %.2f gpu %.2f ms" % [v.name, RenderingServer.viewport_get_measured_render_time_cpu((v as Viewport).get_viewport_rid()), RenderingServer.viewport_get_measured_render_time_gpu((v as Viewport).get_viewport_rid())])
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / frames
	print("cpu %.2f ms/frame" % ((_cpu_ms() - c0) / frames))
	print("chunk viewport updates %d redraws %d over %d frames" % [game.world3d.chunks.update_calls - u0, game.world.chunk_redraws - r0, frames])
	print("process %.1f ms physics %.1f ms draws %d prims %d objs %d" % [Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
	for n: Node in [game, game.hud, game.world, game.world3d, game.camera]:
		var q0 := Time.get_ticks_usec()
		for i in 10:
			n._process(0.016)
		print("  _process %s %.2f ms" % [n.name, float(Time.get_ticks_usec() - q0) / 10000.0])
	var s0 := Time.get_ticks_usec()
	for i in 30:
		game.world3d._process(0.016)
	var script_ms := float(Time.get_ticks_usec() - s0) / 1000.0 / 30.0
	print("world3d._process script time %.2f ms" % script_ms)
	print("size=%d enemies=%d zoom=%.2f frame=%.2f ms (software GL)" % [size, game.sim.threats.enemies.size(), zoom, ms])
	get_tree().quit()
