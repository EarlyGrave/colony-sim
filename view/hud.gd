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
signal patrol_done()
signal patrol_undo()
signal patrol_auto()
signal overlay_toggled(on: bool)

const TOAST_MAX_QUEUE := 4
const PANEL_REFRESH := 0.25

const BTN_MIN := Vector2(96, 88)
const SIDE_W := 340
const SPR := "res://assets/sprites/"
## [tool id, label, icon sprite or ""]
const TOOLS: Array = [
	["inspect", "Inspect", ""],
	["mine", "Mine", "designation_mine"],
	["stockpile", "Stockpile", "item_ore"],
	["waste_dump", "Dump", "item_waste"],
	["clear_zone", "Clear", ""],
	["refinery", "Refinery", "refinery"],
	["turret", "Turret", "turret_base"],
	["workbench", "Bench", "refinery"],
	["deconstruct", "Demolish", ""],
	["wall", "Wall", "wall"],  # region construction
	["door", "Door", "door"],  # region construction
	# region needs
	["growing", "Crops", "plant_ripe"],
	["stove", "Stove", "stove"],
	["bed", "Bunk", "bed"],
	# endregion
	["training_dummy", "Dummy", ""],  # region batch3 ui
	["patrol", "Patrol", ""],
	["overlay", "Taint", ""],
]
const COMPACT_H := 500.0  ## logical viewport height below which the compact layout is used
const BAR_H := 64.0
## Compact bottom bar: category -> [label, tool ids]. "alarm" and rule ids are handled separately.
const CATS: Array = [
	["zones", "Zones", ["stockpile", "waste_dump", "clear_zone", "growing"]],
	["build", "Build", ["refinery", "turret", "workbench", "wall", "door", "stove", "bed", "training_dummy", "deconstruct"]],
	["orders", "Orders", ["mine", "patrol", "overlay", "@rules"]],
]
const REASONS := {
	"hq_destroyed": "The pod is destroyed. The colony has fallen.",
	"colonists_dead": "All colonists are dead.",
	"planet_dead": "The planet died of contamination.",
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
var _menu_box: GridContainer
var _colonist_dock: PanelContainer
var _tool_order: Array[Button] = []
var _inspect_btn_ref: Button
var _forecast_bar: ForecastBar
var _contract_btn: Button
var _alerts: AlertCenter
var _patrol_bar: PanelContainer
var _legend: PanelContainer
var _overlay_on := true
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
	_t5_build_strip()  # region T5
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
	_forecast.add_theme_font_size_override("font_size", 20)
	_forecast_bar = ForecastBar.new()
	labels.add_child(_forecast_bar)
	_threat = _label(labels)
	labels.move_child(_forecast_bar, _forecast.get_index() + 1)
	var speed_row := HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 4)
	top_flow.add_child(speed_row)
	_contract_btn = _button(speed_row, "Contract", Vector2(120, 64))
	_contract_btn.add_theme_font_size_override("font_size", 16)
	_contract_btn.pressed.connect(func() -> void: toggle_panel("contracts"))
	_contract_btn.visible = false
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
	_letters_btn = _button(panel_row, "Letters", Vector2(84, 64))
	_letters_btn.add_theme_font_size_override("font_size", 17)
	_letters_btn.pressed.connect(func() -> void: toggle_panel("letters"))
	for e: Array in PanelRegistry.panel_entries():
		var pid: String = e[0]
		var pb := _button(panel_row, str(e[1]), Vector2(84, 64))
		pb.add_theme_font_size_override("font_size", 17)
		pb.pressed.connect(func() -> void: toggle_panel(pid))
		_panel_buttons[pid] = pb

	_menu_btn = _button(speed_row, "More", Vector2(88, 64))
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
		var id: String = t[0]
		if id == "overlay":
			b.set_pressed_no_signal(true)
			b.toggled.connect(func(on: bool) -> void:
				_overlay_on = on
				overlay_toggled.emit(on))
		else:
			b.button_group = group
			b.pressed.connect(func() -> void:
				tool_selected.emit(id)
				_patrol_bar.visible = id == "patrol")
		_tool_buttons[id] = b
		_tool_order.append(b)
	_alarm_btn = _button(tools_row, "Alarm", BTN_MIN, "capsule")
	_alarm_btn.toggle_mode = true
	_alarm_btn.toggled.connect(func(on: bool) -> void: alarm_toggled.emit(on))
	_tool_order.append(_alarm_btn)
	var rules: Dictionary = Defs.get_default().rules
	for rule_id: String in rules:
		if rules[rule_id].get("hidden", false):  # region T3
			continue
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

	_build_batch3_widgets(root)

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
	var again := _button(go_box, "New Sentence", Vector2(260, 80))
	again.pressed.connect(func() -> void: new_game_requested.emit())
	_game_over.visible = false

	_o2_build(root)  # region O2
	root.move_child(_alerts, -1)
	select_tool("inspect")
	get_viewport().size_changed.connect(_check_layout)
	_check_layout()


