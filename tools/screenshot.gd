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
	var panel := ""
	var tutorial := false  # R5X: --tutorial[=N] starts Warden's Orientation (N = lessons skipped first)
	var lesson := 0
	var nudge := false  # --nudge: wait past the lesson's nudge so the highlight shows
	var dialog := false  # --dialog: new-game dialog
	var wavereport := false  # region B5
	var radial := false  # --radial: radial menu open mid-screen
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
		elif a.begins_with("--panel="):
			panel = a.substr(8)  # open a registered side panel by id
		elif a.begins_with("--tutorial"):
			tutorial = true
			lesson = int(a.substr(11)) if a.length() > 11 else 0
		elif a == "--nudge":
			nudge = true
		elif a == "--dialog":
			dialog = true
		elif a == "--wavereport":  # region B5
			wavereport = true
		elif a == "--radial":
			radial = true
		elif a.begins_with("--zoom="):
			zoom = float(a.substr(7))
	if win != Vector2i.ZERO:
		get_window().size = win
	var game := (load("res://view/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	if ui_scale > 0.0:
		get_tree().root.content_scale_factor = ui_scale
	game.new_game(42, {"tutorial": true} if tutorial else {})
	game.sim.run_ticks(ticks)
	for i in lesson:
		game.sim.tutorial_skip_step()
	if nudge and tutorial:
		game.hud._process(0.1)  # lets the HUD stamp the lesson's start tick
		game.sim.run_ticks(int(game.sim.tutorial.current().get("nudge_ticks", 600)) + 20)
	for c in game.sim.colonists.list:
		c.hp = c.max_hp * 0.5  # show the overlay bars
	game.camera.zoom_level = zoom
	if cat != "":
		game.hud._toggle_cat(cat)
	if panel == "research":  # demo state: T2 audited, essence in stock, one tech half done, one queued
		var r: ResearchSystem = game.sim.research
		r.unlock_tier(2)
		r.paid.append("assembly")  # demo shortcut: essence already spent
		r.queue.push_front("assembly")
		r.progress["assembly"] = float(r.bench_ticks("assembly")) * 0.45
		game.sim.queue_research("filters", true)
	if panel.begins_with("exp_"):  # region R4e: the real campaign flow (research granted, party sent and arrived)
		var c: Campaign = game.campaign
		c.home_sim().research.done.append("expeditions")
		var ids: Array = []
		for col in c.home_sim().colonists.list:
			if ids.size() < 2:
				ids.append(col.id)
		c.send_expedition("ash", ids, {"raw_food": 10, "essence_ore": 30})
		for i in int(c.cfg["travel_ticks"]):
			c.step()
		if panel == "exp_map":
			c.switch_map(1)
			game._r4e_sync_active()
		else:
			if panel == "exp_cargo":
				c.switch_map(1)
				game._r4e_sync_active()
			game.hud.open_expedition("cargo" if panel == "exp_cargo" else "expedition")
			var p: ExpeditionPanel = game.hud._side
			if panel == "exp_crew":
				p.biome = "ash"
				p.step = ExpeditionPanel.Step.CREW
				p._render()
	elif panel != "":
		game.hud.toggle_panel(panel)
	if dialog:
		game._o3_open_dialog()
	if wavereport:  # region B5: fake a finished wave so the report card shows
		var bus: Node = game.sim.bus
		bus.wave_started.emit(1, 5.0)
		var bs: Array = game.sim.buildings.list
		if not bs.is_empty():
			game.hud._b5_card._by_building[bs[0].id] = "Brute"
			bus.building_destroyed.emit(bs[0].id)
		bus.enemy_killed.emit(1)
		bus.wave_ended.emit(1)
		game.hud._b5_card.refresh()
	if radial:
		game.radial.open_at(get_viewport().get_visible_rect().size * 0.5)
	if nudge and tutorial:
		game.hud._process(0.1)
	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	get_tree().quit()
