extends Node
## F2 screenshot (needs a display): kill feed + PA banner at 844x390 logical (scale 2.55).
##   xvfb-run -a -s "-screen 0 2200x1100x24" godot --path . --rendering-driver opengl3 res://tools/f2_shot.tscn -- --out=/tmp/f2.png


func _ready() -> void:
	var out := "/tmp/f2_feed_pa.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	get_window().size = Vector2i(2152, 995)
	var game := (load("res://view/game.tscn") as PackedScene).instantiate() as GameController
	add_child(game)
	await get_tree().process_frame
	get_tree().root.content_scale_factor = 2.55
	game.new_game(42)
	game.sim.run_ticks(300)
	game.camera.zoom_level = 1.0
	var kinds := ["crawler", "brute", "spitter"]
	for i in 3:
		var e := Enemy.new(900 + i, kinds[i], game.sim.defs.enemies[kinds[i]], Vector2i(3, 3))
		e.hp = 1.0
		game.sim.threats.enemies.append(e)
		game.sim.threats.damage_enemy(e, 5.0, "turret")
	game.sim.bus.wave_started.emit(1, 1.0)
	for i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	get_tree().quit()
