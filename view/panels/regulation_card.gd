class_name RegulationCard
extends GamePanel
## F5 W1 Standing Orders: the open slot as a card (3 stacked buttons, one price line each) plus past picks.
## Reads sim.regulations; answers go through Simulation.choose_regulation.

var _sig := "-"


func build() -> void:
	set_title("Standing Orders")


func refresh() -> void:
	if sim == null or sim.regulations == null:
		return
	var r := sim.regulations
	var sig := "%d:%s:%s" % [r.pending, str(r.chosen), "on" if r.enabled() else "off"]
	if r.pending >= 0:  # the countdown text changes every hour
		sig += ":%d" % (maxi(0, r.expires - sim.tick) * 24 / maxi(1, sim.ticks_per_day))
	if sig == _sig:
		return
	_sig = sig
	for ch in content.get_children():
		content.remove_child(ch)
		ch.queue_free()
	if not r.enabled():
		_wrap("Standing Orders are not in force on this term.", Color(0.7, 0.7, 0.7))
		return
	if r.pending >= 0:
		_slot_card(r, r.pending)
	else:
		_wrap("No order awaits your signature.", Color(0.7, 0.7, 0.7))
	for slot: int in r.chosen:
		var s: Dictionary = r.slots[slot]
		_wrap("%s: %s" % [s["title"], s["options"][r.chosen[slot]]["label"]], Color(0.6, 0.9, 0.6))


func _slot_card(r: RegulationSystem, slot: int) -> void:
	var s: Dictionary = r.slots[slot]
	_wrap(str(s["title"]), Color(1.0, 0.85, 0.4))
	_wrap(str(s["text"]))
	var left := maxi(0, r.expires - sim.tick) * 24.0 / maxf(1.0, float(sim.ticks_per_day))
	_wrap("Decide in %.0f h (otherwise: %s)" % [left, s["options"][s["default"]]["label"]], Color(1.0, 0.7, 0.5))
	for id: String in s["options"]:
		var o: Dictionary = s["options"][id]
		var b := Button.new()
		b.text = str(o["label"])
		b.custom_minimum_size = Vector2(0, 64)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		var why := r.reject_reason(slot, id)
		b.disabled = why != ""
		b.pressed.connect(func() -> void: sim.choose_regulation(slot, id))
		content.add_child(b)
		_wrap(why.capitalize() if why != "" else str(o["price"]), Color(0.75, 0.75, 0.75)).add_theme_font_size_override("font_size", 14)


func _wrap(text: String, color := Color.WHITE) -> Label:
	var l := add_line(text, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
