class_name Hud
extends CanvasLayer
## Touch-first HUD: big buttons, no hover, no right click.
## Reads sim state every frame; sends player intent to GameController via signals.

signal tool_selected(tool: String)
signal speed_selected(speed: int)
signal alarm_toggled(on: bool)
signal rule_toggled(rule_id: String, on: bool)
signal new_game_requested()
signal colonist_card_pressed(colonist_id: int)
signal focus_cell_requested(cell: Vector2i)

const TOAST_MAX_QUEUE := 4
const PANEL_REFRESH := 0.25

const BTN_MIN := Vector2(96, 88)
const SIDE_W := 340
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
	["workbench", "Верстак", "refinery"],
	["deconstruct", "Снести", ""],
	["wall", "Стена", "wall"],  # region construction
	["door", "Дверь", "door"],  # region construction
	# region needs
	["growing", "Грядки", "plant_ripe"],
	["stove", "Печь", "stove"],
	["bed", "Кровать", "bed"],
	# endregion
]
const COMPACT_H := 500.0  ## logical viewport height below which the compact layout is used
const BAR_H := 64.0
## Compact bottom bar: category -> [label, tool ids]. "alarm" and rule ids are handled separately.
const CATS: Array = [
	["zones", "Зоны", ["stockpile", "waste_dump", "clear_zone", "growing"]],
	["build", "Стройка", ["refinery", "turret", "workbench", "wall", "door", "stove", "bed", "deconstruct"]],
	["orders", "Приказы", ["mine", "@rules"]],
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
var _clock: Label
var _stack: VBoxContainer
var _colonist_bar: ColonistBar
var _letters := LetterLog.new()
var _letters_btn: Button
var _panel_buttons := {}  # panel id -> Button
var _side: GamePanel = null
var _side_id := ""
var _inspector: InspectorPanel = null
var _root: Control
var _panel_timer := 0.0
var _toasts: Array[Array] = []  # [text, seconds]
var _tool_buttons := {}
var _speed_buttons: Array[Button] = []
var _alarm_btn: Button
var _rule_buttons := {}  # rule id -> Button
var _game_over: PanelContainer
var _game_over_label: Label
var _message_until := 0.0
var _compact := false
var _top_flow: HFlowContainer
var _panel_row: HBoxContainer
var _tools_row: HBoxContainer
var _tools_scroll: ScrollContainer
var _bottom: PanelContainer
var _cat_row: HBoxContainer
var _cat_popup: PanelContainer
var _cat_popup_row: HBoxContainer
var _cat_buttons := {}  # category id -> Button
var _open_cat := ""
var _stash: Control
var _menu_btn: Button
var _menu_popup: PanelContainer
var _menu_box: VBoxContainer
var _colonist_dock: PanelContainer
var _tool_order: Array[Button] = []
var _inspect_btn_ref: Button
var _bottom_inset := BTN_MIN.y + 24


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)

	# --- Top bar: stats + speed (wraps on narrow screens) ---
	_root = root
	_stack = VBoxContainer.new()
	_stack.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.add_theme_constant_override("separation", 2)
	root.add_child(_stack)
	var top := PanelContainer.new()
	_stack.add_child(top)
	var top_flow := HFlowContainer.new()
	_top_flow = top_flow
	top_flow.add_theme_constant_override("h_separation", 6)
	top_flow.add_theme_constant_override("v_separation", 4)
	top.add_child(top_flow)
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.custom_minimum_size.x = 430
	labels.add_theme_constant_override("separation", 0)
	top_flow.add_child(labels)
	_clock = _label(labels)
	_clock.visible = false
	_stats = _label(labels)
	_forecast = _label(labels)
	_forecast.add_theme_font_size_override("font_size", 16)
	_threat = _label(labels)
	var speed_row := HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 4)
	top_flow.add_child(speed_row)
	for i in 4:
		var b := _button(speed_row, "||" if i == 0 else "%dx" % i, Vector2(56, 64))
		b.toggle_mode = true
		b.pressed.connect(func() -> void: speed_selected.emit(i))
		_speed_buttons.append(b)

	# --- Panel bar (letters + registered panels) ---
	var panel_row := HBoxContainer.new()
	_panel_row = panel_row
	panel_row.add_theme_constant_override("separation", 4)
	top_flow.add_child(panel_row)
	_letters_btn = _button(panel_row, "Письма", Vector2(84, 64))
	_letters_btn.add_theme_font_size_override("font_size", 17)
	_letters_btn.pressed.connect(func() -> void: toggle_panel("letters"))
	for e: Array in PanelRegistry.panel_entries():
		var pid: String = e[0]
		var pb := _button(panel_row, str(e[1]), Vector2(84, 64))
		pb.add_theme_font_size_override("font_size", 17)
		pb.pressed.connect(func() -> void: toggle_panel(pid))
		_panel_buttons[pid] = pb

	_menu_btn = _button(speed_row, "Ещё", Vector2(88, 64))
	_menu_btn.pressed.connect(func() -> void: _menu_popup.visible = not _menu_popup.visible)
	_menu_btn.visible = false

	# --- Colonist bar ---
	_colonist_bar = ColonistBar.new()
	_colonist_bar.colonist_pressed.connect(func(id: int) -> void: colonist_card_pressed.emit(id))
	_stack.add_child(_colonist_bar)

	# --- Bottom bar: tools + alarm ---
	var bottom := PanelContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(bottom)
	_bottom = bottom
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = BTN_MIN.y + 8
	bottom.add_child(scroll)
	_tools_scroll = scroll
	var tools_row := HBoxContainer.new()
	_tools_row = tools_row
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
		_tool_order.append(b)
	_alarm_btn = _button(tools_row, "Тревога", BTN_MIN, "capsule")
	_alarm_btn.toggle_mode = true
	_alarm_btn.toggled.connect(func(on: bool) -> void: alarm_toggled.emit(on))
	_tool_order.append(_alarm_btn)
	var rules: Dictionary = Defs.get_default().rules
	for rule_id: String in rules:
		var rb := _button(tools_row, str(rules[rule_id]["short"]), BTN_MIN, "colonist_engineer")
		rb.toggle_mode = true
		rb.toggled.connect(func(on: bool) -> void: rule_toggled.emit(rule_id, on))
		_rule_buttons[rule_id] = rb
		_tool_order.append(rb)
	_build_compact_widgets(root, group)

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
	get_viewport().size_changed.connect(_check_layout)
	_check_layout()


