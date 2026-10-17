extends InspectorSection


func _init() -> void:
	title = "Колонист"


func applies(_sim: Simulation, target: Dictionary) -> bool:
	return target.get("colonist") != null


func build(sim: Simulation, target: Dictionary, box: VBoxContainer) -> void:
	var c: Colonist = target["colonist"]
	var role := " (инженер)" if c.engineer else ""
	add_line(box, c.display_name + role).add_theme_font_size_override("font_size", 24)
	add_line(box, "Здоровье %d / %d" % [c.hp, c.max_hp])
	add_bar(box, c.hp / c.max_hp, Color(0.85, 0.3, 0.3))
	var status := "погиб"
	if c.alive:
		if c.is_sick(sim.tick):
			status = "болен"
		elif c.hidden:
			status = "в укрытии"
		elif c.job:
			status = c.job.describe()
		else:
			status = "без дела"
	add_line(box, "Занят: " + status)
	if c.carry_count > 0:
		add_line(box, "Несёт: %s × %d" % [sim.defs.items[c.carry_item]["name"], c.carry_count])
