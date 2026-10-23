class_name PassiveBoard
extends GamePanel
## F11W4: the Record board (passives v2, docs/gdd/03-colony/passives-v2/board.md). Left: inmate, marks, keystones n/2,
## six detail chips. Centre: one card (3x6 grid of 64 px buttons) with the seam bridges on both edges. Right: bottom
## sheet for the tapped passive (Rule / Drawback, effects, requirement, Allocate / Undo, Respec).
## Reads sim state only; changes go through sim.allocate_passive / undo_passive / respec_passives.
## Opened from the colonist sheet ("Record" button); hidden while balance.passives_v2_enabled is false.

const CELL := 64.0
const GAP_X := 8.0
const GAP_Y := 4.0
const SEAM_X := 288.0  ## x of the right seam strip (left strip is at 0); the card sits between
const CANVAS_W := 352.0
const CANVAS_H := 6.0 * CELL + 5.0 * GAP_Y
const LEFT_W := 200.0
const BRIDGE_COLOR := "#e0a030"
const DIM_ALPHA := 0.4
const REASONS := {
	"locked": "Locked after a respec",
	"gate_skill": "Needs %s",
	"gate_deed": "Needs the deed: %s",
	"requires": "Needs %s",
	"excluded": "Excluded by %s",
	"keystone_limit": "Two keystones already",
	"no_marks": "Needs %d marks",
	"off": "The Record is closed",
}
const UNDO_REASONS := {
	"grace": "Too late to take back",
	"dependents": "Other passives depend on it",
}
## Inmate shown when the board opens (set by the colonist sheet / HUD); -1 = first living inmate.
static var focus_cid := -1
static var _tree: PassiveTreeV2

var cid := -1
var detail := ""
var sel_id := ""
var node_buttons: Dictionary = {}  ## passive id -> Button (current card + seams)
var chip_buttons: Dictionary = {}  ## detail id -> Button
var allocate_button: Button
var undo_button: Button
var respec_button: Button
var close_button: Button
var _confirm_respec := false
var _sig := ""
var _root: HBoxContainer
var _left: VBoxContainer
var _canvas: Control
var _text_box: VBoxContainer
var _action_box: VBoxContainer


func _init() -> void:
	super._init()
	set_meta("wide_sheet", true)  # the HUD gives this sheet the full width and hides the thumb cluster
	set_meta("full_screen", true)  # ... and the full height (a 6-row card of 64 px cells needs ~420 px)
	ModalStyle.apply(self)
	(_title_label.get_parent() as HBoxContainer).visible = false  # the board carries its own close button


static func tree() -> PassiveTreeV2:
	if _tree == null:
		_tree = PassiveTreeV2.new(PassiveTreeV2.load_default())
	return _tree


## Picks the inmate (call before open()).
func focus_colonist(p_cid: int, _skill := "") -> void:
	focus_cid = p_cid
	cid = p_cid
	sel_id = ""
	_confirm_respec = false
	_sig = ""


func build() -> void:
	_pick_colonist()
	_root = HBoxContainer.new()
	_root.add_theme_constant_override("separation", 8)
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_root)
	_left = VBoxContainer.new()
	_left.custom_minimum_size = Vector2(LEFT_W, CANVAS_H)
	_left.add_theme_constant_override("separation", 4)
	_root.add_child(_left)
	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(CANVAS_W, CANVAS_H)
	_root.add_child(_canvas)
	var sheet := VBoxContainer.new()
	sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet.custom_minimum_size = Vector2(190.0, CANVAS_H)
	sheet.add_theme_constant_override("separation", 4)
	_root.add_child(sheet)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sheet.add_child(sc)
	_text_box = VBoxContainer.new()
	_text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_text_box)
	_action_box = VBoxContainer.new()
	_action_box.add_theme_constant_override("separation", 4)
	sheet.add_child(_action_box)


func refresh() -> void:
	if sim == null or _root == null:
		return
	var c := sim.colonists.get_by_id(cid)
	if c == null or not c.alive:
		_pick_colonist()
		c = sim.colonists.get_by_id(cid)
	if c == null:
		return
	if detail == "":
		detail = _default_detail(c)
	var st := _state(c)
	var sig := "%d|%s|%s|%s|%d/%d|%s|%d" % [cid, detail, sel_id, _confirm_respec, st.marks_earned, st.marks_spent,
		",".join(st.allocated), sim.tick / 300]
	if sig == _sig:
		return
	_sig = sig
	_rebuild(c, st)


# region state helpers
func _state(c: Colonist) -> PassiveTreeV2.State:
	var st := sim.passives.state_of(c)
	return st if st != null else PassiveTreeV2.State.new()


