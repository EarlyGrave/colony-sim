class_name AlertCenter
extends Control
## Modal-ish cards for things that need an answer now: pending contamination
## crises (resolve_crisis) and paid-off prisoners (choose_payoff).
## Can be collapsed to a single strip button so it never blocks the map for long.

var sim: Simulation
var top_inset := 0.0
var collapsed := false
var _panel: PanelContainer
var _scroll: ScrollContainer
var _box: VBoxContainer
var _strip: Button
var _sig := ""
var _hide_btn: Button
var _known: Dictionary = {}
var _timers: Array = []  # [Label, crisis id]


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.1, 1.0)
	sb.border_color = Color(1.0, 0.45, 0.35)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 8)
	_scroll.add_child(_box)
	_strip = Button.new()
	_strip.custom_minimum_size = Vector2(300, 64)
	_strip.focus_mode = Control.FOCUS_NONE
	_strip.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_strip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_strip.pressed.connect(func() -> void:
		collapsed = false
		_sig = ""
		refresh())
	add_child(_strip)
	_panel.visible = false
	_strip.visible = false


func bind(p_sim: Simulation) -> void:
	sim = p_sim
	_sig = ""
	_known.clear()
	collapsed = false
	refresh()


## Payoff-ready prisoners (debt cleared, waiting for a decision).
func payoff_ids() -> Array[int]:
	var out: Array[int] = []
	if sim == null or sim.debt == null:
		return out
	for c in sim.colonists.list:
		var st := sim.debt.state_of(c)
		if c.alive and st != null and st.pending_choice:
			out.append(c.id)
	return out


func pending_count() -> int:
	if sim == null:
		return 0
	return (sim.crises.pending.size() if sim.crises != null else 0) + payoff_ids().size()


func refresh() -> void:
	if sim == null:
		return
	var sig_parts: PackedStringArray = []
	var fresh := false
	if sim.crises != null:
		for p in sim.crises.pending:
			var id := str(p["id"])
			sig_parts.append(id)
			for o: String in sim.defs.crises["crises"][id]["options"]:
				sig_parts.append("1" if sim.crises.can_afford(id, o) else "0")
			if not _known.has("c" + id):
				_known["c" + id] = true
				fresh = true
	for cid in payoff_ids():
		sig_parts.append("p%d" % cid)
		if not _known.has("p%d" % cid):
			_known["p%d" % cid] = true
			fresh = true
	if fresh:
		collapsed = false
	var total := pending_count()
	_panel.visible = total > 0 and not collapsed
	_strip.visible = total > 0 and collapsed
	if total == 0:
		_sig = ""
		return
	var sig := "|".join(sig_parts) + ("c" if collapsed else "o")
	if sig != _sig:
		_sig = sig
		_rebuild()
	_update_timers()
	_strip.position.y = top_inset + 4


func _update_timers() -> void:
	for t: Array in _timers:
		for p in sim.crises.pending:
			if p["id"] == t[1]:
				var left := maxi(0, int(p["expires"]) - sim.tick)
				(t[0] as Label).text = "Decide in %.1f h (otherwise default)" % (left * 24.0 / sim.ticks_per_day)


func _rebuild() -> void:
	for ch in _box.get_children():
		_box.remove_child(ch)
		ch.queue_free()
	_timers.clear()
	var vp := get_viewport_rect().size
	var width := minf(760.0, vp.x - 40.0)
	_strip.text = "Answer needed: %d (tap)" % pending_count()
	_strip.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
	if collapsed:
		return
	_hide_btn = Button.new()
	_hide_btn.text = "Hide"
	_hide_btn.custom_minimum_size = Vector2(130, 56)
	_hide_btn.focus_mode = Control.FOCUS_NONE
	_hide_btn.pressed.connect(func() -> void:
		collapsed = true
		_sig = ""
		refresh())
	if sim.crises != null:
		for p in sim.crises.pending:
			_crisis_card(str(p["id"]), width)
	for cid in payoff_ids():
		_payoff_card(cid, width)
	_scroll.custom_minimum_size = Vector2(width, 10)
	_fit.call_deferred()


func _fit() -> void:
	var vp := get_viewport_rect().size
	var want := _box.get_combined_minimum_size().y
	_scroll.custom_minimum_size.y = minf(want + 4.0, vp.y - top_inset - 90.0)


func _crisis_card(id: String, width: float) -> void:
	var c: Dictionary = sim.defs.crises["crises"][id]
	var head := Label.new()
	head.text = "CRISIS: %s (%d%% taint)" % [c["name"], roundi(float(c["threshold"]) * 100.0)]
	head.add_theme_font_size_override("font_size", 18 if _small() else 26)
	head.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
	_add_head(head)
	var body := _wrapped(_box, str(c["text"]), width)
	if _small():
		body.add_theme_font_size_override("font_size", 14)
	var tl := Label.new()
	if _small():
		tl.add_theme_font_size_override("font_size", 14)
	tl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_box.add_child(tl)
	_timers.append([tl, id])
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 8)
	_box.add_child(flow)
	var n_opts: int = c["options"].size()
	var col_w := (width - 10.0 * (n_opts - 1) - 24.0) / n_opts if (_small() or width >= 560.0) and n_opts > 0 else width
	if not _small() and width >= 560.0:
		col_w = (width - 20.0) / 2.0
	for oid: String in c["options"]:
		var o: Dictionary = c["options"][oid]
		var vb := VBoxContainer.new()
		vb.custom_minimum_size.x = col_w
		flow.add_child(vb)
		var label := str(o["label"])
		var cost: Dictionary = o.get("cost", {})
		for item: String in cost:
			label += " (%d %s)" % [int(cost[item]), str(sim.defs.items[item]["name"]).to_lower()]
		var b := _button(vb, label, Vector2(0, 64))
		if _small():
			b.add_theme_font_size_override("font_size", 15)
		b.disabled = not sim.crises.can_afford(id, oid)
		b.pressed.connect(func() -> void: sim.resolve_crisis(id, oid))
		_wrapped(vb, str(o["text"]), col_w).add_theme_font_size_override("font_size", 12 if _small() else 16)
	_box.add_child(HSeparator.new())


func _payoff_card(cid: int, width: float) -> void:
	var c := sim.colonists.get_by_id(cid)
	var head := Label.new()
	head.text = "%s paid off the debt" % c.display_name
	head.add_theme_font_size_override("font_size", 24)
	head.add_theme_color_override("font_color", Color(0.5, 0.95, 0.5))
	_add_head(head)
	_wrapped(_box, "Stay on as a free colonist or leave the planet?", width)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	_box.add_child(row)
	var stay := _button(row, "Stay", Vector2(200, 64))
	stay.pressed.connect(func() -> void: sim.choose_payoff(cid, true))
	var leave := _button(row, "Leave the planet", Vector2(240, 64))
	leave.pressed.connect(func() -> void: sim.choose_payoff(cid, false))
	_box.add_child(HSeparator.new())


## First card header shares its row with the "Hide" button.
func _add_head(head: Label) -> void:
	if _hide_btn != null and _hide_btn.get_parent() == null:
		var row := HBoxContainer.new()
		head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(head)
		row.add_child(_hide_btn)
		_box.add_child(row)
	else:
		_box.add_child(head)


func _small() -> bool:
	return get_viewport_rect().size.y < 500.0


func _wrapped(parent: Control, text: String, width: float) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = minf(width, 700.0)
	parent.add_child(l)
	return l


func _button(parent: Control, text: String, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(b)
	return b
