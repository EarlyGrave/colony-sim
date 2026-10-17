extends InspectorSection


func _init() -> void:
	title = "Постройка"


func applies(_sim: Simulation, target: Dictionary) -> bool:
	return target.get("building") != null


func build(sim: Simulation, target: Dictionary, box: VBoxContainer) -> void:
	var b: Building = target["building"]
	add_line(box, str(b.def["name"])).add_theme_font_size_override("font_size", 24)
	add_line(box, "Прочность %d / %d" % [b.hp, b.max_hp])
	add_bar(box, b.hp / b.max_hp, Color(0.85, 0.3, 0.3))
	if b.is_machine():
		add_line(box, "Состояние %d%%" % b.condition, Color(1, 0.4, 0.4) if b.broken else Color.WHITE)
		if b.broken:
			add_line(box, "СЛОМАНА", Color(1, 0.4, 0.4))
	if not b.recipe.is_empty():
		add_line(box, "Вход: " + _fmt(sim, b.input))
		add_line(box, "Выход: " + _fmt(sim, b.output))


func _fmt(sim: Simulation, d: Dictionary) -> String:
	if d.is_empty():
		return "—"
	var parts: Array[String] = []
	for k in d:
		parts.append("%s %d" % [sim.defs.items[k]["name"], d[k]])
	return ", ".join(parts)