func _pick_colonist() -> void:
	if cid >= 0 and sim.colonists.get_by_id(cid) != null and sim.colonists.get_by_id(cid).alive:
		return
	cid = -1
	var want := sim.colonists.get_by_id(focus_cid)
	if want != null and want.alive:
		cid = want.id
		return
	for c in sim.colonists.list:
		if c.alive:
			cid = c.id
			return


func _default_detail(c: Colonist) -> String:
	var st := _state(c)
	if not st.allocated.is_empty():
		return str(tree().def_of(st.allocated[st.allocated.size() - 1]).get("detail", "pit")).split("+")[0]
	for d: String in tree().details():
		var first := _entry_of(d)
		if first != "" and sim.passives.can_allocate(c, first) in ["", "no_marks"]:
			return d
	return "pit"


## The gated first minor of a detail ("" if none).
func _entry_of(d: String) -> String:
	for id in tree().passives_of(d):
		if not (tree().def_of(id).get("gate", {}) as Dictionary).is_empty() and str(tree().def_of(id)["tier"]) == "minor":
			return id
	return ""


func _step_colonist(dir: int) -> void:
	var alive: Array[int] = []
	for c in sim.colonists.list:
		if c.alive:
			alive.append(c.id)
	if alive.is_empty():
		return
	var i := alive.find(cid)
	cid = alive[posmod(i + dir, alive.size())]
	focus_cid = cid
	sel_id = ""
	detail = ""
	_confirm_respec = false
	_sig = ""
	refresh()
# endregion


# region copy
static func skill_label(sim: Simulation, sk: String) -> String:
	return str(sim.defs.skills["skills"].get(sk, {}).get("label", sk))


static func pname(id: String) -> String:
	return str(tree().def_of(id).get("name", id))


## One line of copy for a can_allocate reason code ("" for ok).
static func reason_text(sim: Simulation, st: PassiveTreeV2.State, id: String, reason: String) -> String:
	if reason == "":
		return ""
	var d := tree().def_of(id)
	match reason:
		"gate_skill":
			var parts: Array[String] = []
			for sk: String in (d.get("gate", {}) as Dictionary).get("skills", {}):
				parts.append("%s %d" % [skill_label(sim, sk), int(d["gate"]["skills"][sk])])
			return REASONS["gate_skill"] % " or ".join(parts)
		"gate_deed":
			var deed: Dictionary = tree().deeds().get(str(d.get("gate", {}).get("deed", "")), {})
			return REASONS["gate_deed"] % str(deed.get("name", "a deed"))
		"requires":
			var names: Array[String] = []
			for g: Dictionary in d.get("requires_groups", []):
				var have := 0
				var opts: Array[String] = []
				for x: Variant in g["any"]:
					opts.append(pname(str(x)))
					if st.allocated.has(str(x)):
						have += 1
				if have < int(g["n"]):
					names.append(("%d of " % int(g["n"]) if int(g["n"]) > 1 else "") + ", ".join(opts))
			return REASONS["requires"] % "; ".join(names)
		"excluded":
			var by: Array[String] = []
			for x: Variant in d.get("excludes", []):
				if st.allocated.has(str(x)):
					by.append(pname(str(x)))
			return REASONS["excluded"] % ", ".join(by)
		"no_marks":
			return REASONS["no_marks"] % tree().cost_of(st, id)
		"allocated":
			return "Allocated"
	return str(REASONS.get(reason, reason))


## "Mining speed +10%" for one effect value.
static func effect_text(stat: String, v: float) -> String:
	var nm := stat.replace("_", " ").capitalize()
	if absf(v) < 5.0:
		return "%s %+d%%" % [nm, roundi(v * 100.0)]
	return "%s %+d" % [nm, roundi(v)]


## One short line per rule flag of a passive ("Never sleeps").
static func rule_lines(id: String) -> Array[String]:
	var out: Array[String] = []
	var cons := tree().rule_consumers()
	for r in tree().rules_of(id):
		out.append(str(cons.get(r, {}).get("rule", r)))
	return out
# endregion


# region build
func _rebuild(c: Colonist, st: PassiveTreeV2.State) -> void:
	for box: Node in [_left, _canvas, _text_box, _action_box]:
		for ch in box.get_children():
			box.remove_child(ch)
			ch.queue_free()
	node_buttons.clear()
	chip_buttons.clear()
	_build_left(c, st)
	_build_card(c, st)
	_build_sheet(c, st)