# region batch3 ui
func _build_batch3_widgets(root: Control) -> void:
	_forecast_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_alerts = AlertCenter.new()
	root.add_child(_alerts)
	# Patrol route editor controls (shown while the patrol tool is active).
	_patrol_bar = PanelContainer.new()
	_patrol_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_patrol_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_patrol_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_patrol_bar.visible = false
	root.add_child(_patrol_bar)
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 8)
	_patrol_bar.add_child(prow)
	var pl := Label.new()
	pl.text = "Route: tap waypoints"
	pl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prow.add_child(pl)
	_button(prow, "Undo", Vector2(96, 64)).pressed.connect(func() -> void: patrol_undo.emit())
	_button(prow, "Done", Vector2(112, 64)).pressed.connect(func() -> void: patrol_done.emit())
	_button(prow, "Auto", Vector2(96, 64)).pressed.connect(func() -> void: patrol_auto.emit())
	# Contamination overlay legend.
	_legend = PanelContainer.new()
	_legend.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_legend.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_legend.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_legend)
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 6)
	_legend.add_child(lrow)
	for e: Array in [[Color(0.35, 0.8, 0.25, 0.8), "tainted"], [Color(0.6, 0.25, 0.8, 0.9), "mutated"]]:
		var sw := ColorRect.new()
		sw.color = e[0]
		sw.custom_minimum_size = Vector2(18, 18)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lrow.add_child(sw)
		var ll := Label.new()
		ll.text = e[1]
		ll.add_theme_font_size_override("font_size", 16)
		lrow.add_child(ll)


func _update_batch3() -> void:
	var cont := sim.contamination
	var f := cont.fraction()
	var ths := ForecastBar.thresholds(sim)
	var col := ForecastBar.tint(f, ths)
	_forecast.add_theme_color_override("font_color", col)
	var next_name := ""
	var next_m := 9.0
	for id: String in sim.defs.crises["crises"]:
		var t := float(sim.defs.crises["crises"][id]["threshold"])
		if t > f and t - f < next_m:
			next_m = t - f
			next_name = str(sim.defs.crises["crises"][id]["name"])
	if next_name != "":
		_forecast.text += " · to \"%s\" %.1f%%" % [next_name, next_m * 100.0]
	_alerts.top_inset = _stack.size.y
	_alerts.refresh()
	# Contract indicator: the active contract with the nearest deadline, else an open offer.
	var best: Dictionary = {}
	var offers := 0
	if sim.contracts != null:
		for c in sim.contracts.open_contracts():
			if c["state"] == "active" and (best.is_empty() or int(c["deadline_day"]) < int(best["deadline_day"])):
				best = c
			elif c["state"] == "offered":
				offers += 1
	_contract_btn.visible = not best.is_empty() or offers > 0
	if not best.is_empty():
		var have := sim.items.count_stored("refined_essence")
		_contract_btn.text = "Contract\n%d/%d ess · %dd" % [mini(have, int(best["essence"])), int(best["essence"]), maxi(0, int(best["deadline_day"]) - sim.day())]
		_contract_btn.modulate = Color(0.6, 1.0, 0.6) if sim.contracts.can_deliver(best) else Color.WHITE
	elif offers > 0:
		_contract_btn.text = "Contract\noffered (%d)" % offers
		_contract_btn.modulate = Color(1.0, 0.85, 0.4)
	_legend.visible = _overlay_on
	_legend.offset_bottom = -_bottom_inset - 4
	_legend.offset_right = -8
	_patrol_bar.offset_bottom = -_bottom_inset - 4
