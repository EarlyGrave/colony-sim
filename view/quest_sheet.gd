class_name QuestSheet
extends PanelContainer
## Quest sheet (QU): phone-first dispatch sheet. Per active quest: title, beat progress, Warden text;
## per pending choice: option buttons (>= 64 px) with cost/effect hints and a "Needs ..." line when `requires` is unmet.
## Reads QuestLog + Defs only; answers via Simulation.answer_quest. Styled with ModalStyle.

signal choice_posted(title: String)

var sim: Simulation
var _box: VBoxContainer
var _scroll: ScrollContainer
var _collapsed := false


func _init() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	offset_top = 72.0
	custom_minimum_size.x = 400.0
	ModalStyle.apply(self)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 6)
	_scroll.add_child(_box)


func _signals() -> Array:
	return [sim.bus.quest_started, sim.bus.quest_beat, sim.bus.quest_choice_posted, sim.bus.quest_resolved]


func bind(p_sim: Simulation) -> void:
	sim = p_sim
	if not sim.quests.is_enabled():
		return
	for sig: Signal in _signals():
		sig.connect(_changed)
	sim.bus.quest_choice_posted.connect(_on_posted)
	_refresh()


func unbind() -> void:
	if sim == null:
		return
	for sig: Signal in _signals():
		if sig.is_connected(_changed):
			sig.disconnect(_changed)
	if sim.bus.quest_choice_posted.is_connected(_on_posted):
		sim.bus.quest_choice_posted.disconnect(_on_posted)


func _on_posted(_uid: int, quest_id: String, _opts: Array) -> void:
	choice_posted.emit("%s awaits your answer" % title_of(quest_id))


func _changed(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	if sim != null and not sim.quests.pending.is_empty():
		_collapsed = false
	_refresh()


## Quest title from data; falls back to a readable form of the id.
func title_of(qid: String) -> String:
	var q: Dictionary = sim.defs.quests.get(qid, {})
	return str(q.get("title", qid.replace("_", " ").capitalize()))


## "Beat 2/3" for data quests; code quests have no beat list.
func progress_of(qid: String) -> String:
	var q: Dictionary = sim.defs.quests.get(qid, {})
	var beats: Dictionary = q.get("beats", {})
	var cur := str(sim.quests.quests[qid]["beat"]) if sim.quests.quests.has(qid) else ""
	var keys: Array = beats.keys()
	if cur != "" and keys.has(cur):
		return "Beat %d/%d" % [keys.find(cur) + 1, keys.size()]
	return "Awaiting reply" if not sim.quests.pending_for(qid).is_empty() else "Under way"


func option_hint(qid: String, beat: String, oid: String) -> String:
	var d := _opt_data(qid, beat, oid)
	return str(d.get("hint", ""))


func option_needs(qid: String, beat: String, oid: String) -> String:
	var r: Dictionary = _opt_data(qid, beat, oid).get("requires", {})
	var parts: Array = []
	if r.has("item"):
		parts.append("%d %s" % [int(r.get("n", 1)), str(r["item"])])
	var its: Variant = r.get("items", null)
	if its is Dictionary:
		for k: String in its:
			parts.append("%d %s" % [int(its[k]), k])
	return "Needs " + ", ".join(parts) if not parts.is_empty() else ""


func _opt_data(qid: String, beat: String, oid: String) -> Dictionary:
	var q: Dictionary = sim.defs.quests.get(qid, {})
	var src: Variant = q.get("beats", {}).get(beat, {}).get("options", null)
	if src == null:
		src = q.get("options", null)
	if src is Dictionary:
		return src.get(oid, {})
	if src is Array:
		for o: Dictionary in src:
			if str(o.get("id", "")) == oid:
				return o
	return {}


func _beat_text(qid: String) -> String:
	var cur := str(sim.quests.quests[qid]["beat"])
	return str(sim.defs.quests.get(qid, {}).get("beats", {}).get(cur, {}).get("text", ""))


func _label(text: String, title := false, dim := false) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ModalStyle.style_label(l, title)
	if title:
		l.add_theme_font_size_override("font_size", 18)
	if not title:
		l.add_theme_font_size_override("font_size", 15)
	if dim:
		l.add_theme_color_override("font_color", ModalStyle.BORDER_COLOR)
	return l


func _refresh() -> void:
	for ch in _box.get_children():
		_box.remove_child(ch)
		ch.queue_free()
	if sim == null or not sim.quests.is_enabled() or not sim.quests.has_state():
		visible = false
		return
	visible = true
	var vh := get_viewport().get_visible_rect().size.y if is_inside_tree() else 390.0
	_scroll.custom_minimum_size.y = 0.0 if (_collapsed or sim.quests.pending.is_empty()) else vh * 0.66
	var head := Button.new()
	var np := sim.quests.pending.size()
	head.text = "Dispatches (%d)%s" % [sim.quests.active_ids().size(), "  - %d to answer" % np if np > 0 else ""]
	ModalStyle.style_button(head, np > 0)
	head.add_theme_font_size_override("font_size", 16)
	head.pressed.connect(func() -> void:
		_collapsed = not _collapsed
		_refresh())
	_box.add_child(head)
	if _collapsed:
		return
	for id: String in sim.quests.active_ids():
		var pend := sim.quests.pending_for(id)
		_box.add_child(_label("%s  |  %s" % [title_of(id), progress_of(id)], true))
		var txt := str(pend["text"]) if not pend.is_empty() else _beat_text(id)
		if txt != "":
			_box.add_child(_label("Warden: " + txt))
		if pend.is_empty():
			continue
		for o: Dictionary in pend["options"]:
			_box.add_child(_option_button(pend, o))


func _option_button(p: Dictionary, o: Dictionary) -> Button:
	var qid := str(p["quest"])
	var oid := str(o["id"])
	var lines := str(o["label"])
	var hint := option_hint(qid, str(p["beat"]), oid)
	if hint != "":
		lines += "\n" + hint
	if not bool(o["enabled"]):
		var need := option_needs(qid, str(p["beat"]), oid)
		lines += "\n" + (need if need != "" else "Unavailable")
	var b := Button.new()
	b.text = lines
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.disabled = not bool(o["enabled"])
	ModalStyle.style_button(b, true)
	b.add_theme_font_size_override("font_size", 15)
	var uid := int(p["uid"])
	b.pressed.connect(func() -> void: sim.answer_quest(uid, oid))
	return b
