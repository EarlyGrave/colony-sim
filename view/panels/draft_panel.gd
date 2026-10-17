extends GamePanel
## Draft toggles, one big button per colonist. With a drafted colonist selected
## (inspect tool), tap the ground to move or tap a creature to attack.

var _buttons := {}  # colonist id -> Button


func build() -> void:
	add_line("Призвать в строй: призванный колонист не работает и стреляет. Выбери его и нажми на землю (идти) или на врага (атаковать).")
	for c in sim.colonists.list:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 64)
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id := c.id
		b.pressed.connect(func() -> void:
			var col := sim.colonists.get_by_id(id)
			if col != null and col.alive:
				sim.set_drafted(id, not col.combat.drafted)
				refresh())
		content.add_child(b)
		_buttons[c.id] = b


func refresh() -> void:
	for c in sim.colonists.list:
		var b: Button = _buttons.get(c.id)
		if b == null:
			continue
		var w: String = sim.defs.weapons["weapons"][c.combat.weapon]["name"]
		b.disabled = not c.alive
		b.text = "%s (%s) — %s" % [c.display_name, w, "в строю" if c.combat.drafted else "работает"]
		b.modulate = Color(1.0, 0.45, 0.45) if c.combat.drafted else Color.WHITE
