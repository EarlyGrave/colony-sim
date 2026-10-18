extends Node
## W2a before/after probe: a fixed scene (zone, blueprint, field overlay, patrol, selection, night) at speed 0.
##   xvfb-run -a godot --path . res://tools/w2a_cmp.tscn -- --out=a.png [--desig]


func _ready() -> void:
	var out := "cmp.png"
	var desig := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a == "--desig":
			desig = true
	var game := (load("res://view/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	game.new_game(42, {})
	game.sim.run_ticks(1500)
	game.set_speed(0)
	print("A")
	var c: Vector2i = game.sim.map_center()
	for dx in 6:
		for dy in 4:
			game.sim.set_zone(c + Vector2i(dx + 3, dy), "stockpile")
	game.sim.place_building("wall", c + Vector2i(-4, 4))
	game.sim.place_building("wall", c + Vector2i(-3, 4))
	for x in range(-8, 8):
		for y in range(-6, 6):
			var cc := c + Vector2i(x, y)
			game.sim.mutation.field[cc.y * game.sim.map.width + cc.x] = float(x + 9) * 3.0
	for y in game.sim.map.height:
		game.sim.mutation.dirty_rows[y] = 1
	game.world.patrol_draft.assign([c + Vector2i(-6, -3), c + Vector2i(-2, -3), c + Vector2i(-2, 2)])
	game.world.selected_cell = c + Vector2i(2, 2)
	game.world.pending_corner = c + Vector2i(5, -4)
	if desig:
		var n := 0
		for x in range(-20, 20):
			for y in range(-20, 20):
				if n < 6 and game.sim.map.get_tile(c + Vector2i(x, y)) != MapGrid.Tile.GROUND:
					game.sim.designate_mine(c + Vector2i(x, y), true)
					n += 1
	print("B")
	game.camera.focus = WorldView.cell_to_world(c)
	game.camera.zoom_level = 1.0
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	get_tree().quit()
