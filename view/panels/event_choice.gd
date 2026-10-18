class_name EventChoicePanel
extends GamePanel
## Pending storyteller choices (wanderers, pod survivors). Buttons call
## Simulation.answer_event; the panel never changes the sim itself.

var _sig := ""


func refresh() -> void:
	if sim == null or sim.storyteller == null:
		return
	var sig := ""
	for p: Dictionary in sim.storyteller.pending:
		sig += "%d:%s;" % [int(p["uid"]), str(p["rescued"])]
	if sig == _sig:
		return
	_sig = sig
	for ch in content.get_children():
		content.remove_child(ch)
		ch.queue_free()
	if sim.storyteller.pending.is_empty():
		add_line("Nothing to decide right now.", Color(0.7, 0.7, 0.7))
		return
	for p: Dictionary in sim.storyteller.pending:
		var c: Colonist = p["colonist"]
		add_line(str(p["text"]), Color(1.0, 0.85, 0.4)).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if c == null:  # storyteller chain choice (no colonist attached)
			var crow := HBoxContainer.new()
			content.add_child(crow)
			var cuid := int(p["uid"])
			_button(crow, str(p["yes_label"]), func() -> void: sim.answer_event(cuid, true))
			_button(crow, str(p["no_label"]), func() -> void: sim.answer_event(cuid, false))
			continue
		add_line("%s, age %d. %s" % [c.display_name, int(c.bio.get("age", 0)), c.bio.get("backstory", "")])
		var tn := ColonistGenerator.trait_names(sim, c)
		if not tn.is_empty():
			add_line("Traits: " + ", ".join(tn))
		if bool(p["rescued"]):
			add_line("Rescued, awaiting treatment.", Color(0.6, 1.0, 0.6))
			continue
		var row := HBoxContainer.new()
		content.add_child(row)
		var uid := int(p["uid"])
		var yes_text := "Rescue" if p["kind"] == "survivor" else "Accept"
		var no_text := "Abandon" if p["kind"] == "survivor" else "Decline"
		_button(row, yes_text, func() -> void: sim.answer_event(uid, true))
		_button(row, no_text, func() -> void: sim.answer_event(uid, false))


func _button(parent: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(120, 64)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
