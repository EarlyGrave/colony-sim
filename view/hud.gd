class_name Hud
extends CanvasLayer
## Touch-first HUD: big buttons, no hover, no right click.
## Reads sim state every frame; sends player intent to GameController via signals.

signal tool_selected(tool: String)
signal speed_selected(speed: int)
signal alarm_toggled(on: bool)
signal rule_toggled(rule_id: String, on: bool)
signal new_game_requested()

const BTN_MIN := Vector2(96, 88)
const SPR := "res://assets/sprites/"
## [tool id, label, icon sprite or ""]
const TOOLS: Array = [
	["inspect", "Осмотр", ""],
	["mine", "Добыча", "designation_mine"],
	["stockpile", "Склад", "item_ore"],
	["waste_dump", "Свалка", "item_waste"],
	["clear_zone", "Убрать", ""],
	["refinery", "Установка", "refinery"],
	["turret", "Турель", "turret_base"],
	["deconstruct", "Снести", ""],
]
const REASONS := {
	"hq_destroyed": "Капсула разрушена. Колония пала.",
	"colonists_dead": "Все колонисты погибли.",
	"planet_dead": "Планета погибла от заражения.",
}

var sim: Simulation
var _stats: Label
var _forecast: Label
var _threat: Label
var _message: Label
var _info: Label
var _tool_buttons := {}
var _speed_buttons: Array[Button] = []
var _alarm_btn: Button
var _rule_buttons := {}  # rule id -> Button
var _game_over: PanelContainer
var _game_over_label: Label
var _message_until := 0.0


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)

	# --- Top bar: stats + speed (wraps on narrow screens) ---
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	root.add_child(top)
	var top_flow := HFlowContainer.new()
	top_flow.add_theme_constant_override("h_separation", 12)
	top_flow.add_theme_constant_override("v_separation", 4)
	top.add_child(top_flow)
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.custom_minimum_size.x = 300
	labels.add_theme_constant_override("separation", 0)
	top_flow.add_child(labels)
	_stats = _label(labels)
	_forecast = _label(labels)
	_threat = _label(labels)
	var speed_row := HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 8)
	top_flow.add_child(speed_row)
	for i in 4:
		var b := _button(speed_row, "||" if i == 0 else "%dx" % i, Vector2(72, 64))
		b.toggle_mode = true
		b.pressed.connect(func() -> void: speed_selected.emit(i))
		_speed_buttons.append(b)

	# --- Bottom bar: tools + alarm ---
	var bottom := PanelContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(bottom)
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = BTN_MIN.y + 8
	bottom.add_child(scroll)
	var tools_row := HBoxContainer.new()
	tools_row.add_theme_constant_override("separation", 8)
	scroll.add_child(tools_row)
	var group := ButtonGroup.new()
	for t in TOOLS:
		var b := _button(tools_row, t[1], BTN_MIN, t[2])
		b.toggle_mode = true
		b.button_group = group
		var id: String = t[0]
		b.pressed.connect(func() -> void: tool_selected.emit(id))
		_tool_buttons[id] = b
	_alarm_btn = _button(tools_row, "Тревога", BTN_MIN, "capsule")
	_alarm_btn.toggle_mode = true
	_alarm_btn.toggled.connect(func(on: bool) -> void: alarm_toggled.emit(on))
	var rules: Dictionary = Defs.get_default().rules
	for rule_id: String in rules:
		var rb := _button(tools_row, str(rules[rule_id]["short"]), BTN_MIN, "colonist_engineer")
		rb.toggle_mode = true
		rb.toggled.connect(func(on: bool) -> void: rule_toggled.emit(rule_id, on))
		_rule_buttons[rule_id] = rb

	# --- Message line above the bottom bar ---
	_message = Label.new()
	_message.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_message.offset_left = 12
	_message.offset_right = -12
	_message.offset_top = -(BTN_MIN.y + 110)
	_message.offset_bottom = -(BTN_MIN.y + 24)
	_message.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_color_override("font_outline_color", Color.BLACK)
	_message.add_theme_constant_override("outline_size", 6)
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_message)

	# --- Inspector (right side) ---
	var info_panel := PanelContainer.new()
	info_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	info_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(info_panel)
	_info = Label.new()
	_info.custom_minimum_size = Vector2(260, 0)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_panel.add_child(_info)
	info_panel.visible = false
	_info.set_meta("panel", info_panel)

	# --- Game over overlay ---
	_game_over = PanelContainer.new()
	_game_over.set_anchors_preset(Control.PRESET_CENTER)
	_game_over.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_game_over.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(_game_over)
	var go_box := VBoxContainer.new()
	go_box.add_theme_constant_override("separation", 16)
	_game_over.add_child(go_box)
	_game_over_label = Label.new()
	_game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go_box.add_child(_game_over_label)
	var again := _button(go_box, "Новая ссылка", Vector2(260, 80))
	again.pressed.connect(func() -> void: new_game_requested.emit())
	_game_over.visible = false

	select_tool("inspect")


