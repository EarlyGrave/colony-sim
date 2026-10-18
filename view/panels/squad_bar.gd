class_name SquadBar
extends ScrollContainer
## C5: bottom bar of squad banners (>= 64 px). Tap a banner = select it (then tap the ground
## for squad_hold, tap a creature for squad_focus; the game does that in `_squad_tap`).
## Long-press a banner (0.45 s) = ability radial. Plus "Form squad", "Disband" (selected
## squad) and "Wave" (opens the forecast panel).
##
## Squad API (C1/C2), every call guarded with has_method / get so the bar stays inert until merged:
##   sim.squads.list                       Array of squads {id, name, members:Array[int], role_of:{id:role}, hold:Vector2i, focus:int}
##   sim.form_squad(ids:Array, roles:Array=[]) -> int (roles parallel to ids)
##   sim.disband_squad(sid)   sim.squad_hold(sid, cell)   sim.squad_focus(sid, enemy_id)
##   sim.use_ability(sid, ability_id)   sim.abilities.cooldown_left(sid, ability_id) -> ticks (optional, default 0)

signal forecast_requested()
signal selection_changed(squad_id: int)

const BTN_H := 64.0
const BANNER_W := 104.0
## [ability id, label, role that owns it]
const ABILITIES: Array = [
	["taunt", "Taunt", "bulwark"],
	["volley", "Volley", "lancer"],
	["stabilise", "Stabilise", "medic"],
]
const DEFAULT_ROLES: Array = ["bulwark", "lancer", "medic"]
const FORM_SIZE := 3

## The simulation (or a test double) the bar talks to.
var api: Object
var selected := -1
var radial: AbilityRadial
var banners: Dictionary = {}  ## squad id -> Button
var form_btn: Button
var disband_btn: Button
var wave_btn: Button

var _row: HBoxContainer
var _sig := "?"
var _press_sid := -1


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	custom_minimum_size = Vector2(0, BTN_H)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 6)
	add_child(_row)
	form_btn = _button("Form\nsquad", 92.0)
	form_btn.pressed.connect(form_default)
	disband_btn = _button("Disband", 92.0)
	disband_btn.pressed.connect(disband_selected)
	wave_btn = _button("Wave", 84.0)
	wave_btn.pressed.connect(func() -> void: forecast_requested.emit())
	radial = AbilityRadial.new()
	radial.slot_picked.connect(_on_ability)
	visible = false


func _button(text: String, w: float) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, BTN_H)
	b.add_theme_font_size_override("font_size", 15)
	return b


# --- API adapter (all guarded) ------------------------------------------------------------

static func supports(p_api: Object) -> bool:
	return p_api != null and p_api.has_method("form_squad") and p_api.has_method("squad_hold") and p_api.get("squads") != null


func squad_list() -> Array:
	if api == null:
		return []
	var sq: Variant = api.get("squads")
	if sq == null:
		return []
	var l: Variant = sq.get("list")
	return l if l is Array else []


func squad_by_id(sid: int) -> Variant:
	for s: Variant in squad_list():
		if int(s.id) == sid:
			return s
	return null


func cooldown_left(sid: int, ability: String) -> int:
	for holder in ["abilities", "squads"]:
		var o: Variant = api.get(holder)
		if o != null and o.has_method("cooldown_left"):
			return int(o.cooldown_left(sid, ability))
	return 0


func has_role(s: Variant, role: String) -> bool:
	var ro: Variant = s.get("role_of")
	return ro is Dictionary and role in (ro as Dictionary).values()


## Radial slots for a squad: [id, label, ready, detail].
func ability_slots(sid: int) -> Array:
	var out: Array = []
	var s: Variant = squad_by_id(sid)
	for a: Array in ABILITIES:
		var ok := s != null and has_role(s, str(a[2]))
		var detail := "Ready"
		if not ok:
			detail = "No %s" % str(a[2]).capitalize()
		else:
			var cd := cooldown_left(sid, str(a[0]))
			if cd > 0:
				ok = false
				detail = "%ds" % ceili(float(cd) / float(Simulation.TICKS_PER_SECOND))
		out.append([a[0], a[1], ok, detail])
	return out


# --- commands -----------------------------------------------------------------------------

func select(sid: int) -> void:
	selected = -1 if selected == sid else sid
	selection_changed.emit(selected)
	_sync()


func form_default() -> bool:
	if api == null or not api.has_method("form_squad"):
		return false
	var ids := free_inmates()
	if ids.is_empty():
		return false
	if ids.size() > FORM_SIZE:
		ids = ids.slice(0, FORM_SIZE)
	var roles: Array = []  # C1: roles are parallel to ids; [] lets the sim auto-suggest by affinity
	var sq: Variant = api.get("squads")
	if sq != null and sq.has_method("suggest_roles"):
		roles = Array(sq.suggest_roles(ids))
	else:
		for i in ids.size():
			roles.append(DEFAULT_ROLES[i % DEFAULT_ROLES.size()])
	api.form_squad(ids, roles)
	return true