func _label(parent: Control, text: String, size := 16, color := Color(0.92, 0.93, 0.96), wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
	return l


func _btn(parent: Control, text: String, min_size: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _build_left(c: Colonist, st: PassiveTreeV2.State) -> void:
	var nm := _label(_left, c.display_name, 20, Color.WHITE, false)
	nm.clip_text = true
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 4)
	_left.add_child(nav)
	_btn(nav, "<", Vector2(CELL, CELL), func() -> void: _step_colonist(-1))
	_btn(nav, ">", Vector2(CELL, CELL), func() -> void: _step_colonist(1))
	close_button = _btn(nav, "X", Vector2(CELL, CELL), func() -> void: close_requested.emit())
	var free := st.marks_free()
	_label(_left, "Marks: %d free" % free, 18, Color(0.95, 0.8, 0.3) if free > 0 else Color(0.75, 0.77, 0.82), false)
	var ks := tree().keystones_of(st)
	var krow := HBoxContainer.new()
	krow.add_theme_constant_override("separation", 4)
	_left.add_child(krow)
	_label(krow, "Keystones %d/%d" % [ks.size(), tree().max_keystones()], 16, Color(0.92, 0.93, 0.96), false)
	for k in ks:
		var ic := _icon(k, 24)
		ic.tooltip_text = pname(k)
		krow.add_child(ic)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	_left.add_child(grid)
	for d: String in tree().details():
		var info: Dictionary = tree().details()[d]
		var held := 0
		for id in st.allocated:
			if str(tree().def_of(id).get("detail", "")).split("+").has(d):
				held += 1
		var chip := _btn(grid, "%s%s" % [str(info.get("name", d)).trim_prefix("The "), " (%d)" % held if held > 0 else ""],
			Vector2(98.0, CELL), func() -> void: _pick_detail(d))
		chip.add_theme_font_size_override("font_size", 15)
		chip.clip_text = true
		chip.modulate = Color(0.8, 0.6, 1.0) if d == detail else Color.WHITE
		chip_buttons[d] = chip


func _pick_detail(d: String) -> void:
	detail = d
	sel_id = ""
	_confirm_respec = false
	_sig = ""
	refresh()


func _icon(id: String, size: int) -> TextureRect:
	var t := TextureRect.new()
	var path := "res://assets/sprites/%s.png" % str(tree().def_of(id).get("icon", id))
	if ResourceLoader.exists(path):
		t.texture = load(path)
	t.custom_minimum_size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return t


func _build_card(c: Colonist, st: PassiveTreeV2.State) -> void:
	var order: Array = tree().details().keys()
	var i := order.find(detail)
	var prev: String = order[posmod(i - 1, order.size())]
	var next: String = order[posmod(i + 1, order.size())]
	for id in tree().passives_of(detail):
		var pos: Array = tree().def_of(id)["pos"]
		_add_node(c, st, id, Vector2(_col_x(int(pos[0])), float(pos[1]) * (CELL + GAP_Y)))
	for id in tree().passives_of(detail + "+" + next):  # right seam
		_add_node(c, st, id, Vector2(SEAM_X, float(tree().def_of(id)["pos"][1]) * (CELL + GAP_Y)))
	for id in tree().passives_of(prev + "+" + detail):  # left seam
		_add_node(c, st, id, Vector2(0.0, float(tree().def_of(id)["pos"][1]) * (CELL + GAP_Y)))


static func _col_x(col: int) -> float:
	return CELL + GAP_X + float(col) * (CELL + GAP_X)


func _add_node(c: Colonist, st: PassiveTreeV2.State, id: String, at: Vector2) -> void:
	var d := tree().def_of(id)
	var reason := sim.passives.can_allocate(c, id)
	var owned := st.allocated.has(id)
	var tier := str(d["tier"])
	var det := str(d["detail"])
	var col := Color.html(BRIDGE_COLOR if det.contains("+") else str(tree().details().get(det, {}).get("color", "#c8a060")))
	var b := Button.new()
	b.position = at
	b.custom_minimum_size = Vector2(CELL, CELL)
	b.size = Vector2(CELL, CELL)
	b.focus_mode = Control.FOCUS_NONE
	b.icon = load("res://assets/sprites/%s.png" % str(d.get("icon", id))) if ResourceLoader.exists("res://assets/sprites/%s.png" % str(d.get("icon", id))) else null
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 36)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.tooltip_text = pname(id)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.09) if tier == "keystone" else Color(0.12, 0.13, 0.17)
	sb.border_color = col if (owned or reason == "") else col.darkened(0.4)
	if id == sel_id:
		sb.border_color = Color.WHITE
	match tier:
		"minor":
			sb.set_border_width_all(2)
			sb.corner_radius_top_left = 10
			sb.corner_radius_bottom_right = 10
		"notable":
			sb.set_border_width_all(5)
			sb.set_corner_radius_all(3)
		_:
			sb.set_border_width_all(5)
			sb.set_corner_radius_all(26)
	if owned:
		sb.bg_color = sb.bg_color.lerp(col, 0.35)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, sb)
	if not owned and reason != "":
		b.modulate.a = 0.7 if reason in ["no_marks", "keystone_limit"] else DIM_ALPHA
	b.pressed.connect(func() -> void: _select(id))
	_canvas.add_child(b)
	node_buttons[id] = b
	if reason == "excluded":
		var x := Label.new()
		x.text = "X"
		x.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		x.add_theme_font_size_override("font_size", 28)
		x.mouse_filter = Control.MOUSE_FILTER_IGNORE
		x.set_anchors_preset(Control.PRESET_FULL_RECT)
		x.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		x.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b.add_child(x)


