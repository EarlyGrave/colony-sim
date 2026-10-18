extends Node
## C5 screenshots (needs a display): squad banners, ability radial, forecast sheet at 844x390 logical.
##   xvfb-run -a -s "-screen 0 2200x1100x24" godot --path . res://tools/c5_shot.tscn -- --dir=/tmp/shots


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
	var stub := SquadStub.new(game.sim.colonists)
	var ids: Array = game.sim.colonists.list.map(func(c: Colonist) -> int: return c.id)
	stub.form_squad(ids.slice(0, 3), ["bulwark", "lancer", "medic"])
	stub.form_squad(ids.slice(3, 5), ["bulwark"])
	stub.squads.list[0].hold = game.sim.map_center()
	stub.squads.cooldowns["1:taunt"] = 80
	game.hud.squad_bar.api = stub
	game.hud.squad_bar.refresh()
	game.hud.squad_bar.select(1)
	game.camera.zoom_level = 1.0
	await _shot(dir + "/c5_banners.png")
	var bar := game.hud.squad_bar
	var b: Button = bar.banners[1]
	bar.radial.set_slots(1, bar.ability_slots(1))
	bar.radial.open_at(b.get_global_rect().get_center())
	bar.radial.hovered = 1
	await _shot(dir + "/c5_ability_radial.png")
	bar.radial.close()
	game.sim.threats.awakened = true
	game.sim.threats.next_wave_tick = game.sim.tick + 150
	game.sim.threats._schedule_origin()
	game.hud.toggle_panel("forecast")
	await _shot(dir + "/c5_forecast.png")
	get_tree().quit()
