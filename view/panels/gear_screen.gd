class_name GearScreen
extends GamePanel
## F8: full gear screen. Left: paper-doll with one 72 px button per slot (2 columns). Centre: grid inventory of
## stored gear (64 px cells, 5 columns, at least 15 cells). Right: item card + fighter profile + actions.
## Tap only: tap an item/slot to select it, then Equip / Unequip / Socket. Commands go through Simulation.
## Icons come from GearIcons (W1) and the card from ItemCard (W3); both are loaded by path at run time so this
## panel still builds (letter fallback / plain text) if either is missing.

const CELL := 64.0
const SLOT := 72.0
const COLS := 5
const MIN_CELLS := 15
const ICONS_PATH := "res://view/gear_icons.gd"
const CARD_PATH := "res://view/panels/item_card.gd"
const DIM := Color(0.55, 0.57, 0.62)

## Inmate shown when the panel opens (set by the inspector button / HUD); -1 = first inmate with gear.
static var focus_cid := -1

var cid := -1
var sel_id := -1
var hint := ""
var _sig := ""
var _doll: GridContainer
var _grid: GridContainer
var _side: VBoxContainer
var _prev: Button
var _next: Button


func _init() -> void:
	super._init()
	set_meta("wide_sheet", true)  # HUD gives this sheet the full width and hides the thumb cluster


## Picks the inmate (call before open()).
func focus_colonist(p_cid: int, _skill := "") -> void:
	focus_cid = p_cid
	cid = p_cid
	sel_id = -1
	hint = ""
	_sig = ""


func build() -> void:
	_pick_colonist()
	var head := _title_label.get_parent() as HBoxContainer
	_prev = _nav_button("<", -1)
	_next = _nav_button(">", 1)
	head.add_child(_prev)
	head.add_child(_next)
	head.move_child(_prev, head.get_child_count() - 3)
	head.move_child(_next, head.get_child_count() - 2)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(row)
	_doll = GridContainer.new()
	_doll.columns = 2
	_doll.add_theme_constant_override("h_separation", 4)
	_doll.add_theme_constant_override("v_separation", 4)
	row.add_child(_doll)
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 2)
	_grid.add_theme_constant_override("v_separation", 2)
	row.add_child(_grid)
	_side = VBoxContainer.new()
	_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side.custom_minimum_size.x = 200.0
	row.add_child(_side)
	_rebuild()


func refresh() -> void:
	if sim == null or _doll == null:
		return
	var c := sim.colonists.get_by_id(cid)
	if c == null or not c.alive:
		_pick_colonist()
	var key := _signature()
	if key != _sig:
		_rebuild()


# --- state -----------------------------------------------------------------------------------------------------

func _inmates() -> Array[Colonist]:
	var out: Array[Colonist] = []
	for c in sim.colonists.list:
		if c.alive:
			out.append(c)
	return out


func _has_gear(c: Colonist) -> bool:
	return sim.equipment.equipped.has(c.id) or not sim.equipment.stored_of(c.id).is_empty()


func _pick_colonist() -> void:
	var list := _inmates()
	var c := sim.colonists.get_by_id(focus_cid if cid < 0 else cid)
	if c != null and c.alive:
		cid = c.id
		return
	for x in list:
		if _has_gear(x):
			cid = x.id
			return
	cid = list[0].id if not list.is_empty() else -1


func _signature() -> String:
	var eq := sim.equipment
	var ups := ""
	var dur := 0
	var sel := eq.instances.get(sel_id) as GearItem
	if sel != null:
		ups = ",".join(sel.upgrades)
		dur = int(sel.durability)
	return "%d|%d|%s|%s|%s|%s|%d" % [cid, sel_id, hint, str(eq.equipped.get(cid, {})), str(eq.stored_of(cid)), ups, dur]


func _worn_id(slot: String) -> int:
	return int(sim.equipment.equipped.get(cid, {}).get(slot, -1))


func _item(id: int) -> GearItem:
	return sim.equipment.instances.get(id) as GearItem


func _is_worn(g: GearItem) -> bool:
	return g != null and _worn_id(g.slot) == g.id


func _rarity_color(rarity: String) -> Color:
	return Color.html(str(sim.defs.equipment["rarity"].get(rarity, {}).get("color", "#c0c0c8")))