## Overlay widgets used only by the compact (small-height) layout.
func _build_compact_widgets(root: Control, group: ButtonGroup) -> void:
	_cat_row = HBoxContainer.new()
	_cat_row.add_theme_constant_override("separation", 6)
	_inspect_btn_ref = _tool_buttons["inspect"]
	for c: Array in CATS:
		var cid: String = c[0]
		var cb := Button.new()
		cb.text = str(c[1])
		cb.custom_minimum_size = Vector2(120, BAR_H)
		cb.focus_mode = Control.FOCUS_NONE
		cb.pressed.connect(func() -> void: _toggle_cat(cid))
		_cat_buttons[cid] = cb
	_cat_popup = PanelContainer.new()
	_cat_popup.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_cat_popup.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_cat_popup.visible = false
	root.add_child(_cat_popup)
	var sc := ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_cat_popup.add_child(sc)
	_cat_popup_row = HBoxContainer.new()
	_cat_popup_row.add_theme_constant_override("separation", 6)
	sc.add_child(_cat_popup_row)
	_menu_popup = PanelContainer.new()
	_menu_popup.visible = false
	root.add_child(_menu_popup)
	_menu_box = VBoxContainer.new()
	_menu_popup.add_child(_menu_box)
	_stash = Control.new()
	_stash.visible = false
	root.add_child(_stash)
	for tb: Button in _tool_order:
		tb.pressed.connect(func() -> void:
			if tb != _alarm_btn and not _rule_buttons.values().has(tb):
				_close_cat())
	_colonist_dock = PanelContainer.new()
	_colonist_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var flat := StyleBoxEmpty.new()
	_colonist_dock.add_theme_stylebox_override("panel", flat)
	root.add_child(_colonist_dock)


