class_name GameController
extends Node
## Owns the running Simulation, drives fixed ticks at the chosen speed and
## wires view + HUD. Player input becomes Simulation commands here.

const MAX_TICKS_PER_FRAME := 40
const RECT_TOOLS := ["mine", "stockpile", "waste_dump", "clear_zone", "growing"]
const BUILD_TOOLS := ["refinery", "turret", "wall", "door", "workbench", "stove", "bed", "training_dummy", "miner", "smelter", "assembler", "storage_in", "storage_out"]
const HINTS := {
	"inspect": "Нажми на клетку, чтобы посмотреть, что там.",
	"mine": "Добыча: нажми два угла области с рудой (фиолетовое).",
	"stockpile": "Склад: нажми два угла области.",
	"waste_dump": "Свалка отходов: нажми два угла области. Отходы там заражают слабее.",
	"growing": "Грядки: нажми два угла области. Колонисты посеют и соберут клубни.",
	"patrol": "Патруль: нажимай клетки маршрута по порядку, затем «Готово». «Авто» — кольцо вокруг базы.",
	"clear_zone": "Убрать зону: нажми два угла области.",
}

var sim: Simulation
var speed := 1
var tool := "inspect"
var _accum := 0.0

@onready var world: WorldView = $MapViewport/World
@onready var world3d: WorldView3D = $World3D
@onready var map_viewport: SubViewport = $MapViewport
@onready var camera: CameraController = $Camera
@onready var hud: Hud = $Hud


func _ready() -> void:
	_apply_ui_scale()
	world3d.camera = camera
	world3d.world_view = world  # region G1b
	world3d.overlay = $Overlay
	camera.tapped.connect(_on_tapped)
	_setup_automation()  # region A2d
	hud.tool_selected.connect(_on_tool_selected)
	hud.speed_selected.connect(set_speed)
	hud.alarm_toggled.connect(func(on: bool) -> void: sim.set_alarm(on))
	hud.rule_toggled.connect(func(id: String, on: bool) -> void:
		sim.set_rule(id, on)
		hud.show_message(("Правило включено: " if on else "Правило выключено: ") + str(sim.defs.rules[id]["name"]), 4.0))
	hud.new_game_requested.connect(func() -> void: new_game(_random_seed()))
	hud.colonist_card_pressed.connect(_select_colonist)
	hud.overlay_toggled.connect(func(on: bool) -> void: world.show_field = on)  # region batch3 ui
	hud.patrol_undo.connect(func() -> void:
		if not world.patrol_draft.is_empty():
			world.patrol_draft.pop_back())
	hud.patrol_auto.connect(func() -> void:
		world.patrol_draft.clear()
		sim.set_patrol_route([])
		hud.show_message("Патруль: автоматический маршрут.", 3.0))
	hud.patrol_done.connect(func() -> void:
		if world.patrol_draft.is_empty():
			hud.show_message("Сначала отметь точки маршрута.", 3.0)
			return
		sim.set_patrol_route(world.patrol_draft)
		hud.show_message("Маршрут патруля сохранён: %d точек." % world.patrol_draft.size(), 3.0)
		world.patrol_draft.clear())
	hud.focus_cell_requested.connect(func(cell: Vector2i) -> void:
		camera.focus = WorldView.cell_to_world(cell))
	EventBus.game_over.connect(_on_game_over_meta)  # region meta
	new_game(_initial_seed(), MetaStore.load_state().make_opts())  # region meta
	_setup_save_load()  # save-load


## Scales the whole 2D/UI by screen density so touch targets keep a physical
## size: ~0.85 CSS px per logical px on phones/tablets, 1:1 on desktop.
## Flat layers render at 16 px per cell into the map viewport, which the 3D
## ground plane and rock blocks sample.
func _bind_3d() -> void:
	map_viewport.size = Vector2i(64, 64)  # host of the shared canvas only; chunk viewports render it
	map_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	world3d.bind(sim, map_viewport.world_2d)


