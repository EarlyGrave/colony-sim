extends Node
## S3 screenshots: gantry per stage + shuttle + beacon, then the win screen.
##   xvfb-run -a -s "-screen 0 1200x700x24" godot --path . --rendering-driver opengl3 res://tools/s3_shot.tscn -- --dir=<dir>


func _shot(path: String) -> void:
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


func _ready() -> void:
	var dir := "/tmp"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dir="):
			dir = a.substr(6)
	get_window().size = Vector2i(844, 390)
	var root := Node3D.new()
	add_child(root)
	var cam := Camera3D.new()
	root.add_child(cam)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.18, 0.16, 0.15)
	root.add_child(env)
	for s in 3:
		var g := ShuttleView3D.build_gantry(s)
		g.position = Vector3(-6 + s * 5.5, 0, 0)
		root.add_child(g)
	var sh := ShuttleView3D.build_shuttle()
	sh.position = Vector3(-6 + 2 * 5.5 + 2, 0.15, 2)
	root.add_child(sh)
	var bc := ShuttleView3D.build_beacon()
	bc.position = Vector3(8, 0, 4)
	root.add_child(bc)
	cam.position = Vector3(3, 6, 11)
	cam.look_at(Vector3(3, 1, 2))
	await _shot(dir + "/gantry_stages.png")
	root.queue_free()
	var cl := CanvasLayer.new()
	add_child(cl)
	cl.add_child(WinScreen.new({"days": 23, "colonists": 6, "debt_paid": 1200, "pollution": 0.42}))
	await _shot(dir + "/win_screen.png")
	get_tree().quit()