# endregion


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
	_menu_box = GridContainer.new()
	_menu_box.add_theme_constant_override("h_separation", 6)
	_menu_box.add_theme_constant_override("v_separation", 6)
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
	var want := true  # O4: one phone-first layout on every screen size
	if want != _compact or _cat_popup_row.get_parent() == null or _cat_row.get_parent() == null:
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
		_reparent_to(b, _stash)
	for cid: String in _cat_buttons:
		if _cat_buttons[cid].get_parent() != null:
			_cat_buttons[cid].get_parent().remove_child(_cat_buttons[cid])
	_reparent_to(_colonist_bar, _stack)
	_menu_btn.visible = true
	_panel_row.visible = false
	if _cat_row.get_parent() != null:
		_cat_row.get_parent().remove_child(_cat_row)
	# Category bottom bar and "More" menu on every screen size.
	_bottom_inset = BAR_H + 22
	_message.offset_top = -(BAR_H + 90)
	_message.offset_bottom = -(BAR_H + 24)
	_tools_scroll.custom_minimum_size.y = BAR_H + 4
	_tools_row.add_theme_constant_override("separation", 6)
	_tools_row.add_child(_cat_row)
	_reparent_to(_tool_buttons["inspect"], _cat_row)
	_tool_buttons["inspect"].custom_minimum_size = Vector2(110, BAR_H)
	for cid: String in _cat_buttons:
		_cat_row.add_child(_cat_buttons[cid])
	_reparent_to(_alarm_btn, _cat_row)
	_alarm_btn.custom_minimum_size = Vector2(110, BAR_H)
	for b: Button in [_letters_btn] + _panel_buttons.values():
		_reparent_to(b, _menu_box)
		b.custom_minimum_size = Vector2(150, BAR_H)
	_colonist_dock.visible = compact
	_cat_popup.offset_left = 88.0 if compact else 0.0  # keep clear of the colonist portrait column
	_menu_box.columns = 4 if compact else 2
	_reparent_to(_colonist_bar, _colonist_dock)  # O4: portrait column on every size
	_colonist_bar.set_compact(true)
	_o4_build()
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
	_forecast_bar.bind(p_sim)
	_alerts.bind(p_sim)
	_patrol_bar.visible = false
	_o2_bind(p_sim)  # region O2


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
		_inspector.panel_requested.connect(func(pid: String, cid: int) -> void: open_panel_for(pid, cid))
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
		lp.panel_requested.connect(func(pid: String, cid: int, sk: String) -> void: open_panel_for(pid, cid, sk))
		p = lp
	else:
		p = PanelRegistry.make_panel(id)
	if p != null:
		_open_side(p, id)


## Opens a registered panel focused on a colonist (perk panel).
func open_panel_for(id: String, colonist_id: int, skill := "") -> void:
	var p := PanelRegistry.make_panel(id)
	if p == null:
		return
	if p is PerkPanel:
		(p as PerkPanel).focus_colonist(colonist_id, skill)
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
	var sw := minf(SIDE_W, get_viewport().get_visible_rect().size.x * 0.45)  # O4: sheets <= 45% width
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
	_o4_layout()  # O4


func _sync_panel_buttons() -> void:
	if _letters_btn:
		_letters_btn.modulate = Color(0.8, 0.6, 1.0) if _side_id == "letters" else Color.WHITE
	for pid: String in _panel_buttons:
		_panel_buttons[pid].modulate = Color(0.8, 0.6, 1.0) if _side_id == pid else Color.WHITE


func show_game_over(reason: String) -> void:
	_game_over_label.text = "%s\nSurvived %d days." % [REASONS.get(reason, reason), sim.day()]
	_game_over.visible = true


func _process(delta: float) -> void:
	if sim == null:
		return
	var it := sim.items
	var night: bool = sim.clock.is_night()
	_clock.text = "%s %d, %02d:%02d" % ["Night" if night else "Day", sim.day() + 1, sim.clock.hour_int(), int(fposmod(sim.clock.hour(), 1.0) * 60.0)]
	_stats.text = _clock.text + " · Ore %d · Ess %d · Waste %d · Crew %d" % [
		it.count_stored("essence_ore"), it.count_stored("refined_essence"),
		it.count_world("waste"), sim.colonists.alive_count()]
	var cont := sim.contamination
	if cont.revealed:
		var f := cont.forecast()
		_forecast.text = "Taint %.1f%% · end ~%.0f±%.0f d" % [cont.fraction() * 100.0, f["days"], f["error"]]
	else:
		_forecast.text = "Taint %.1f%% · forecast unknown" % (cont.fraction() * 100.0)
	_threat.text = ""
	_threat.visible = false
	_forecast.text += " · " + _threat_text()
	_update_batch3()
	_t5_update()  # region T5
	_o2_update()  # region O2
	_o4_update()  # region O4
	_alarm_btn.set_pressed_no_signal(sim.alarm)
	for rule_id: String in _rule_buttons:
		_rule_buttons[rule_id].set_pressed_no_signal(sim.is_rule_on(rule_id))
	if _message.text != "" and Time.get_ticks_msec() / 1000.0 > _message_until:
		_message.text = ""
		_next_toast()
	_letters_btn.text = "Letters (%d)" % _letters.unread if _letters.unread > 0 else "Letters"
	_menu_btn.text = "More (%d)" % _letters.unread if _letters.unread > 0 else "More"
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
		return "WAVE %d: %d creatures (from the %s)" % [t.wave_index, t.enemies.size(), t.side_name(t.next_spawn_origin)]
	if not t.awakened:
		return "Creatures asleep"
	var ticks := t.next_wave_tick - sim.tick
	var side := " from the %s" % t.side_name(t.next_spawn_origin) if ticks < int(t.cfg["warning_ticks"]) else ""
	return "Wave in %.1f h%s, strength ~%.0f" % [ticks * 24.0 / sim.ticks_per_day, side, t.wave_strength(t.wave_index + 1)]


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