func bind(p_sim: Simulation) -> void:
	sim = p_sim
	_game_over.visible = false
	_alarm_btn.set_pressed_no_signal(false)
	show_info("")


func select_tool(id: String) -> void:
	if _tool_buttons.has(id):
		_tool_buttons[id].set_pressed_no_signal(true)


func set_speed(speed: int) -> void:
	for i in _speed_buttons.size():
		_speed_buttons[i].set_pressed_no_signal(i == speed)


func show_message(text: String, seconds := 3.0) -> void:
	_message.text = text
	_message_until = Time.get_ticks_msec() / 1000.0 + seconds


func show_info(text: String) -> void:
	_info.text = text
	(_info.get_meta("panel") as Control).visible = text != ""


func show_game_over(reason: String) -> void:
	_game_over_label.text = "%s\nПродержались %d дн." % [REASONS.get(reason, reason), sim.day()]
	_game_over.visible = true


func _process(_delta: float) -> void:
	if sim == null:
		return
	var it := sim.items
	_stats.text = "День %d · Руда %d · Эссенция %d · Отходы %d · Люди %d" % [
		sim.day() + 1, it.count_stored("essence_ore"), it.count_stored("refined_essence"),
		it.count_world("waste"), sim.colonists.alive_count()]
	var cont := sim.contamination
	if cont.revealed:
		var f := cont.forecast()
		_forecast.text = "Заражение %.1f%% · Конец через ~%.0f ± %.0f дн." % [cont.fraction() * 100.0, f["days"], f["error"]]
	else:
		_forecast.text = "Заражение %.1f%% · Прогноз конца неизвестен" % (cont.fraction() * 100.0)
	_threat.text = _threat_text()
	_alarm_btn.set_pressed_no_signal(sim.alarm)
	for rule_id: String in _rule_buttons:
		_rule_buttons[rule_id].set_pressed_no_signal(sim.is_rule_on(rule_id))
	if _message.text != "" and Time.get_ticks_msec() / 1000.0 > _message_until:
		_message.text = ""


func _threat_text() -> String:
	if sim.get("threats") == null or sim.threats == null:
		return ""
	var t: ThreatSystem = sim.threats
	if t.wave_active:
		return "ВОЛНА %d: тварей %d" % [t.wave_index, t.enemies.size()]
	if not t.awakened:
		return "Твари спят"
	var ticks := t.next_wave_tick - sim.tick
	return "Волна через %.1f ч, сила ~%.0f" % [ticks * 24.0 / sim.ticks_per_day, t.wave_strength(t.wave_index + 1)]


func _label(parent: Control) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


func _button(parent: Control, text: String, min_size: Vector2, icon := "") -> Button:
	var b := Button.new()
	b.text = text
	if icon != "":
		b.icon = load(SPR + icon + ".png")
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_constant_override("icon_max_width", 36)
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	parent.add_child(b)
	return b


func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 20
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.06, 0.06, 0.08, 0.82)
	panel.set_content_margin_all(8)
	th.set_stylebox("panel", "PanelContainer", panel)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.2, 0.2, 0.25)
	normal.set_corner_radius_all(8)
	normal.set_content_margin_all(6)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.55, 0.35, 0.75)
	th.set_stylebox("normal", "Button", normal)
	th.set_stylebox("hover", "Button", normal)
	th.set_stylebox("pressed", "Button", pressed)
	th.set_stylebox("hover_pressed", "Button", pressed)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	return th
