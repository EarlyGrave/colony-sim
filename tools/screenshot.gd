extends Node
## Renders the real game scene and saves a PNG (needs a display, e.g. xvfb-run):
##   xvfb-run -a godot --path . res://tools/screenshot.tscn -- --out=shot.png --ticks=600 --zoom=1.0


func _ready() -> void:
	var out := "shot.png"
	var ticks := 600
	var zoom := 1.0
	var ui_scale := 0.0
	var win := Vector2i.ZERO
	var cat := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--ticks="):
			ticks = int(a.substr(8))
		elif a.begins_with("--scale="):
			ui_scale = float(a.substr(8))
		elif a.begins_with("--w="):
			win.x = int(a.substr(4))
		elif a.begins_with("--h="):
			win.y = int(a.substr(4))
		elif a.begins_with("--cat="):
			cat = a.substr(6)  # open a compact HUD category popup (zones/build/orders)
		elif a.begins_with("--zoom="):
			zoom = float(a.substr(7))
	if win != Vector2i.ZERO:
		get_window().size = win
	var game := (load("res://view/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	if ui_scale > 0.0:
		get_tree().root.content_scale_factor = ui_scale
	game.new_game(42)
	game.sim.run_ticks(ticks)
	for c in game.sim.colonists.list:
		c.hp = c.max_hp * 0.5  # show the overlay bars
	game.camera.zoom_level = zoom
	if cat != "":
		game.hud._toggle_cat(cat)
	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	get_tree().quit()