# region T5
## Rally warning strip: shown from the rally letter until the wave starts.
var _t5_strip: PanelContainer
var _t5_label: Label
var _t5_look: Button


func _t5_build_strip() -> void:
	_t5_strip = PanelContainer.new()
	_t5_strip.visible = false
	_t5_strip.modulate = Color(1.0, 0.7, 0.55)
	var row := HBoxContainer.new()
	_t5_strip.add_child(row)
	_t5_label = _label(row)
	_t5_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_t5_look = _button(row, "Look", Vector2(96, 64))
	_t5_look.pressed.connect(func() -> void:
		if sim != null and sim.ecology.active():
			focus_cell_requested.emit(sim.ecology.lead_cell()))
	_stack.add_child(_t5_strip)


func _t5_update() -> void:
	if _t5_strip == null:
		return
	var left := -1
	if sim != null and sim.get("ecology") != null:
		left = sim.ecology.rally_ticks_left()
	_t5_strip.visible = left >= 0
	if left >= 0:
		_t5_label.text = "Creatures massing in the %s - raid in %.1f h" % [
			sim.threats.side_name(sim.ecology.lead_cell()), left * 24.0 / sim.ticks_per_day]
# endregion


# region R4e
signal map_chosen(id: int)
var map_switcher: MapSwitcher
var _campaign: Object


## Shows the map chips when the campaign has more than the home map (or
## expeditions can be planned); pass null for a plain single-map game.
func bind_campaign(c: Object) -> void:
	_campaign = c
	if c == null:
		if map_switcher != null:
			map_switcher.visible = false
		return
	if map_switcher == null:
		map_switcher = MapSwitcher.new()
		map_switcher.map_chosen.connect(func(id: int) -> void: map_chosen.emit(id))
		map_switcher.expedition_pressed.connect(func() -> void: open_expedition("expedition"))
		map_switcher.cargo_pressed.connect(func() -> void: open_expedition("cargo"))
		_stack.add_child(map_switcher)
	map_switcher.visible = true
	map_switcher.bind(c)


func open_expedition(mode: String) -> void:
	var id := "exp_" + mode
	if _side_id == id:
		close_side()
		return
	var p := ExpeditionPanel.new()
	p.setup(_campaign, mode)
	p.sent.connect(func(kind: String, ok: bool) -> void:
		show_message(("Expedition sent." if kind == "expedition" else "Crate launched.") if ok else "Could not send.", 4.0))
	_open_side(p, id)
# endregion


# region O2
## Warden's Orientation: card + pulsing non-blocking highlight. Reads sim.tutorial only.
var tutorial_card: TutorialCard
var tutorial_highlight: TutorialHighlight
var _o2_step := -2
var _o2_start_tick := 0
var _o2_density := "Full"


func _o2_build(root: Control) -> void:
	tutorial_card = TutorialCard.new()
	tutorial_card.visible = false
	tutorial_card.anchor_left = 0.0
	tutorial_card.anchor_right = 1.0
	root.add_child(tutorial_card)
	tutorial_highlight = TutorialHighlight.new()
	tutorial_highlight.visible = false
	root.add_child(tutorial_highlight)


func _o2_bind(p_sim: Simulation) -> void:
	tutorial_card.bind(p_sim)
	_o2_step = -2