func disband_selected() -> bool:
	if selected < 0 or api == null or not api.has_method("disband_squad"):
		return false
	api.disband_squad(selected)
	selected = -1
	selection_changed.emit(-1)
	refresh()
	return true


## Living, undowned inmates that belong to no squad, in id order.
func free_inmates() -> Array:
	var out: Array = []
	var cols: Variant = api.get("colonists") if api != null else null
	if cols == null:
		return out
	var taken := {}
	for s: Variant in squad_list():
		for id: Variant in (s.members as Array):
			taken[int(id)] = true
	for c in cols.list:
		if c.alive and not taken.has(c.id) and not (c.health != null and c.health.downed):
			out.append(c.id)
	return out


func _on_ability(ability: String) -> void:
	if radial.squad_id >= 0 and api != null and api.has_method("use_ability"):
		api.use_ability(radial.squad_id, ability)


# --- banners ------------------------------------------------------------------------------

## The bar shows while squads exist, or when a fight is near (alarm / wave warning / wave) so the
## first squad can be formed; otherwise the bottom row stays free for the toast and legend.
func wanted() -> bool:
	if not squad_list().is_empty():
		return true
	if api is Simulation:
		var s := api as Simulation
		var t := s.threats
		return s.alarm or t.wave_active or (t.awakened and t.next_wave_tick >= 0 and t.next_wave_tick - s.tick < int(t.cfg["warning_ticks"]))
	return false


func _signature() -> String:
	var parts: Array[String] = []
	for s: Variant in squad_list():
		parts.append("%d:%s" % [int(s.id), str(s.name)])
	return ",".join(parts)


## Rebuilds the banner row when the squad set changes and refreshes texts every call.
func refresh() -> void:
	visible = supports(api) and wanted()
	if not supports(api):
		return
	if selected >= 0 and squad_by_id(selected) == null:
		selected = -1
		selection_changed.emit(-1)
	var sig := _signature()
	if sig != _sig:
		_sig = sig
		_rebuild()
	for s: Variant in squad_list():
		var b: Button = banners.get(int(s.id))
		if b != null:
			b.text = banner_text(s)
	_sync()


func banner_text(s: Variant) -> String:
	var n := (s.members as Array).size()
	var h: Variant = s.get("hold")
	var f: Variant = s.get("focus")
	var mode := "Free"
	if f is int and int(f) >= 0:
		mode = "Focus"
	elif h is Vector2i and (h as Vector2i).x >= 0:
		mode = "Hold"
	return "%s\n%d · %s" % [str(s.name), n, mode]


func _rebuild() -> void:
	for ch in _row.get_children():
		_row.remove_child(ch)
		if ch != form_btn and ch != disband_btn and ch != wave_btn:
			ch.queue_free()
	banners.clear()
	for s: Variant in squad_list():
		var b := _button("", BANNER_W)
		var sid := int(s.id)
		b.gui_input.connect(banner_input.bind(sid, b))
		_row.add_child(b)
		banners[sid] = b
	_row.add_child(form_btn)
	_row.add_child(disband_btn)
	_row.add_child(wave_btn)


func _sync() -> void:
	for sid: int in banners:
		(banners[sid] as Button).modulate = Color(1.0, 0.85, 0.3) if sid == selected else Color.WHITE
	disband_btn.visible = selected >= 0
	form_btn.disabled = free_inmates().is_empty() if api != null else true
	wave_btn.text = wave_text()


func wave_text() -> String:
	if api is Simulation and (api as Simulation).threats != null:
		var t: ThreatSystem = (api as Simulation).threats
		if t.wave_active:
			return "Wave!\n%d" % t.enemies.size()
		if t.awakened and t.next_wave_tick >= 0:
			var left: int = t.next_wave_tick - (api as Simulation).tick
			if left < int(t.cfg["warning_ticks"]):
				return "Wave\n%.1f h" % (float(left) * 24.0 / float((api as Simulation).ticks_per_day))
	return "Wave"


## Banner touch/mouse handler: a short press selects, a long press opens the ability ring and
## releasing over a slot uses it. Positions are converted to viewport space for the ring.
func banner_input(ev: InputEvent, sid: int, b: Button) -> void:
	if not (ev is InputEventMouseButton or ev is InputEventMouseMotion):
		return
	var gpos := b.get_global_transform_with_canvas() * (ev as InputEventMouse).position
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_press_sid = sid
			radial.set_slots(sid, ability_slots(sid))
			radial.press_begin(gpos)
		else:
			var was_press := _press_sid == sid
			_press_sid = -1
			var long_press := radial.press_end(gpos)
			if was_press and not long_press and Rect2(Vector2.ZERO, b.size).has_point(mb.position):
				select(sid)
	elif _press_sid == sid:
		radial.press_move(gpos)


func _process(delta: float) -> void:
	if radial != null and radial.is_pressing():
		radial.press_tick(delta)
