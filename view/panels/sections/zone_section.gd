extends InspectorSection
## Storage zone settings: item filter toggles and priority (whole zone group).

const BTN_H := 64


func _init() -> void:
	title = "Зона хранения"


func applies(sim: Simulation, target: Dictionary) -> bool:
	return target.get("kind") == "cell" and sim.map.get_zone(target["cell"]) != ""


func build(sim: Simulation, target: Dictionary, box: VBoxContainer) -> void:
	var c: Vector2i = target["cell"]
	var zone: Dictionary = sim.defs.zones[sim.map.get_zone(c)]
	add_line(box, "Хранение: " + str(zone["name"])).add_theme_font_size_override("font_size", 20)
	var prios: Array = sim.defs.crafting["priorities"]
	var cur := sim.storage.priority(c)
	var row := HBoxContainer.new()
	box.add_child(row)
	for i in prios.size():
		var btn := _button(("[%s]" if i == cur else "%s") % _prio_name(str(prios[i])))
		btn.pressed.connect(func() -> void: sim.set_zone_priority(c, i))
		row.add_child(btn)
	for item: String in zone["accepts"]:
		var chk := CheckButton.new()
		chk.text = str(sim.defs.items[item]["name"])
		chk.button_pressed = sim.storage.accepts(c, item)
		chk.custom_minimum_size = Vector2(0, BTN_H)
		chk.toggled.connect(func(on: bool) -> void: sim.set_zone_filter(c, item, on))
		box.add_child(chk)


func _prio_name(id: String) -> String:
	match id:
		"low":
			return "Низкий"
		"high":
			return "Высокий"
	return "Обычный"


func _button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(BTN_H, BTN_H)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return btn