## Control that the lesson `target` points at, or null (cell targets belong to the map view).
func o2_target_control(target: Dictionary) -> Control:
	var id := str(target.get("id", ""))
	var c: Control = null
	match str(target.get("kind", "")):
		"tool":
			c = _tool_buttons.get(id)
			if c != null and not c.is_visible_in_tree():
				for cat: Array in CATS:
					if (cat[2] as Array).has(id):
						c = _cat_buttons.get(cat[0])
		"panel":
			match id:  # region R5X: lesson panel ids that are HUD widgets, not registry buttons
				"colonist_bar":
					c = _colonist_dock
				"contamination", "forecast":
					c = _o4_ticker if _o4_ticker != null else _forecast_bar
				"tutorial_card":
					c = tutorial_card
				_:
					c = _panel_buttons.get(id)
					if c != null and not c.is_visible_in_tree():
						c = _menu_btn
	return c if c != null and c.is_visible_in_tree() else null


## R5X: sends the recorded `tutorial_ack` when the active lesson is `lesson_id` (view-mirrored steps).
func o2_ack_if(lesson_id: String) -> void:
	if sim == null or sim.tutorial == null or sim.tutorial.finished():
		return
	if str(sim.tutorial.current().get("id", "")) == lesson_id:
		sim.tutorial_ack()


## R5X: the game supplies the screen rect of a "cell" lesson target (id -> Rect2, empty = none).
var o2_cell_rect: Callable = Callable()


func _o2_update() -> void:
	if tutorial_card == null:
		return
	if _o4_slot != null and tutorial_card.get_parent() != _o4_slot:  # R5X: card lives in O4's slot
		tutorial_card.reparent(_o4_slot, false)
		tutorial_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var step := TutorialCard.current_step(sim)
	var lessons := TutorialCard.lessons(sim)
	if step != _o2_step:
		_o2_density = MetaStore.load_hint_density()
		_o2_step = step
		_o2_start_tick = sim.tick
		tutorial_highlight.hide_highlight()
	var on := step >= 0 and step < lessons.size() and _o2_density != "Off"
	if on and _o4_slot != null and _o4_slot.size.x < 420.0:
		on = false  # R5X: beside an open sheet the card would be a squeezed column; it returns when the sheet closes
	tutorial_card.visible = on
	if not on:
		tutorial_highlight.hide_highlight()
		return
	tutorial_card.refresh()
	var d: Dictionary = lessons[step]
	var nudge := int(d.get("nudge_ticks", 600)) * (2 if _o2_density == "New" else 1)
	var target: Control = null
	if d.get("target") is Dictionary:
		target = o2_target_control(d["target"])
	var cell_rect := Rect2()
	if d.get("target") is Dictionary and str(d["target"].get("kind", "")) == "cell" and o2_cell_rect.is_valid():
		cell_rect = o2_cell_rect.call(str(d["target"].get("id", "")))
	if sim.tick - _o2_start_tick >= nudge and (target != null or cell_rect.has_area()):
		tutorial_highlight.show_over(target.get_global_rect() if target != null else cell_rect)
	else:
		tutorial_highlight.hide_highlight()
# endregion


# region O4
## Phone-first layout (844x390 logical and up): 72 px portrait column on the left, a top strip
## (resources | taint + threat ticker | speed), a bottom-right thumb cluster, side sheets <= 45%
## width that start right of the column, and a reserved top slot for the tutorial card.
const O4_COL_W := 72.0
const O4_LEFT := 80.0  ## x where everything except the portrait column may start
const O4_BTN := Vector2(80, 64)
const O4_TOAST_H := 76.0
const O4_LEGEND_H := 36.0
const O4_SLOT_H := 76.0
const O4_SLOT_MIN_W := 200.0

var _o4_built := false
var _o4_res: VBoxContainer
var _o4_ticker: Button
var _o4_cluster: GridContainer
var _o4_slot: Control
var _o4_strip: PanelContainer


## Free area under the top strip for the tutorial card (a plain Control that never takes input).
## Its rect is kept clear of the map chips, the contract chip and any open side sheet; it is hidden
## when narrower than O4_SLOT_MIN_W. Put the card inside and let it fill the slot.
func tutorial_slot() -> Control:
	return _o4_slot