func _apply_ui_scale() -> void:
	var dpr := DisplayServer.screen_get_scale()
	if OS.has_feature("web"):
		var v: Variant = JavaScriptBridge.eval("window.devicePixelRatio || 1")
		if v != null:
			dpr = float(v)
	get_tree().root.content_scale_factor = clampf(dpr * 0.85, 1.0, 4.0)


func _exit_tree() -> void:
	if sim:
		world.unbind()
		world3d.unbind()
		sim.dispose()
		sim = null


func _initial_seed() -> int:
	if OS.has_feature("web"):
		var s: Variant = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('seed')")
		if s != null and str(s).is_valid_int():
			return int(str(s))
	return _random_seed()


func _random_seed() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0) % 1000000


# region meta
var _meta_layer: CanvasLayer


func _on_game_over_meta(_reason: String) -> void:
	var meta := MetaStore.load_state()
	meta.record_run(sim.run_summary)
	MetaStore.save_state(meta)
	_close_meta()
	_meta_layer = CanvasLayer.new()
	_meta_layer.layer = 60
	add_child(_meta_layer)
	var scr := MetaScreen.new(meta, sim.run_summary)
	scr.new_link.connect(func(o: Dictionary) -> void:
		_close_meta()
		new_game(_random_seed(), o))
	scr.next_batch.connect(func(s: int, o: Dictionary) -> void:
		_close_meta()
		new_game(s, o))
	_meta_layer.add_child(scr)


func _close_meta() -> void:
	if _meta_layer != null:
		_meta_layer.queue_free()
		_meta_layer = null
# endregion


func new_game(seed_value: int, opts: Dictionary = {}) -> void:
	if sim:
		world.unbind()
		world3d.unbind()
		sim.dispose()
	sim = Simulation.new(seed_value, EventBus, null, opts)  # region meta
	sim.start_new_game()
	combat_selected = -1  # region combat
	world.bind(sim)
	_bind_3d()
	world.pending_corner = Vector2i(-1, -1)
	world.selected_cell = Vector2i(-1, -1)
	world.patrol_draft.clear()
	_belt_reset()  # region A2d
	hud.bind(sim)
	camera.world_size = world.world_size()
	camera.focus = WorldView.cell_to_world(sim.map_center())
	camera.zoom_level = 1.0
	_accum = 0.0
	set_speed(1)
	hud.show_message("Сид %d. Отметь руду инструментом «Добыча» — колонисты начнут копать." % seed_value, 8.0)


func set_speed(s: int) -> void:
	speed = s
	hud.set_speed(s)


func _process(delta: float) -> void:
	if sim == null or speed == 0:
		return
	_accum += delta * Simulation.TICKS_PER_SECOND * speed
	var n := mini(int(_accum), MAX_TICKS_PER_FRAME)
	_accum -= int(_accum)
	for i in n:
		sim.step()


func _unhandled_key_input(event: InputEvent) -> void:
	# Optional desktop shortcuts; everything is reachable by touch too.
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				set_speed(0 if speed != 0 else 1)
			KEY_1, KEY_2, KEY_3:
				set_speed(event.keycode - KEY_0)


func _on_tool_selected(t: String) -> void:
	tool = t
	_leave_belt_tools()  # region A2d
	world.pending_corner = Vector2i(-1, -1)
	world.patrol_draft.clear()
	if t in BUILD_TOOLS:
		var def: Dictionary = sim.defs.buildings[t]
		var cost: Array[String] = []
		for item in def["cost"]:
			cost.append("%s ×%d" % [str(sim.defs.items[item]["name"]).to_lower(), def["cost"][item]])
		hud.show_message("%s (%s): нажми, где поставить (%d×%d)." % [def["name"], ", ".join(cost), def["size"][0], def["size"][1]], 5.0)
	else:
		hud.show_message(HINTS.get(t, ""), 5.0)


