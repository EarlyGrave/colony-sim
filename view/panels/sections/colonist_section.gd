extends InspectorSection


func _init() -> void:
	title = "Colonist"


func applies(_sim: Simulation, target: Dictionary) -> bool:
	return target.get("colonist") != null


func build(sim: Simulation, target: Dictionary, box: VBoxContainer) -> void:
	var c: Colonist = target["colonist"]
	var role := " (engineer)" if c.engineer else ""
	add_line(box, c.display_name + role).add_theme_font_size_override("font_size", 24)
	add_line(box, "Health %d / %d" % [c.hp, c.max_hp])
	add_bar(box, c.hp / c.max_hp, Color(0.85, 0.3, 0.3))
	var status := "dead"
	if c.alive:
		if c.is_sick(sim.tick):
			status = "sick"
		elif c.hidden:
			status = "in cover"
		elif c.job:
			status = c.job.describe()
		else:
			status = "idle"
	add_line(box, "Doing: " + status)
	# region N4
	if sim.blocks != null and sim.blocks.is_enabled():
		var bid := sim.blocks.block_of(c)
		var lean := BlocksPanel.leaning_for(sim, bid)
		add_line(box, "Block: %s (Standing %d%s)" % [sim.blocks.cfg["blocks"].get(bid, {}).get("name", bid), roundi(sim.blocks.standing_of(bid)), ", leans " + lean if lean != "" else ""], Color(0.8, 0.8, 0.95))
	# endregion
	if c.carry_count > 0:
		add_line(box, "Carrying: %s%s × %d" % [sim.defs.items[c.carry_item]["name"], "" if c.carry_quality == "" else " (%s)" % sim.quality.quality_name(c.carry_quality), c.carry_count])
	if not c.alive:
		return
	if c.combat != null and c.combat.drafted:
		add_line(box, "On combat alert", Color(1.0, 0.8, 0.3))
	if c.health != null and c.health.downed:
		add_line(box, "Unconscious", Color(1.0, 0.4, 0.4))
	# region C4
	if c.health != null:
		var bd := sim.health.band(c)
		var secs := sim.health.bleed_out_seconds(c)
		var txt := bd.capitalize()
		if secs >= 0:
			txt += " - bleeds out in %ds" % secs
		add_line(box, txt, Color(1.0, 0.4, 0.4) if bd == "down" else (Color(1.0, 0.8, 0.3) if bd == "wounded" else Color(0.6, 0.9, 0.6)))
	# endregion
	if c.needs != null:
		add_line(box, "Food %d%%" % roundi(c.needs.food * 100.0))
		add_bar(box, c.needs.food, Color(0.9, 0.7, 0.2))
		add_line(box, "Rest %d%%" % roundi(c.needs.rest * 100.0))
		add_bar(box, c.needs.rest, Color(0.4, 0.6, 0.95))
	if c.mood != null:
		add_line(box, "Mood %d / 100" % roundi(c.mood.value))
	# region PW3
	var tl: Array = c.bio.get("traits", [])
	for t: String in tl:
		var td := sim.traits.def(t)
		if not td.is_empty():
			add_line(box, "%s - %s" % [td.get("name", t), td.get("desc", "")], Color(0.8, 0.85, 1.0))
	if c.skills != null and not c.skills.levels.is_empty():
		var ids: Array = c.skills.levels.keys()
		ids.sort_custom(func(a: String, b: String) -> bool: return c.skills.level(a) > c.skills.level(b))
		for sid: String in ids:
			var lv := c.skills.level(sid)
			if lv <= 0:
				continue
			var nm: String = str(sim.defs.skills["skills"].get(sid, {}).get("label", sid))
			var badge := " *" if [3, 6, 10].has(lv) else ""
			add_line(box, "%s %d (%d%% speed)%s" % [nm, lv, roundi(c.skills.speed_mult(sim.defs, sid) * 100.0), badge])
	# endregion