func _o4_build() -> void:
	if _o4_built:
		return
	_o4_built = true
	_o4_strip = _top_flow.get_parent() as PanelContainer
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.06, 0.06, 0.08, 0.88)
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 3
	st.content_margin_bottom = 3
	_o4_strip.add_theme_stylebox_override("panel", st)
	_o4_strip.remove_child(_top_flow)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_o4_strip.add_child(row)
	_o4_res = VBoxContainer.new()
	_o4_res.add_theme_constant_override("separation", 0)
	_o4_res.alignment = BoxContainer.ALIGNMENT_CENTER
	_o4_res.custom_minimum_size.x = 250
	row.add_child(_o4_res)
	_reparent_to(_clock, _o4_res)
	_clock.visible = true
	_reparent_to(_stats, _o4_res)
	_o4_ticker = Button.new()
	_o4_ticker.focus_mode = Control.FOCUS_NONE
	_o4_ticker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_o4_ticker.custom_minimum_size = Vector2(190, 64)
	_o4_ticker.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_o4_ticker.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	_o4_ticker.pressed.connect(func() -> void:
		o2_ack_if("forecast")  # R5X: forecast lesson = the player opened the forecast ticker
		toggle_panel("letters"))
	row.add_child(_o4_ticker)
	var tv := VBoxContainer.new()
	tv.set_anchors_preset(Control.PRESET_FULL_RECT)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_theme_constant_override("separation", 1)
	_o4_ticker.add_child(tv)
	_reparent_to(_forecast, tv)
	_reparent_to(_forecast_bar, tv)
	_reparent_to(_threat, tv)
	_threat.visible = true
	for l: Label in [_clock, _stats, _forecast, _threat]:
		l.clip_text = false
		l.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		l.add_theme_font_size_override("font_size", 16 if l == _clock else 15)
	var sp := HBoxContainer.new()
	sp.add_theme_constant_override("separation", 4)
	row.add_child(sp)
	for b in _speed_buttons:
		_reparent_to(b, sp)
		b.custom_minimum_size = Vector2(64, 64)
	_top_flow.queue_free()
	_reparent_to(_contract_btn, _root)
	_contract_btn.custom_minimum_size = Vector2(170, 64)
	_contract_btn.add_theme_font_size_override("font_size", 15)
	_bottom.visible = false
	_o4_cluster = GridContainer.new()
	_o4_cluster.columns = 3
	_o4_cluster.add_theme_constant_override("h_separation", 6)
	_o4_cluster.add_theme_constant_override("v_separation", 6)
	_o4_cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_o4_cluster)
	_alarm_btn.icon = null
	for b: Button in [_tool_buttons["inspect"], _cat_buttons["zones"], _cat_buttons["build"], _cat_buttons["orders"], _alarm_btn, _menu_btn]:
		_reparent_to(b, _o4_cluster)
		b.custom_minimum_size = O4_BTN
		b.add_theme_font_size_override("font_size", 16)
	_menu_btn.visible = true
	_o4_slot = Control.new()
	_o4_slot.name = "TutorialSlot"
	_o4_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_o4_slot)
	_message.add_theme_font_size_override("font_size", 16)
	_message.max_lines_visible = 3
	_bottom_inset = 8.0
	(_cat_popup.get_child(0) as ScrollContainer).horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER  # touch-drag, keeps the popup 88 px tall
	var msc := ScrollContainer.new()  # More menu: one scrolling row, same height as the category popups
	msc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	msc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_menu_popup.add_child(msc)
	_reparent_to(_menu_box, msc)
	_menu_box.columns = 12
	for b: Button in _menu_box.get_children():
		b.custom_minimum_size = Vector2(96, 64)
		b.add_theme_font_size_override("font_size", 16)
	_root.move_child(_alerts, -1)
	_root.move_child(_game_over, -1)


func _o4_threat_short() -> String:
	if sim.get("threats") == null or sim.threats == null:
		return ""
	var t: ThreatSystem = sim.threats
	if t.wave_active:
		return "WAVE %d: %d from the %s" % [t.wave_index, t.enemies.size(), t.side_name(t.next_spawn_origin)]
	if not t.awakened:
		return "Creatures asleep"
	var ticks := t.next_wave_tick - sim.tick
	var side := " from the %s" % t.side_name(t.next_spawn_origin) if ticks < int(t.cfg["warning_ticks"]) else ""
	return "Wave in %.1f h%s" % [ticks * 24.0 / sim.ticks_per_day, side]