func _check_layout() -> void:
	var h := get_viewport().get_visible_rect().size.y
	var want := h < COMPACT_H
	if want != _compact or _cat_popup_row.get_parent() == null:
		_apply_layout(want)


func _reparent_to(n: Control, to: Node) -> void:
	if n.get_parent() != null:
		n.get_parent().remove_child(n)
	to.add_child(n)


func _apply_layout(compact: bool) -> void:
	_compact = compact
	_open_cat = ""
	_cat_popup.visible = false
	_menu_popup.visible = false
	for b: Button in _tool_order:
		_reparent_to(b, _stash if compact else _tools_row)
	for cid: String in _cat_buttons:
		if _cat_buttons[cid].get_parent() != null:
			_cat_buttons[cid].get_parent().remove_child(_cat_buttons[cid])
	for b: Button in [_letters_btn] + _panel_buttons.values():
		_reparent_to(b, _panel_row)
	_reparent_to(_colonist_bar, _stack)
	_colonist_dock.visible = compact
	_menu_btn.visible = compact
	_panel_row.visible = not compact
	if _cat_row.get_parent() != null:
		_cat_row.get_parent().remove_child(_cat_row)
	if compact:
		_top_flow.get_child(0).custom_minimum_size.x = 150
		_bottom_inset = BAR_H + 22
		_message.offset_top = -(BAR_H + 90)
		_message.offset_bottom = -(BAR_H + 24)
		_tools_scroll.custom_minimum_size.y = BAR_H + 4
		_tools_row.add_theme_constant_override("separation", 6)
		# bottom bar: Осмотр, categories, alarm
		_tools_row.add_child(_cat_row)
		_reparent_to(_tool_buttons["inspect"], _cat_row)
		_tool_buttons["inspect"].custom_minimum_size = Vector2(110, BAR_H)
		for cid: String in _cat_buttons:
			_cat_row.add_child(_cat_buttons[cid])
		_reparent_to(_alarm_btn, _cat_row)
		_alarm_btn.custom_minimum_size = Vector2(110, BAR_H)
		for b: Button in _panel_buttons.values() + [_letters_btn]:
			_reparent_to(b, _menu_box)
			b.custom_minimum_size = Vector2(150, BAR_H)
		_reparent_to(_colonist_bar, _colonist_dock)
		_colonist_bar.set_compact(true)
	else:
		_top_flow.get_child(0).custom_minimum_size.x = 430
		_bottom_inset = BTN_MIN.y + 24
		_message.offset_top = -(BTN_MIN.y + 110)
		_message.offset_bottom = -(BTN_MIN.y + 24)
		_tools_scroll.custom_minimum_size.y = BTN_MIN.y + 8
		_tools_row.add_theme_constant_override("separation", 8)
		for b: Button in _tool_order:
			b.custom_minimum_size = BTN_MIN
		for b: Button in [_letters_btn] + _panel_buttons.values():
			b.custom_minimum_size = Vector2(84, 64)
		_colonist_bar.set_compact(false)
	_place_side()


func _toggle_cat(cid: String) -> void:
	var was := _open_cat
	_close_cat()
	if was == cid:
		return
	_open_cat = cid
	for c: Array in CATS:
		if c[0] != cid:
			continue
		for tid: String in c[2]:
			if tid == "@rules":
				for rb: Button in _rule_buttons.values():
					_reparent_to(rb, _cat_popup_row)
					rb.custom_minimum_size = Vector2(96, 72)
			elif _tool_buttons.has(tid):
				_reparent_to(_tool_buttons[tid], _cat_popup_row)
				_tool_buttons[tid].custom_minimum_size = Vector2(96, 72)
	_cat_popup.offset_bottom = -(BAR_H + 22)
	_cat_popup.visible = true
	_cat_buttons[cid].modulate = Color(0.8, 0.6, 1.0)