func _on_tapped(world_pos: Vector2) -> void:
	var cell := WorldView.world_to_cell(world_pos)
	if sim == null or not sim.map.in_bounds(cell):
		return
	# region combat
	if _combat_tap(world_pos, cell):
		return
	# endregion
	if tool in RECT_TOOLS:
		if world.pending_corner.x < 0:
			world.pending_corner = cell
			hud.show_message("Теперь нажми второй угол.", 4.0)
		else:
			_apply_rect(Rect2i(world.pending_corner, Vector2i.ONE).expand(cell + Vector2i.ONE))
			world.pending_corner = Vector2i(-1, -1)
	elif tool in BUILD_TOOLS:
		var err := sim.can_place_building(tool, cell)
		if err == "":
			sim.place_building(tool, cell)
			hud.show_message("Заложено: " + str(sim.defs.buildings[tool]["name"]) + " (нужны материалы и стройка)", 3.0)
		else:
			hud.show_message(err, 3.0)
	elif tool == "patrol":
		if sim.map.is_passable(cell):
			world.patrol_draft.append(cell)
			hud.show_message("Точка %d. «Готово», когда хватит." % world.patrol_draft.size(), 2.0)
		else:
			hud.show_message("Сюда не пройти.", 2.0)
	elif tool == "deconstruct":
		if sim.deconstruct(cell):
			hud.show_message("Снесено / план отменён", 3.0)
		else:
			hud.show_message("Здесь нечего сносить", 3.0)
	else:
		_inspect(world_pos, cell)


func _apply_rect(r: Rect2i) -> void:
	var count := 0
	match tool:
		"mine":
			# Toggle: if the first corner was designated, clear the area instead.
			var on := not sim.map.is_mine_designated(world.pending_corner)
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					var c := Vector2i(x, y)
					if sim.map.is_deposit(c):
						sim.designate_mine(c, on)
						count += 1
			hud.show_message(("Отмечено под добычу: %d" if on else "Снята отметка: %d") % count, 3.0)
		"clear_zone":
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					sim.set_zone(Vector2i(x, y), "")
		_:
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					if sim.set_zone(Vector2i(x, y), tool):
						count += 1
			hud.show_message("%s: %d клеток" % [sim.defs.zones[tool]["name"], count], 3.0)


## Inspect tool: colonist under the tap, else building, else the bare cell.
func _inspect(world_pos: Vector2, cell: Vector2i) -> void:
	world.selected_cell = cell
	var best: Colonist = null
	var best_d := WorldView.TILE * 0.9
	for col in sim.colonists.list:
		if not col.alive or col.hidden:
			continue
		# Standing sprites: a tap on the body hits the ground just north of the feet.
		var feet := col.visual_pos() * WorldView.TILE + Vector2(WorldView.TILE, WorldView.TILE) * 0.5
		var d := minf(feet.distance_to(world_pos), (feet - Vector2(0, WorldView.TILE * 0.7)).distance_to(world_pos))
		if d < best_d:
			best_d = d
			best = col
	if best != null:
		_select_colonist(best.id, false)
		return
	world3d.selected_colonist = -1  # region G1c
	hud.show_inspector(inspect_target(sim, cell))


## Target dictionary for the inspector (see InspectorSection).
static func inspect_target(p_sim: Simulation, cell: Vector2i) -> Dictionary:
	var b := p_sim.buildings.at(cell)
	return {"kind": "building" if b else "cell", "colonist": null, "building": b, "cell": cell}


func _select_colonist(id: int, center := true) -> void:
	combat_selected = id  # region combat
	world3d.selected_colonist = id  # region G1c
	for col in sim.colonists.list:
		if col.id == id and col.alive:
			world.selected_cell = col.cell
			if center:
				camera.focus = col.visual_pos() * WorldView.TILE + Vector2(WorldView.TILE, WorldView.TILE) * 0.5
			hud.show_inspector({"kind": "colonist", "colonist": col, "building": null, "cell": col.cell})
			return


# region save-load
var _continue_btn: Button
var _loading := false


