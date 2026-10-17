class_name GameController
extends Node
## Owns the running Simulation, drives fixed ticks at the chosen speed and
## wires view + HUD. Player input becomes Simulation commands here.

const MAX_TICKS_PER_FRAME := 40
const RECT_TOOLS := ["mine", "stockpile", "waste_dump", "clear_zone"]
const BUILD_TOOLS := ["refinery", "turret"]
const HINTS := {
	"inspect": "Нажми на клетку, чтобы посмотреть, что там.",
	"mine": "Добыча: нажми два угла области с рудой (фиолетовое).",
	"stockpile": "Склад: нажми два угла области.",
	"waste_dump": "Свалка отходов: нажми два угла области. Отходы там заражают слабее.",
	"clear_zone": "Убрать зону: нажми два угла области.",
}

var sim: Simulation
var speed := 1
var tool := "inspect"
var _accum := 0.0

@onready var world: WorldView = $World
@onready var camera: CameraController = $Camera
@onready var hud: Hud = $Hud


func _ready() -> void:
	_apply_ui_scale()
	camera.tapped.connect(_on_tapped)
	hud.tool_selected.connect(_on_tool_selected)
	hud.speed_selected.connect(set_speed)
	hud.alarm_toggled.connect(func(on: bool) -> void: sim.set_alarm(on))
	hud.rule_toggled.connect(func(id: String, on: bool) -> void:
		sim.set_rule(id, on)
		hud.show_message(("Правило включено: " if on else "Правило выключено: ") + str(sim.defs.rules[id]["name"]), 4.0))
	hud.new_game_requested.connect(func() -> void: new_game(_random_seed()))
	EventBus.story_event.connect(func(_id: String, text: String) -> void: hud.show_message(text, 5.0))
	EventBus.game_over.connect(func(reason: String) -> void: hud.show_game_over(reason))
	new_game(_initial_seed())


## Scales the whole 2D/UI by screen density so touch targets keep a physical
## size: ~0.85 CSS px per logical px on phones/tablets, 1:1 on desktop.
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


func new_game(seed_value: int) -> void:
	if sim:
		world.unbind()
		sim.dispose()
	sim = Simulation.new(seed_value, EventBus)
	sim.start_new_game()
	world.bind(sim)
	world.pending_corner = Vector2i(-1, -1)
	world.selected_cell = Vector2i(-1, -1)
	hud.bind(sim)
	camera.world_size = world.world_size()
	camera.position = WorldView.cell_to_world(sim.map_center())
	camera.zoom = Vector2(1, 1)
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
	world.pending_corner = Vector2i(-1, -1)
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
			hud.show_message("Построено: " + str(sim.defs.buildings[tool]["name"]), 3.0)
		else:
			hud.show_message(err, 3.0)
	elif tool == "deconstruct":
		if sim.deconstruct(cell):
			hud.show_message("Снесено", 3.0)
		else:
			hud.show_message("Здесь нечего сносить", 3.0)
	else:
		world.selected_cell = cell
		hud.show_info(_describe_cell(cell))


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


func _describe_cell(c: Vector2i) -> String:
	var lines: Array[String] = []
	var b := sim.buildings.at(c)
	if b:
		lines.append("%s\nПрочность %d/%d" % [b.def["name"], b.hp, b.max_hp])
		if b.is_machine():
			lines.append("Износ: состояние %d%%%s" % [b.condition, "  СЛОМАНА" if b.broken else ""])
		if not b.recipe.is_empty():
			lines.append("Вход: %s\nВыход: %s" % [_fmt_items(b.input), _fmt_items(b.output)])
	for col in sim.colonists.list:
		if col.alive and col.cell == c and not col.hidden:
			var status := "болен" if col.is_sick(sim.tick) else (col.job.describe() if col.job else "без дела")
			lines.append("%s%s: здоровье %d, %s" % [col.display_name, " (инженер)" if col.engineer else "", col.hp, status])
	match sim.map.get_tile(c):
		MapGrid.Tile.ROCK:
			lines.append("Скала")
		MapGrid.Tile.DEPOSIT:
			lines.append("Месторождение эссенции: %d" % sim.map.get_deposit_amount(c))
	var st := sim.items.get_stack(c)
	if not st.is_empty():
		lines.append("%s × %d" % [sim.defs.items[st["item"]]["name"], st["count"]])
	var z := sim.map.get_zone(c)
	if z != "":
		lines.append("Зона: " + str(sim.defs.zones[z]["name"]))
	if lines.is_empty():
		lines.append("Грунт")
	return "\n".join(lines)


func _fmt_items(d: Dictionary) -> String:
	if d.is_empty():
		return "—"
	var parts: Array[String] = []
	for k in d:
		parts.append("%s %d" % [sim.defs.items[k]["name"], d[k]])
	return ", ".join(parts)