func _base_name(g: GearItem) -> String:
	return str(sim.defs.gear[g.base].get("name", g.base))


# --- interactions (also called by tests) ------------------------------------------------------------------------

func tap_item(id: int) -> void:
	sel_id = id
	hint = ""
	_rebuild()


func tap_slot(slot: String) -> void:
	var worn := _worn_id(slot)
	var g := _item(sel_id)
	if g != null and not _is_worn(g):  # a stored item is selected: the slot is the drop target
		if g.slot == slot:
			do_equip()
		else:
			hint = "%s does not fit the %s slot." % [_base_name(g), _slot_name(slot)]
			_rebuild()
		return
	if worn >= 0:
		sel_id = worn
		hint = ""
	else:
		hint = "Nothing worn in the %s slot. Select a stored item first." % _slot_name(slot)
	_rebuild()


func do_equip() -> void:
	var g := _item(sel_id)
	if g == null or _is_worn(g):
		return
	hint = "Equipped." if sim.equip(cid, sel_id) else "Cannot equip that."
	_rebuild()


func do_unequip() -> void:
	var g := _item(sel_id)
	if g == null or not _is_worn(g):
		return
	hint = "Unequipped." if sim.unequip(cid, g.slot) else "Cannot unequip that."
	_rebuild()


func do_socket(upgrade_id: String) -> void:
	if _item(sel_id) == null:
		return
	hint = "Socketed." if sim.socket(sel_id, upgrade_id) else "Cannot socket that."
	_rebuild()


func step_inmate(dir: int) -> void:
	var list := _inmates()
	if list.is_empty():
		return
	var idx := 0
	for i in list.size():
		if list[i].id == cid:
			idx = i
	cid = list[posmod(idx + dir, list.size())].id
	focus_cid = cid
	sel_id = -1
	hint = ""
	_rebuild()


func _slot_name(slot: String) -> String:
	return str(sim.defs.equipment["slots"].get(slot, {}).get("name", slot))


# --- widgets ---------------------------------------------------------------------------------------------------

func _nav_button(text: String, dir: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(64, 64)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void: step_inmate(dir))
	return b


static func _clear(n: Node) -> void:
	for ch in n.get_children():
		n.remove_child(ch)
		ch.queue_free()


static func _icons() -> GDScript:
	return load(ICONS_PATH) as GDScript if ResourceLoader.exists(ICONS_PATH) else null


static func _icon(base: String) -> Texture2D:
	var s := _icons()
	return s.call("texture", base) as Texture2D if s != null else null


static func _frame(rarity: String) -> Texture2D:
	var s := _icons()
	return s.call("frame", rarity) as Texture2D if s != null else null