func _o4_update() -> void:
	if not _o4_built:
		return
	var it := sim.items
	_clock.text = "%s %d · %02d:%02d" % ["Night" if sim.clock.is_night() else "Day", sim.day() + 1, sim.clock.hour_int(), int(fposmod(sim.clock.hour(), 1.0) * 60.0)]
	_stats.text = "Ore %d  Ess %d  Waste %d  Crew %d" % [
		it.count_stored("essence_ore"), it.count_stored("refined_essence"),
		it.count_world("waste"), sim.colonists.alive_count()]
	var cont := sim.contamination
	if cont.revealed:
		var f := cont.forecast()
		_forecast.text = "Taint %.1f%% · end ~%.0f±%.0f d" % [cont.fraction() * 100.0, f["days"], f["error"]]
	else:
		_forecast.text = "Taint %.1f%% · forecast unknown" % (cont.fraction() * 100.0)
	_threat.text = _o4_threat_short()
	_threat.visible = true


func _o4_place_corner(c: Control, left: float, bottom: float) -> void:
	c.anchor_left = 0.0
	c.anchor_right = 0.0
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0
	c.grow_horizontal = Control.GROW_DIRECTION_END
	c.grow_vertical = Control.GROW_DIRECTION_BEGIN
	c.offset_left = left
	c.offset_right = left
	c.offset_bottom = bottom
	c.offset_top = bottom


func _o4_anchor_br(c: Control, right: float, bottom: float) -> void:
	c.anchor_left = 1.0
	c.anchor_right = 1.0
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0
	c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	c.grow_vertical = Control.GROW_DIRECTION_BEGIN
	c.offset_right = right
	c.offset_left = right
	c.offset_bottom = bottom
	c.offset_top = bottom


func _o4_anchor_tl(c: Control, left: float, top: float, w: float, h: float) -> void:
	c.anchor_left = 0.0
	c.anchor_right = 0.0
	c.anchor_top = 0.0
	c.anchor_bottom = 0.0
	c.offset_left = left
	c.offset_right = left + w
	c.offset_top = top
	c.offset_bottom = top + h


