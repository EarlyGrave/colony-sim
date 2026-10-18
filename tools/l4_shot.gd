extends Node
## L4 screenshots (needs a display): powered base with every generator model, overlay, HUD chip, power panel.
##   xvfb-run -a -s "-screen 0 2400x1200x24" godot --path . res://tools/l4_shot.tscn -- --dir=/tmp/x --size=844x390 --scale=2.55 --tag=phone


func _shot(path: String) -> void:
	for i in 14:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


func _ready() -> void:
	var dir := "/tmp"
	var sz := Vector2i(844, 390)
	var sc := 2.55
	var tag := "phone"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dir="):
			dir = a.substr(6)
		elif a.begins_with("--size="):
			var p := a.substr(7).split("x")
			sz = Vector2i(int(p[0]), int(p[1]))
		elif a.begins_with("--scale="):
			sc = float(a.substr(8))
		elif a.begins_with("--tag="):
			tag = a.substr(6)
	get_window().size = Vector2i(roundi(sz.x * sc), roundi(sz.y * sc))
	var game := (load("res://view/game.tscn") as PackedScene).instantiate() as GameController
	add_child(game)
	await get_tree().process_frame
	get_tree().root.content_scale_factor = sc
	game.new_game(42)
	game.sim.run_ticks(200)
	var at := game.sim.map_center() + Vector2i(0, 8)
	PowerStub.build_base(game.sim, at)
	game.camera.focus = WorldView.cell_to_world(at + Vector2i(1, -4))
	game.camera.zoom_level = 0.95 if sz.x < 1000 else 1.1
	await _shot("%s/l4_%s_models.png" % [dir, tag])
	PowerReader.overlay_on = true
	await _shot("%s/l4_%s_overlay.png" % [dir, tag])
	game.hud.toggle_panel("power")
	await _shot("%s/l4_%s_panel.png" % [dir, tag])
	get_tree().quit()