func _close_cat() -> void:
	if _open_cat == "":
		return
	for ch in _cat_popup_row.get_children():
		_reparent_to(ch, _stash)
	_cat_popup.visible = false
	for cb: Button in _cat_buttons.values():
		cb.modulate = Color.WHITE
	_open_cat = ""


func _exit_tree() -> void:
	_letters.unbind()


func bind(p_sim: Simulation) -> void:
	sim = p_sim
	_game_over.visible = false
	_alarm_btn.set_pressed_no_signal(false)
	close_side()
	_toasts.clear()
	_message.text = ""
	_letters.bind(p_sim, p_sim.bus)
	if not _letters.letter_added.is_connected(_on_letter):
		_letters.letter_added.connect(_on_letter)
	_colonist_bar.bind(p_sim)


func select_tool(id: String) -> void:
	if _tool_buttons.has(id):
		_tool_buttons[id].set_pressed_no_signal(true)


func set_speed(speed: int) -> void:
	for i in _speed_buttons.size():
		_speed_buttons[i].set_pressed_no_signal(i == speed)


## Queues a toast; shown one after another.
func show_message(text: String, seconds := 3.0) -> void:
	if text == "":
		return
	if not _toasts.is_empty() and _toasts[-1][0] == text:
		return
	_toasts.append([text, seconds])
	while _toasts.size() > TOAST_MAX_QUEUE:
		_toasts.pop_front()
	if _message.text == "":
		_next_toast()


func _next_toast() -> void:
	if _toasts.is_empty():
		_message.text = ""
		return
	var t: Array = _toasts.pop_front()
	_message.text = t[0]
	# Shorten the toast when more are waiting.
	_message_until = Time.get_ticks_msec() / 1000.0 + (minf(float(t[1]), 2.5) if not _toasts.is_empty() else float(t[1]))


func _on_letter(entry: Dictionary) -> void:
	show_message(str(entry["text"]), 5.0)


## Opens the inspector for {"kind", "colonist", "building", "cell"}; empty closes it.
func show_inspector(target: Dictionary) -> void:
	if target.is_empty():
		if _side_id == "inspector":
			close_side()
		return
	if _inspector == null or _side != _inspector:
		_open_side(_inspector_panel(), "inspector")
	_inspector.set_target(target)


func _inspector_panel() -> InspectorPanel:
	if _inspector == null:
		_inspector = InspectorPanel.new()
	return _inspector


func toggle_panel(id: String) -> void:
	if _side_id == id:
		close_side()
		return
	var p: GamePanel
	if id == "letters":
		var lp := LettersPanel.new()
		lp.bind_log(_letters)
		lp.show_cell_requested.connect(func(c: Vector2i) -> void: focus_cell_requested.emit(c))
		p = lp
	else:
		p = PanelRegistry.make_panel(id)
	if p != null:
		_open_side(p, id)


func _open_side(p: GamePanel, id: String) -> void:
	close_side()
	if _menu_popup != null:
		_menu_popup.visible = false
	_side = p
	_side_id = id
	p.close_requested.connect(close_side)
	p.anchor_left = 1.0
	p.anchor_right = 1.0
	p.anchor_top = 0.0
	p.anchor_bottom = 1.0
	var sw := 300 if _compact else SIDE_W
	p.offset_left = -sw - 8
	p.offset_right = -8
	p.offset_bottom = -_bottom_inset
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_root.add_child(p)
	_place_side()
	p.open(sim)
	if id == "letters":
		_letters.mark_read()
	_sync_panel_buttons()


func close_side() -> void:
	if _side != null and is_instance_valid(_side):
		if _side == _inspector:
			_root.remove_child(_side)
		else:
			_side.queue_free()
	_side = null
	_side_id = ""
	_sync_panel_buttons()


