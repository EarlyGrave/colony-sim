class_name ColonistBar
extends ScrollContainer
## RimWorld-style colonist cards: icon, name, hp bar, current job, idle flag.

signal colonist_pressed(colonist_id: int)

const SPR := "res://assets/sprites/"
const CARD := Vector2(176, 68)

var sim: Simulation
var _row: HBoxContainer
var _cards := {}  # colonist id -> Dictionary of widgets
var _key := ""


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mouse_filter = Control.MOUSE_FILTER_PASS
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 6)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	custom_minimum_size.y = CARD.y + 4


func bind(p_sim: Simulation) -> void:
	sim = p_sim
	_key = ""
	_clear()


func _clear() -> void:
	for ch in _row.get_children():
		_row.remove_child(ch)
		ch.queue_free()
	_cards.clear()


func refresh() -> void:
	if sim == null:
		return
	var ids := PackedInt32Array()
	for c in sim.colonists.list:
		if c.alive:
			ids.append(c.id)
	var key := ",".join(Array(ids).map(func(i: int) -> String: return str(i)))
	if key != _key:
		_key = key
		_clear()
		for c in sim.colonists.list:
			if c.alive:
				_cards[c.id] = _make_card(c)
	for c in sim.colonists.list:
		if c.alive and _cards.has(c.id):
			_update_card(c, _cards[c.id])


func _make_card(c: Colonist) -> Dictionary:
	var btn := Button.new()
	btn.custom_minimum_size = CARD
	btn.focus_mode = Control.FOCUS_NONE
	var id := c.id
	btn.pressed.connect(func() -> void: colonist_pressed.emit(id))
	_row.add_child(btn)
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_theme_constant_override("separation", 6)
	btn.add_child(hb)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(icon)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 1)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(vb)
	var name_l := _small_label(vb, 17)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.3, 0.3)
	bar.add_theme_stylebox_override("fill", fill)
	vb.add_child(bar)
	var job_l := _small_label(vb, 14)
	var st_l := _small_label(hb, 15)
	st_l.clip_text = false
	st_l.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return {"icon": icon, "name": name_l, "bar": bar, "job": job_l, "state": st_l}


func _small_label(parent: Control, size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## [short text, color] for sleeping / eating / downed / drafted / break.
func _state_of(c: Colonist) -> Array:
	if c.health != null and c.health.downed:
		return ["ЛЕЖ", Color(1.0, 0.4, 0.4)]
	if c.mood != null and c.mood.break_kind != "":
		return ["СРЫВ", Color(1.0, 0.3, 0.3)]
	if c.combat != null and c.combat.drafted:
		return ["БОЙ", Color(1.0, 0.8, 0.3)]
	if c.job != null:
		match c.job.type:
			"sleep":
				return ["ZZ", Color(0.6, 0.7, 1.0)]
			"eat":
				return ["ЕДА", Color(0.6, 1.0, 0.6)]
	return ["", Color.WHITE]


func _update_card(c: Colonist, w: Dictionary) -> void:
	var sprite := "colonist_engineer" if c.engineer else "colonist"
	if c.is_sick(sim.tick):
		sprite += "_sick"
	(w["icon"] as TextureRect).texture = load(SPR + sprite + ".png")
	(w["name"] as Label).text = c.display_name
	(w["bar"] as ProgressBar).value = c.hp / c.max_hp
	var job_l := w["job"] as Label
	var st := _state_of(c)
	var st_l := w["state"] as Label
	st_l.text = st[0]
	st_l.add_theme_color_override("font_color", st[1])
	var idle_col := Color(1.0, 0.75, 0.3)
	if c.hidden:
		job_l.text = "в укрытии"
		job_l.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	elif c.job == null:
		job_l.text = "без дела"
		job_l.add_theme_color_override("font_color", idle_col)
	else:
		job_l.text = c.job.describe()
		job_l.add_theme_color_override("font_color", Color.WHITE)