func _select(id: String) -> void:
	sel_id = id
	_confirm_respec = false
	_sig = ""
	refresh()


func _build_sheet(c: Colonist, st: PassiveTreeV2.State) -> void:
	allocate_button = null
	undo_button = null
	if sel_id == "":
		_label(_text_box, str(tree().details().get(detail, {}).get("name", detail)), 20, Color.WHITE)
		_label(_text_box, str(tree().details().get(detail, {}).get("blurb", "")), 16)
		_label(_text_box, "Tap a passive for details.", 15, Color(0.7, 0.72, 0.78))
	else:
		_build_passive_text(c, st)
	_build_actions(c, st)


func _build_passive_text(c: Colonist, st: PassiveTreeV2.State) -> void:
	var d := tree().def_of(sel_id)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	_text_box.add_child(head)
	head.add_child(_icon(sel_id, 32))
	_label(head, "%s\n%s" % [pname(sel_id), str(d["tier"]).capitalize()], 18, Color.WHITE)
	_label(_text_box, str(d.get("desc", "")), 16)
	if str(d["tier"]) == "keystone":
		if str(d.get("rule", "")) != "":
			_label(_text_box, "Rule: " + str(d["rule"]), 16, Color(0.6, 0.9, 0.6))
		if str(d.get("drawback", "")) != "":
			_label(_text_box, "Drawback: " + str(d["drawback"]), 16, Color(1.0, 0.55, 0.45))
	for k: String in d.get("effects", {}):
		if not k.begins_with(PassiveTreeV2.RULE_PREFIX):
			_label(_text_box, effect_text(k, float(d["effects"][k])), 15, Color(0.8, 0.85, 1.0))
	for line in rule_lines(sel_id):
		_label(_text_box, line, 15, Color(0.8, 0.85, 1.0))
	var reason := sim.passives.can_allocate(c, sel_id)
	if reason != "" and reason != "allocated":
		_label(_text_box, reason_text(sim, st, sel_id, reason), 15, Color(0.95, 0.8, 0.3))
	_label(_text_box, "Cost: %d" % tree().cost_of(st, sel_id), 15, Color(0.7, 0.72, 0.78))


func _build_actions(c: Colonist, st: PassiveTreeV2.State) -> void:
	var cur := cid
	if sel_id != "":
		var pid := sel_id
		if st.allocated.has(pid):
			var ur := tree().can_undo(st, pid, sim.tick)
			undo_button = _btn(_action_box, "Undo" if ur == "" else "Undo: " + str(UNDO_REASONS.get(ur, ur)),
				Vector2(0, CELL), func() -> void:
					sim.undo_passive(cur, pid)
					_sig = ""
					refresh())
			undo_button.disabled = ur != ""
		else:
			var reason := sim.passives.can_allocate(c, pid)
			allocate_button = _btn(_action_box, "Allocate (%d)" % tree().cost_of(st, pid), Vector2(0, CELL), func() -> void:
				sim.allocate_passive(cur, pid)
				_sig = ""
				refresh())
			allocate_button.disabled = reason != ""
	var rc := tree().respec_cost(st)
	var item_name := str(sim.defs.items.get(rc["item"], {}).get("name", rc["item"]))
	var txt := "Respec: %d %s" % [rc["count"], item_name]
	if int(rc["standing"]) > 0:
		txt += ", %d Standing" % rc["standing"]
	if _confirm_respec:
		txt = "Tap again to respec"
	respec_button = _btn(_action_box, txt, Vector2(0, CELL), func() -> void:
		if _confirm_respec:
			sim.respec_passives(cur)
			_confirm_respec = false
		else:
			_confirm_respec = true
		_sig = ""
		refresh())
	respec_button.add_theme_font_size_override("font_size", 14)
	respec_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	respec_button.disabled = not tree().can_respec(st)
# endregion
