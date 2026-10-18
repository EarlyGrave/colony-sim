extends InspectorSection
## F3: inmate record card (rap sheet, nickname, career counters).


func _init() -> void:
	title = "Record"


func applies(_sim: Simulation, target: Dictionary) -> bool:
	return target.get("colonist") != null


func build(sim: Simulation, target: Dictionary, box: VBoxContainer) -> void:
	var c: Colonist = target["colonist"]
	var nick := ColonistRecord.nickname(c, sim.colonists.rec(c), sim.defs.names)
	if nick != "":
		add_line(box, "%s \"%s\"" % [c.display_name, nick], Color(1.0, 0.85, 0.4))
	var rs := ColonistRecord.rap_sheet(c.id, sim.defs.names)
	add_line(box, "Crime: " + str(rs["crime"]))
	add_line(box, "Sentence: " + str(rs["sentence"]))
	add_line(box, "Complaint: " + str(rs["complaint"]))
	add_line(box, "Last words: \"%s\"" % rs["last_words"], Color(0.7, 0.7, 0.75))
	var r := sim.colonists.rec(c)
	var prey := ColonistRecord.favourite_prey(r)
	var kills := "Kills %d" % ColonistRecord.total_kills(r)
	if prey != "":
		kills += " (mostly %s)" % str(sim.defs.enemies.get(prey, {}).get("name", prey)).to_lower()
	var col := Color(0.8, 0.9, 0.8)
	add_line(box, kills, col)
	add_line(box, "Ore %d | Refined %d | Repairs %d" % [r["ore_mined"], r["refined"], r["repairs"]], col)
	add_line(box, "Belts %d | Downed %d | Raids %d" % [r["belts_repaired"], r["downs"], r["waves_survived"]], col)
