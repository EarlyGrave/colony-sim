class_name HandbookPanel
extends GamePanel
## "?" Inmate Handbook: all orientation lessons (done = check mark), tap to
## replay the text. Hint density (Full / New / Off) is saved via MetaStore.

var rows: Array[Button] = []
var density_buttons: Array[Button] = []
var _detail: Label


func build() -> void:
	_detail = add_line("Tap a lesson to read it again.")
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var drow := HBoxContainer.new()
	content.add_child(drow)
	var cur := MetaStore.load_hint_density()
	for m: String in MetaStore.HINT_MODES:
		var b := Button.new()
		b.text = m
		b.toggle_mode = true
		b.button_pressed = m == cur
		b.custom_minimum_size = Vector2(80, 64)
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			MetaStore.save_hint_density(m)
			for o in density_buttons:
				o.set_pressed_no_signal(o == b))
		drow.add_child(b)
		density_buttons.append(b)
	var all := TutorialCard.lessons(sim)
	for i in all.size():
		var d: Dictionary = all[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 64)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void:
			_detail.text = "%s\n%s" % [str(d.get("text", "")), str(d.get("reason", ""))])
		content.add_child(b)
		rows.append(b)


func refresh() -> void:
	var all := TutorialCard.lessons(sim)
	var cur := TutorialCard.current_step(sim)
	for i in mini(rows.size(), all.size()):
		var mark := "[x]" if cur > i else "[ ]"
		rows[i].text = "%s %d. %s" % [mark, i + 1, str((all[i] as Dictionary).get("title", ""))]
