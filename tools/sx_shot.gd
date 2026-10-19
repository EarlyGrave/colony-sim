extends Node
const Scenario := preload("res://tests/scenario.gd")
## SX screenshots (real game scene, 844x390): gantry mid-build, countdown siege, win screen.
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/sx_shot.tscn -- --dir=<dir>


func _shot(game: Node, path: String) -> void:
	for i in 20:
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
	var game := (load("res://view/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	game.new_game(42, {})
	var sim: Simulation = game.sim
	sim.run_ticks(300)
	sim.petition.done_phases = [1, 2, 3, 4]
	var c := sim.map_center()
	var g := sim.buildings.place("release_gantry", Scenario.find_spot(sim, "release_gantry", c + Vector2i(-3, -6), 0), false)
	sim.buildings.place("power_pole", Scenario.find_spot(sim, "power_pole", g.cell + Vector2i(4, 1), 0), false)
	for i in 3:
		sim.buildings.place("solar_array", Scenario.find_spot(sim, "solar_array", g.cell + Vector2i(5 + i * 2, 3), 0), false)
	for off in [Vector2i(-2, -2), Vector2i(5, -2), Vector2i(-2, 5), Vector2i(5, 5)]:
		sim.buildings.place("turret", Scenario.find_spot(sim, "turret", g.cell + off, 0), false)
	game.camera.zoom_level = 0.9
	game.camera.focus = WorldView.cell_to_world(g.cell + Vector2i(2, 1))
	if "--nohud" in OS.get_cmdline_user_args():
		game.hud.visible = false
	sim.shuttle.parts = 14
	sim.run_ticks(2)
	await _shot(game, dir + "/gantry_mid_build.png")
	sim.shuttle.parts = sim.shuttle.parts_need()
	sim.run_ticks(2)
	sim.launch_shuttle()
	sim.run_ticks(900)
	var gb: Building = sim.shuttle.gantry()
	if gb != null:
		gb.hp = gb.max_hp * 0.6
	game.hud._process(0.6)
	await _shot(game, dir + "/countdown_siege.png")
	sim.shuttle.won = true
	sim.shuttle.counting = false
	sim.run_ticks(2)
	EventBus.shuttle_won.emit()
	await _shot(game, dir + "/win_screen.png")
	get_tree().quit()
