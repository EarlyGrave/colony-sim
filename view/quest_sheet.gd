class_name QuestSheet
extends PanelContainer
## Minimal quest sheet (Q0): active/done quests plus pending N-way choice buttons (>= 64 px).
## Hidden unless q_enabled and a quest has started. Reads QuestLog only; answers via Simulation.answer_quest.

var sim: Simulation
var _box: VBoxContainer
var _collapsed := false


func _init() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	offset_top = 96.0
	custom_minimum_size.x = 420.0
	_box = VBoxContainer.new()
	add_child(_box)


func bind(p_sim: Simulation) -> void:
	sim = p_sim
	if not sim.quests.is_enabled():
		return
	for sig: Signal in [sim.bus.quest_started, sim.bus.quest_beat, sim.bus.quest_choice_posted, sim.bus.quest_resolved]:
		sig.connect(_changed)
	_refresh()


func unbind() -> void:
	if sim == null:
		return
	for sig: Signal in [sim.bus.quest_started, sim.bus.quest_beat, sim.bus.quest_choice_posted, sim.bus.quest_resolved]:
		if sig.is_connected(_changed):
			sig.disconnect(_changed)


func _changed(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	if sim != null and not sim.quests.pending.is_empty():
		_collapsed = false
	_refresh()


func _refresh() -> void:
	for ch in _box.get_children():
		ch.queue_free()
	if sim == null or not sim.quests.is_enabled() or not sim.quests.has_state():
		visible = false
		return
	visible = true
	var head := Button.new()
	head.text = "Dispatches (%d)" % sim.quests.active_ids().size()
	head.custom_minimum_size.y = 64.0
	head.pressed.connect(func() -> void:
		_collapsed = not _collapsed
		_refresh())
	_box.add_child(head)
	if _collapsed:
		return
	for id: String in sim.quests.active_ids():
		var l := Label.new()
		l.text = "%s: %s" % [id, str(sim.quests.quests[id]["beat"])]
		_box.add_child(l)
	for p: Dictionary in sim.quests.pending:
		var t := Label.new()
		t.text = str(p["text"])
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_box.add_child(t)
		for o: Dictionary in p["options"]:
			var b := Button.new()
			b.text = str(o["label"])
			b.disabled = not bool(o["enabled"])
			b.custom_minimum_size.y = 64.0
			var uid := int(p["uid"])
			var oid := str(o["id"])
			b.pressed.connect(func() -> void: sim.answer_quest(uid, oid))
			_box.add_child(b)
