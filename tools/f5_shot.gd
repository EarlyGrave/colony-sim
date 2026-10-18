extends Node
## F5 screenshots (needs a display): new-game dialog, radial menu, expedition panel with Recall at 844x390 logical.
##   xvfb-run -a -s "-screen 0 2200x1100x24" godot --path . res://tools/f5_shot.tscn -- --dir=/tmp/shots


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
	await _shot(dir + "/f5_idle.png")
	# radial pressed next to the belt strip
	var r := game.auto_panel.get_global_rect()
	game.radial.open_at(r.get_center())
	await _shot(dir + "/f5_radial.png")
	game.radial.close()
	# expedition panel with an outpost
	var c: Campaign = game.campaign
	c.home_sim().research.done.append("expeditions")
	var ids: Array = []
	for col in c.home_sim().colonists.list:
		if ids.size() < 2:
			ids.append(col.id)
	c.send_expedition("ash", ids, {"raw_food": 10, "essence_ore": 30})
	for i in int(c.cfg["travel_ticks"]):
		c.step()
	game.hud.open_expedition("expedition")
	await _shot(dir + "/f5_expedition_recall.png")
	var p: ExpeditionPanel = game.hud._side
	p.ask_recall(1)
	await _shot(dir + "/f5_expedition_confirm.png")
	game.hud.close_side()
	game._o3_open_dialog()
	await _shot(dir + "/f5_dialog.png")
	get_tree().quit()