## Loads user://autosave.json by replaying its command log.
func load_game() -> void:
	if _loading:
		return
	var text := SaveStore.read_text()
	if text == "":
		hud.show_message("Нет сохранения.", 3.0)
		return
	_loading = true
	var prev_speed := speed
	set_speed(0)
	hud.show_message("Загрузка…", 60.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var res := SaveGame.load_json(text, EventBus)
	_loading = false
	if not res["ok"]:
		set_speed(prev_speed)
		if res["error"] == "version":  # region A1d
			hud.show_message("Old save is incompatible with this version.", 5.0)
			return
		hud.show_message("Не удалось загрузить сохранение (%s)." % res["error"], 5.0)
		return
	if sim:
		world.unbind()
		world3d.unbind()
		sim.dispose()
	sim = res["sim"]
	world.bind(sim)
	_bind_3d()
	world.pending_corner = Vector2i(-1, -1)
	world.selected_cell = Vector2i(-1, -1)
	hud.bind(sim)
	camera.world_size = world.world_size()
	camera.focus = WorldView.cell_to_world(sim.map_center())
	_accum = 0.0
	set_speed(1)
	_update_continue()
	hud.show_message("Игра загружена.", 3.0)


func autosave() -> void:
	if sim != null and sim.game_over_reason == "" and not _loading:
		SaveStore.write(sim)


func _setup_save_load() -> void:
	EventBus.day_started.connect(func(_d: int) -> void: autosave())
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_continue_btn = Button.new()
	_continue_btn.text = "Продолжить"
	_continue_btn.custom_minimum_size = Vector2(260, 80)
	_continue_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_continue_btn.position.y -= 120
	_continue_btn.focus_mode = Control.FOCUS_NONE
	_continue_btn.pressed.connect(load_game)
	layer.add_child(_continue_btn)
	EventBus.game_over.connect(func(_r: String) -> void: _update_continue())
	_update_continue()


func _update_continue() -> void:
	_continue_btn.visible = SaveStore.has_save() and (sim == null or sim.tick < 50 or sim.game_over_reason != "")


func _notification(what: int) -> void:
	# Page hidden / app paused or unfocused: save immediately (web tab hide
	# triggers focus-out in Godot's web platform).
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		autosave()
# region combat
## Colonist last selected with the inspect tool (target of draft orders).
var combat_selected := -1


## With a drafted colonist selected: tap an enemy = attack, tap empty ground = move.
func _combat_tap(world_pos: Vector2, cell: Vector2i) -> bool:
	if tool != "inspect" or combat_selected < 0:
		return false
	var sel := sim.colonists.get_by_id(combat_selected)
	if sel == null or not sel.alive or sel.combat == null or not sel.combat.drafted:
		return false
	var half := Vector2(WorldView.TILE, WorldView.TILE) * 0.5
	for e in sim.threats.enemies_in_range(Vector2(cell), 2.0):
		if (e.visual_pos() * WorldView.TILE + half).distance_to(world_pos) < WorldView.TILE * 0.9:
			if sim.order_attack(sel.id, e.id):
				hud.show_message("Атака!", 2.0)
			return true
	for col in sim.colonists.list:
		if col.alive and not col.hidden and col.cell == cell:
			return false
	if sim.order_move(sel.id, cell):
		hud.show_message("Идти сюда", 2.0)
	return true
# endregion


# region A2d
const BELT_TOOLS := ["belt", "belt_remove", "belt_rotate"]
var auto_panel: AutomationPanel
var _stroke: Array[Vector2i] = []
var _stroke_on := false
var _belt_history: Array = []  ## placed paths (Array of Array[Vector2i]), newest last


func _setup_automation() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	auto_panel = AutomationPanel.new()
	auto_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	auto_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	auto_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	layer.add_child(auto_panel)
	auto_panel.tool_picked.connect(_on_auto_tool)
	auto_panel.undo_pressed.connect(undo_belt)
	camera.stroke_began.connect(func(p: Vector2) -> void: stroke_begin(WorldView.world_to_cell(p)))
	camera.stroke_moved.connect(func(p: Vector2) -> void: stroke_move(WorldView.world_to_cell(p)))
	camera.stroke_ended.connect(func(p: Vector2, cancelled: bool) -> void: stroke_end(WorldView.world_to_cell(p), cancelled))


func _on_auto_tool(id: String) -> void:
	hud.select_tool("inspect")  # moves the HUD radio group off its old tool
	_on_tool_selected(id)
	camera.capture_drag = id in BELT_TOOLS
	match id:
		"belt":
			hud.show_message("Belt: drag to paint a path. Red cells are blocked.", 5.0)
		"belt_remove":
			hud.show_message("Remove belt: drag over belts.", 5.0)
		"belt_rotate":
			hud.show_message("Rotate belt: tap a belt to turn it 90 degrees.", 5.0)


func _leave_belt_tools() -> void:
	if camera != null:
		camera.capture_drag = false
	if auto_panel != null and tool not in BELT_TOOLS and tool not in AutomationPanel.MACHINES.map(func(m: Array) -> String: return m[0]):
		auto_panel.clear_selection()
	_belt_reset()


func _belt_reset() -> void:
	_stroke.clear()
	_stroke_on = false
	if world != null:
		world.belt_draft.clear()
		world.belt_bad.clear()


func _refresh_belt_preview() -> void:
	world.belt_draft = _stroke.duplicate()
	world.belt_bad.clear()
	if tool == "belt":
		for c in _stroke:
			if sim.can_belt_cell_error(c) != "":
				world.belt_bad[c] = true
	world.belt_last_dir = AutomationPanel.path_last_dir(_stroke, world.belt_last_dir)
	world.queue_redraw()


func stroke_begin(cell: Vector2i) -> void:
	if sim == null or tool not in BELT_TOOLS:
		return
	_stroke.clear()
	_stroke_on = true
	if sim.map.in_bounds(cell):
		_stroke.append(cell)
	_refresh_belt_preview()


func stroke_move(cell: Vector2i) -> void:
	if not _stroke_on or _stroke.is_empty():
		return
	cell = Vector2i(clampi(cell.x, 0, sim.map.width - 1), clampi(cell.y, 0, sim.map.height - 1))
	if tool == "belt":
		AutomationPanel.extend_path(_stroke, cell)
	elif cell != _stroke[-1]:
		AutomationPanel.extend_path(_stroke, cell)
	_refresh_belt_preview()


func stroke_end(cell: Vector2i, cancelled: bool) -> void:
	if not _stroke_on:
		return
	if not cancelled:
		stroke_move(cell)
		_commit_stroke()
	_belt_reset()
	world.queue_redraw()


func _commit_stroke() -> void:
	var path: Array[Vector2i] = _stroke.duplicate()
	if path.is_empty():
		return
	match tool:
		"belt":
			var last := AutomationPanel.path_last_dir(path, world.belt_last_dir)
			for c in path:
				if sim.can_belt_cell_error(c) != "":
					hud.show_message("Can't build a belt there (blocked).", 3.0)
					return
			if sim.place_belt(path, last):
				_belt_history.append(path)
				world.belt_last_dir = last
				hud.show_message("Belt placed: %d cells." % path.size(), 2.0)
			else:
				hud.show_message("Can't build a belt there.", 3.0)
		"belt_remove":
			if sim.remove_belt(path):
				hud.show_message("Belt removed.", 2.0)
			else:
				hud.show_message("No belts there.", 2.0)
		"belt_rotate":
			var c: Vector2i = path[0]
			var d: int = sim.logistics.dir_at(c)
			if d < 0:
				hud.show_message("No belt there.", 2.0)
			else:
				sim.set_belt_dir(c, (d + 1) % 4)


## Removes the most recently placed belt path.
func undo_belt() -> void:
	if sim == null or _belt_history.is_empty():
		if hud != null:
			hud.show_message("Nothing to undo.", 2.0)
		return
	var path: Array = _belt_history.pop_back()
	sim.remove_belt(path)
	hud.show_message("Last belt path removed.", 2.0)
# endregion