func _style(col: Color, width: int, fill: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_border_width_all(width)
	sb.border_color = col
	sb.set_corner_radius_all(4)
	return sb


## One square gear button (icon + rarity frame). Empty slot buttons show a dim name instead.
func _gear_button(size: float, g: GearItem, slot_label: String, selected: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(size, size)
	b.focus_mode = Control.FOCUS_NONE
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.clip_text = true
	var col := DIM
	if g != null:
		col = _rarity_color(g.rarity)
		b.icon = _icon(g.base)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		if b.icon == null:
			b.text = _base_name(g).left(2)
		var fr := _frame(g.rarity)
		if fr != null:
			var t := TextureRect.new()
			t.texture = fr
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_SCALE
			t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			t.set_anchors_preset(Control.PRESET_FULL_RECT)
			b.add_child(t)
	else:
		b.text = slot_label
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_color_override("font_color", DIM)
	var w := 4 if selected else 2
	var edge := Color(1, 1, 1) if selected else col
	var fill := Color(0.16, 0.17, 0.22) if g != null else Color(0.09, 0.1, 0.13)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, _style(edge, w, fill))
	return b


func _rebuild() -> void:
	if sim == null or _doll == null:
		return
	if _item(sel_id) == null or _item(sel_id).owner != cid:
		sel_id = -1
	var c := sim.colonists.get_by_id(cid)
	set_title("Gear: %s" % (c.display_name if c != null else "nobody"))
	_clear(_doll)
	_clear(_grid)
	_clear(_side)
	var sel := _item(sel_id)
	for s: String in _slot_order():
		var wid := _worn_id(s)
		var g := _item(wid) if wid >= 0 else null
		var b := _gear_button(SLOT, g, _slot_name(s), sel != null and sel.id == wid)
		b.pressed.connect(func() -> void: tap_slot(s))
		_doll.add_child(b)
	var stored: Array = sim.equipment.stored_of(cid) if c != null else []
	var cells := maxi(MIN_CELLS, int(ceil(stored.size() / float(COLS))) * COLS)
	for i in cells:
		if i < stored.size():
			var id: int = stored[i]
			var b := _gear_button(CELL, _item(id), "", id == sel_id)
			b.pressed.connect(func() -> void: tap_item(id))
			_grid.add_child(b)
		else:
			var p := Panel.new()
			p.custom_minimum_size = Vector2(CELL, CELL)
			p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			p.add_theme_stylebox_override("panel", _style(Color(0.2, 0.21, 0.26), 1, Color(0.07, 0.08, 0.1)))
			_grid.add_child(p)
	_build_side(sel)
	_sig = _signature()


func _slot_order() -> Array:
	var order := ["head", "hands", "legs", "torso_inner", "torso_outer", "weapon"]
	var out: Array = []
	for s: String in order:
		if sim.defs.equipment["slots"].has(s):
			out.append(s)
	for s: String in sim.equipment.slot_ids():  # slots added to equipment.json later
		if not out.has(s):
			out.append(s)
	return out


func _build_side(sel: GearItem) -> void:
	var card := _make_card(sel)
	_side.add_child(card)
	if sel != null:
		var worn := _is_worn(sel)
		var act := Button.new()
		act.text = "Unequip" if worn else "Equip"
		act.custom_minimum_size = Vector2(0, 64)
		act.focus_mode = Control.FOCUS_NONE
		act.pressed.connect(do_unequip if worn else do_equip)
		_side.add_child(act)
		var free: int = int(sim.defs.equipment["upgrade_slots"].get(sel.rarity, 0)) - sel.upgrades.size()
		if free > 0:
			var l := Label.new()
			l.text = "Socket an upgrade (%d free):" % free
			l.add_theme_font_size_override("font_size", 15)
			_side.add_child(l)
			for u: String in GearPanel.socket_options(sim, sel.id):
				var sb := Button.new()
				sb.text = str(sim.defs.upgrades[u].get("name", u))
				sb.custom_minimum_size = Vector2(0, 64)
				sb.focus_mode = Control.FOCUS_NONE
				sb.pressed.connect(func() -> void: do_socket(u))
				_side.add_child(sb)
	if hint != "":
		var h := Label.new()
		h.text = hint
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h.add_theme_font_size_override("font_size", 15)
		h.add_theme_color_override("font_color", Color(0.95, 0.8, 0.3))
		_side.add_child(h)
	var head := Label.new()
	head.text = "Profile"
	head.add_theme_font_size_override("font_size", 15)
	head.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
	_side.add_child(head)
	for line in _profile_lines():
		var l := Label.new()
		l.text = line
		l.add_theme_font_size_override("font_size", 14)
		_side.add_child(l)


func _profile_lines() -> Array[String]:
	var out: Array[String] = []
	if ResourceLoader.exists(CARD_PATH):
		var s := load(CARD_PATH) as GDScript
		var r: Variant = s.call("profile", sim, cid)
		for x in r:
			out.append(str(x))
		return out
	for k in ["armor_phys", "armor_energy", "damage_mult", "max_hp"]:
		if not StatBlock.IDX.has(k):
			continue
		out.append("%s: %s" % [k.replace("_", " ").capitalize(), str(snappedf(sim.equipment.total(cid, k), 0.01))])
	return out


func _make_card(sel: GearItem) -> Control:
	if ResourceLoader.exists(CARD_PATH):
		var s := load(CARD_PATH) as GDScript
		return s.call("make", sim, sel.id if sel != null else -1) as Control
	var v := VBoxContainer.new()  # fallback: plain text
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if sel == null:
		l.text = "Select an item"
	else:
		l.text = "%s (%s)\n%s" % [_base_name(sel), sel.rarity, GearPanel.stat_line(sel)]
		l.add_theme_color_override("font_color", _rarity_color(sel.rarity))
	v.add_child(l)
	return v
