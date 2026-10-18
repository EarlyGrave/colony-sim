extends Node
## L2 screenshots (needs a display): Logic row and splitter filter sheet at 844x390 logical (scale 2.55).
##   xvfb-run -a -s "-screen 0 2200x1100x24" godot --path . res://tools/l2_shot.tscn -- --dir=/tmp/shots


func _shot(path: String) -> void:
	for i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


func _ready() -> void:
	var dir := "/tmp"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dir="):
			dir = a.substr(6)
	get_window().size = Vector2i(2152, 995)
	var game := (load("res://view/game.tscn") as PackedScene).instantiate() as GameController
	add_child(game)
	await get_tree().process_frame
	get_tree().root.content_scale_factor = 2.55
	game.new_game(42)
	game.sim.run_ticks(300)
	game.camera.zoom_level = 1.0
	game.auto_panel._logic_btn.button_pressed = true
	await _shot(dir + "/l2_logic_row.png")
	game.auto_panel._logic_btn.button_pressed = false
	var sim := game.sim
	var c := Vector2i(-1, -1)
	for y in sim.map.height:
		for x in sim.map.width:
			if c.x < 0 and sim.can_belt_cell_error(Vector2i(x, y)) == "":
				c = Vector2i(x, y)
	sim.place_belt_node(2, c, 1)
	game.splitter_panel.force_kind = 2
	game.splitter_panel.open(sim, c, 8.0)
	await _shot(dir + "/l2_sheet.png")
	game.splitter_panel._open_picker(1)
	await _shot(dir + "/l2_picker.png")
	get_tree().quit()
