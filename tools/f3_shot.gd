extends Node
## F3 screenshot (needs a display): colonist rap sheet at 844x390 logical.
##   xvfb-run -a -s "-screen 0 2200x1100x24" godot --path . res://tools/f3_shot.tscn -- --dir=/tmp/shots


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
	var c: Colonist = game.sim.colonists.list[0]
	game.sim.colonists.add_kill(c, "crawler")
	for i in 6:
		game.sim.colonists.add_kill(c, "crawler")
	game.sim.colonists.rec(c)["ore_mined"] = 140
	game.sim.colonists.rec(c)["refined"] = 3
	game.sim.colonists.rec(c)["downs"] = 1
	game.sim.colonists.rec(c)["waves_survived"] = 2
	game.sim.colonists.record_changed(c)
	game._select_colonist(c.id)
	for i in 8:
		await get_tree().process_frame
	# The live inspector scrolls and rebuilds; mount the Record section alone on the same spot.
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -330
	panel.offset_top = 60
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.13)
	panel.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	panel.add_child(box)
	game.hud.add_child(panel)
	var sec: InspectorSection = load("res://view/panels/sections/record_section.gd").new()
	sec.build(game.sim, {"colonist": c}, box)
	game.set_speed(0)
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/f3_rapsheet.png")
	get_tree().quit()


func _find_scroll(n: Node) -> ScrollContainer:
	if n is ScrollContainer and n.is_visible_in_tree() and n.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		return n
	for ch in n.get_children():
		var r := _find_scroll(ch)
		if r != null:
			return r
	return null