func _place_side() -> void:
	if _compact and _colonist_dock != null:
		_colonist_dock.anchor_left = 0.0
		_colonist_dock.anchor_right = 0.0
		_colonist_dock.anchor_top = 0.0
		_colonist_dock.anchor_bottom = 1.0
		_colonist_dock.offset_left = 0
		_colonist_dock.offset_right = 84
		_colonist_dock.offset_top = _stack.size.y + 4
		_colonist_dock.offset_bottom = -_bottom_inset
	if _menu_popup != null:
		_menu_popup.anchor_left = 1.0
		_menu_popup.anchor_right = 1.0
		_menu_popup.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_menu_popup.offset_right = -8
		_menu_popup.offset_top = _stack.size.y + 4
	if _side != null:
		_side.offset_top = _stack.size.y + 4
		_side.offset_bottom = -_bottom_inset


func _sync_panel_buttons() -> void:
	if _letters_btn:
		_letters_btn.modulate = Color(0.8, 0.6, 1.0) if _side_id == "letters" else Color.WHITE
	for pid: String in _panel_buttons:
		_panel_buttons[pid].modulate = Color(0.8, 0.6, 1.0) if _side_id == pid else Color.WHITE


func show_game_over(reason: String) -> void:
	_game_over_label.text = "%s\nПродержались %d дн." % [REASONS.get(reason, reason), sim.day()]
	_game_over.visible = true


func _process(delta: float) -> void:
	if sim == null:
		return
	var it := sim.items
	var night: bool = sim.clock.is_night()
	_clock.text = "%s %d, %02d:%02d" % ["Ночь" if night else "День", sim.day() + 1, sim.clock.hour_int(), int(fposmod(sim.clock.hour(), 1.0) * 60.0)]
	_stats.text = _clock.text + " · Руда %d · Эсс. %d · Отх. %d · Люди %d" % [
		it.count_stored("essence_ore"), it.count_stored("refined_essence"),
		it.count_world("waste"), sim.colonists.alive_count()]
	var cont := sim.contamination
	if cont.revealed:
		var f := cont.forecast()
		_forecast.text = "Заражение %.1f%% · конец ~%.0f±%.0f дн." % [cont.fraction() * 100.0, f["days"], f["error"]]
	else:
		_forecast.text = "Заражение %.1f%% · прогноз неизвестен" % (cont.fraction() * 100.0)
	_threat.text = ""
	_threat.visible = false
	_forecast.text += " · " + _threat_text()
	_alarm_btn.set_pressed_no_signal(sim.alarm)
	for rule_id: String in _rule_buttons:
		_rule_buttons[rule_id].set_pressed_no_signal(sim.is_rule_on(rule_id))
	if _message.text != "" and Time.get_ticks_msec() / 1000.0 > _message_until:
		_message.text = ""
		_next_toast()
	_letters_btn.text = "Письма (%d)" % _letters.unread if _letters.unread > 0 else "Письма"
	_place_side()
	_panel_timer += delta
	if _panel_timer >= PANEL_REFRESH:
		_panel_timer = 0.0
		_colonist_bar.refresh()
		if _side != null:
			_side.refresh()
			if _side_id == "letters":
				_letters.mark_read()


func _threat_text() -> String:
	if sim.get("threats") == null or sim.threats == null:
		return ""
	var t: ThreatSystem = sim.threats
	if t.wave_active:
		return "ВОЛНА %d: тварей %d (с %s)" % [t.wave_index, t.enemies.size(), t.side_name(t.next_spawn_origin)]
	if not t.awakened:
		return "Твари спят"
	var ticks := t.next_wave_tick - sim.tick
	var side := " с %s" % t.side_name(t.next_spawn_origin) if ticks < int(t.cfg["warning_ticks"]) else ""
	return "Волна через %.1f ч%s, сила ~%.0f" % [ticks * 24.0 / sim.ticks_per_day, side, t.wave_strength(t.wave_index + 1)]


func _label(parent: Control) -> Label:
	var l := Label.new()
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.12, 0.15)
	th.set_stylebox("background", "ProgressBar", bg)
	return th
