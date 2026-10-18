extends InspectorSection


func _init() -> void:
	title = "Building"


func applies(_sim: Simulation, target: Dictionary) -> bool:
	return target.get("building") != null


func build(sim: Simulation, target: Dictionary, box: VBoxContainer) -> void:
	var b: Building = target["building"]
	add_line(box, str(b.def["name"])).add_theme_font_size_override("font_size", 24)
	add_line(box, "Integrity %d / %d" % [b.hp, b.max_hp])
	add_bar(box, b.hp / b.max_hp, Color(0.85, 0.3, 0.3))
	if b.is_machine():
		add_line(box, "Condition %d%%" % b.condition, Color(1, 0.4, 0.4) if b.broken else Color.WHITE)
		if b.broken:
			add_line(box, "BROKEN", Color(1, 0.4, 0.4))
	if b.def.has("turret") and sim.ammo != null:
		var cap := sim.ammo.turret_capacity()
		add_line(box, "Ammo %d / %d" % [b.ammo, cap], Color(1, 0.5, 0.4) if b.ammo == 0 else Color.WHITE)
		add_bar(box, float(b.ammo) / maxf(1.0, float(cap)), Color(0.9, 0.75, 0.3))
		var conserve := b.ammo_policy == "conserve"
		var pb := Button.new()
		pb.text = "Fire: conserve ammo" if conserve else "Fire: normal"
		pb.custom_minimum_size = Vector2(64, 64)
		pb.focus_mode = Control.FOCUS_NONE
		var bid := b.id
		pb.pressed.connect(func() -> void: sim.set_turret_ammo_policy(bid, "normal" if conserve else "conserve"))
		box.add_child(pb)
	if not b.recipe.is_empty():
		add_line(box, "In: " + _fmt(sim, b.input))
		add_line(box, "Out: " + _fmt(sim, b.output))


func _fmt(sim: Simulation, d: Dictionary) -> String:
	if d.is_empty():
		return "—"
	var parts: Array[String] = []
	for k in d:
		parts.append("%s %d" % [sim.defs.items[k]["name"], d[k]])
	return ", ".join(parts)
