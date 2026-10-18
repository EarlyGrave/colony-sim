extends InspectorSection
## Bills of a workbench-like building: list, add buttons, mode cycle, pause, remove.

const BTN_H := 64


func _init() -> void:
	title = "Bills"


func applies(_sim: Simulation, target: Dictionary) -> bool:
	var b: Building = target.get("building")
	return b != null and b.def.get("bills", false)


func build(sim: Simulation, target: Dictionary, box: VBoxContainer) -> void:
	var b: Building = target["building"]
	add_line(box, "Bills").add_theme_font_size_override("font_size", 20)
	for bl: Bill in sim.crafting.bills_of(b):
		_bill_row(sim, b, bl, box)
	for rid: String in sim.defs.recipes:
		if b.def_id in sim.defs.recipes[rid].get("benches", []):
			var btn := _button("+ " + str(sim.defs.recipes[rid]["name"]))
			var target_n := int(sim.defs.crafting["default_bill_target"])
			btn.pressed.connect(func() -> void: sim.add_bill(b.id, rid, "count", target_n))
			box.add_child(btn)


func _bill_row(sim: Simulation, b: Building, bl: Bill, box: VBoxContainer) -> void:
	var recipe: Dictionary = sim.defs.recipes[bl.recipe_id]
	var text := str(recipe["name"]) + ": " + _mode_text(bl)
	if bl.paused:
		text += " (paused)"
	add_line(box, text)
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(row)
	var modes: Array = sim.defs.crafting["modes"]
	var mode_btn := _button("Mode")
	mode_btn.pressed.connect(func() -> void:
		var next: String = modes[(modes.find(bl.mode) + 1) % modes.size()]
		sim.update_bill(b.id, bl.id, next, bl.target, bl.paused))
	var minus := _button("-")
	minus.pressed.connect(func() -> void: sim.update_bill(b.id, bl.id, bl.mode, maxi(1, bl.target - 1), bl.paused))
	var plus := _button("+")
	plus.pressed.connect(func() -> void: sim.update_bill(b.id, bl.id, bl.mode, bl.target + 1, bl.paused))
	var pause := _button("Pause")
	pause.pressed.connect(func() -> void: sim.update_bill(b.id, bl.id, bl.mode, bl.target, not bl.paused))
	var del := _button("Remove")
	del.pressed.connect(func() -> void: sim.remove_bill(b.id, bl.id))
	for x: Button in [mode_btn, minus, plus, pause, del]:
		row.add_child(x)


func _mode_text(bl: Bill) -> String:
	match bl.mode:
		"count":
			return "make %d times (done %d)" % [bl.target, bl.done]
		"until":
			return "keep %d in stock" % bl.target
	return "forever"


func _button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(BTN_H, BTN_H)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return btn