## Positions every floating HUD element. Runs every frame (cheap) so panels, popups and
## window resizes always settle into the same non-overlapping arrangement.
func _o4_layout() -> void:
	if not _o4_built:
		return
	var vp := get_viewport().get_visible_rect().size
	var y0 := maxf(_stack.get_combined_minimum_size().y, _stack.size.y) + 4.0
	var side_open := _side != null and is_instance_valid(_side)
	var sw := minf(SIDE_W, vp.x * 0.45)
	var limit := vp.x - 8.0 - ((sw + 8.0) if side_open else 0.0)  # right edge free for the thumb cluster
	var menu_open := _menu_popup.visible
	var pop_open := _open_cat != "" or menu_open
	# Thumb cluster: bottom-right, shifts left of an open sheet.
	var cs := _o4_cluster.get_combined_minimum_size()
	_o4_anchor_br(_o4_cluster, limit - vp.x, -8.0)
	var pop_bottom := -(8.0 + cs.y + 8.0)
	var lim2 := limit - cs.x - 8.0  # right edge of the bottom-left stack
	# Popups above the cluster, right-aligned to it.
	var pw := _cat_popup_row.get_combined_minimum_size().x + 28.0
	_cat_popup.offset_left = maxf(O4_LEFT, limit - pw)
	_cat_popup.offset_right = limit - vp.x
	_cat_popup.offset_bottom = pop_bottom
	for b in _cat_popup_row.get_children():
		if b is Button and not b.has_meta("o4"):
			b.set_meta("o4", true)
			b.add_theme_constant_override("icon_max_width", 26)
			b.add_theme_font_size_override("font_size", 16)
		if b is Button:
			b.custom_minimum_size = Vector2(96, 72)
	var mw := _menu_box.get_combined_minimum_size().x + 28.0
	_menu_popup.anchor_left = 0.0
	_menu_popup.anchor_right = 1.0
	_menu_popup.anchor_top = 1.0
	_menu_popup.anchor_bottom = 1.0
	_menu_popup.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_menu_popup.offset_left = maxf(O4_LEFT, limit - mw)
	_menu_popup.offset_right = limit - vp.x
	_menu_popup.offset_bottom = pop_bottom
	# Portrait column.
	_colonist_dock.anchor_left = 0.0
	_colonist_dock.anchor_right = 0.0
	_colonist_dock.anchor_top = 0.0
	_colonist_dock.anchor_bottom = 1.0
	_colonist_dock.offset_left = 0.0
	_colonist_dock.offset_right = O4_COL_W
	_colonist_dock.offset_top = y0
	_colonist_dock.offset_bottom = -8.0
	# Side sheet: top below the strip, right of the column.
	if side_open:
		_side.offset_left = -sw - 8.0
		_side.offset_right = -8.0
		_side.offset_top = y0
		_side.offset_bottom = -8.0
	# Top-left chip row: map chips, then the contract chip; the tutorial slot takes the rest.
	var x := O4_LEFT
	var slot_r := vp.x - 8.0 - ((sw + 8.0) if side_open else 0.0)
	if map_switcher != null and map_switcher.visible:
		if map_switcher.get_parent() != _root:
			_reparent_to(map_switcher, _root)
		_o4_anchor_tl(map_switcher, O4_LEFT, y0, minf(560.0, slot_r - O4_LEFT), 0.0)
		var cw := 0.0
		for ch in map_switcher.get_children():
			if ch is Button:
				if not ch.has_theme_font_size_override("font_size"):
					ch.add_theme_font_size_override("font_size", 16)
					ch.custom_minimum_size.x = 96.0
				cw = maxf(cw, ch.position.x + ch.size.x)
		x = O4_LEFT + cw + 8.0
	if _contract_btn.visible and x + _contract_btn.custom_minimum_size.x > slot_r:
		_contract_btn.visible = false  # no room beside an open sheet; the Contracts entry in More still works
	if _contract_btn.visible:
		_o4_anchor_tl(_contract_btn, x, y0, _contract_btn.custom_minimum_size.x, 64.0)
		x += _contract_btn.custom_minimum_size.x + 8.0
	_o4_anchor_tl(_o4_slot, x, y0, maxf(0.0, slot_r - x), O4_SLOT_H)
	_o4_slot.visible = (slot_r - x) >= O4_SLOT_MIN_W
	# Bottom-left stack: legend, toast, belt strip / patrol bar.
	var quiet := not pop_open and not side_open
	_o4_place_corner(_legend, O4_LEFT, -8.0)
	_legend.visible = _overlay_on and quiet and _legend.get_combined_minimum_size().x + O4_LEFT <= lim2
	var toast_b := -(8.0 + O4_LEGEND_H + 4.0)
	_message.visible = true
	_message.anchor_left = 0.0
	_message.anchor_right = 0.0
	_message.anchor_top = 1.0
	_message.anchor_bottom = 1.0
	_message.offset_left = O4_LEFT
	_message.offset_right = maxf(O4_LEFT + 120.0, lim2)
	_message.offset_bottom = toast_b
	_message.offset_top = toast_b - O4_TOAST_H
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var tool_b := toast_b - O4_TOAST_H - 4.0
	_o4_place_corner(_patrol_bar, O4_LEFT, tool_b)
	for ch in _patrol_bar.get_child(0).get_children():
		if ch is Button:
			ch.custom_minimum_size = Vector2(84, 64)
		elif ch is Label:
			ch.add_theme_font_size_override("font_size", 16)
	_patrol_bar.visible = _patrol_bar.visible and not pop_open and not side_open
	var g := get_parent()
	var ap: Variant = g.get("auto_panel") if g != null else null
	if ap is Control:
		var apc := ap as Control
		if not apc.has_meta("o4"):
			apc.set_meta("o4", true)
			var th := Theme.new()
			th.default_font_size = 16
			apc.theme = th
			for b in _o4_buttons(apc):
				b.custom_minimum_size = Vector2(88, 64)
		var mrow: Variant = apc.get("_machine_row")
		var machines_open: bool = mrow is Control and (mrow as Control).visible
		if machines_open and quiet:  # R5X: the tall Machines row drops into the toast/legend band, clear of the chips
			_legend.visible = false
			_message.visible = false
			tool_b = -8.0
		_o4_place_corner(apc, O4_LEFT, tool_b)
		apc.visible = quiet and not _patrol_bar.visible
	# Save/Continue prompt: above the cluster, never under a menu.
	var cont: Variant = g.get("_continue_btn") if g != null else null
	if cont is Button:
		var cb := cont as Button
		cb.custom_minimum_size = Vector2(160, 64)
		_o4_anchor_br(cb, limit - vp.x, pop_bottom - 4.0)
		var gs: Variant = g.get("sim")
		cb.visible = quiet and SaveStore.has_save() and (gs == null or gs.tick < 50 or gs.game_over_reason != "")


func _o4_buttons(n: Node) -> Array[Button]:
	var out: Array[Button] = []
	for ch in n.get_children():
		if ch is Button:
			out.append(ch)
		out.append_array(_o4_buttons(ch))
	return out
# endregion
