class_name MetaScreen
extends PanelContainer
## Game-over summary + legacy shop. Touch-first: every button >= 64 px.
## Emits new_link (fresh planet) / next_batch (same planet, new site).

signal new_link(opts: Dictionary)
signal next_batch(seed_value: int, opts: Dictionary)

const BTN := Vector2(0, 72)

var meta: MetaState
var _box: VBoxContainer
var _summary: Dictionary


func _init(p_meta: MetaState, summary: Dictionary) -> void:
	meta = p_meta
	_summary = summary
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 10)
	scroll.add_child(_box)
	_rebuild()


func _label(text: String, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.modulate = color
	_box.add_child(l)
	return l


func _button(text: String, cb: Callable, disabled := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = BTN
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = disabled
	b.pressed.connect(cb)
	_box.add_child(b)
	return b


func _rebuild() -> void:
	for c in _box.get_children():
		c.queue_free()
	var s := _summary
	_label("Sentence over: %s" % str(s.get("reason", "")), Color(1, 0.8, 0.5))
	_label("Days: %d  Contracts: %d  Essence delivered: %d\nFreed: %d  Perks: %d" % [
		int(s.get("days", 0)), int(s.get("contracts", 0)), int(s.get("essence", 0)),
		int(s.get("freed", 0)), int(s.get("perks", 0))])
	_label("Legacy: +%d   (balance: %d)" % [int(s.get("legacy", 0)), meta.balance], Color(0.8, 0.9, 1.0))
	_label("Sentence: %s" % str(meta.defs.presets["presets"].get(meta.preset, {}).get("name", meta.preset)), Color(0.8, 0.9, 1.0))  # region O3
	_button("New Sentence (new planet)", func() -> void: new_link.emit(meta.make_opts()))
	var nb := meta.can_next_batch()
	_button("Next run (same planet, taint ×%.0f%%)" % (
		float(meta.defs.meta["next_batch"]["contamination_keep"]) * 100.0),
		func() -> void:
			var nbd := meta.make_next_batch()
			next_batch.emit(int(nbd["seed"]), nbd["opts"]), not nb)
	_label("Legacy - knowledge, not power:", Color(0.7, 0.7, 0.7))
	var un: Dictionary = meta.defs.meta["unlocks"]
	for id: String in un:
		var u: Dictionary = un[id]
		var why := meta.can_buy(id)
		var txt := "%s — %d\n%s" % [u["name"], int(u["cost"]), u["desc"]]
		if why == "owned":
			if str(u["kind"]) == "crate":
				var sel := meta.crate == id
				_button(("[chosen] " if sel else "") + str(u["name"]), func() -> void:
					meta.select_crate("" if sel else id)
					MetaStore.save_state(meta)
					_rebuild())
			else:
				_label("[owned] " + str(u["name"]), Color(0.6, 1, 0.6))
		else:
			_button(txt, func() -> void:
				if meta.buy(id):
					MetaStore.save_state(meta)
					_rebuild(), why != "")
