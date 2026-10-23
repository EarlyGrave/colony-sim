extends Node
## F11W4 board screenshots (needs a display), phone size 844x390 logical at DPR 3 * 0.85:
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/f11w4_shot.tscn -- --dir=/tmp/shots
## Writes f11w4_board.png (card + sheet on a keystone) and f11w4_sheet.png (colonist sheet with Record button).


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
	get_window().size = Vector2i(2532, 1170)
	var game := (load("res://view/game.tscn") as PackedScene).instantiate() as GameController
	add_child(game)
	await get_tree().process_frame
	get_tree().root.content_scale_factor = 2.55
	game.new_game(42)
	game.sim.defs.balance["passives_v2_enabled"] = true
	game.sim.run_ticks(120)
	var c: Colonist = game.sim.colonists.list[0]
	c.skills.levels["mining"] = 4
	game.sim.grant_passive_marks(c.id, 12, "shot")
	for id in ["p_pit_callouses", "p_pit_the_mule", "p_pit_vein_reader"]:
		game.sim.allocate_passive(c.id, id)
	game.hud.show_inspector({"kind": "colonist", "colonist": c})
	await _shot(dir + "/f11w4_sheet.png")
	game.hud.open_panel_for("passives", c.id)
	var b: PassiveBoard = game.hud._side
	b._select("p_pit_beast_of_burden")
	await _shot(dir + "/f11w4_board.png")
	get_tree().quit()
