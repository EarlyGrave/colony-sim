extends InspectorSection


func _init() -> void:
	title = "Cell"


func applies(_sim: Simulation, target: Dictionary) -> bool:
	return target.get("kind") == "cell"


func build(sim: Simulation, target: Dictionary, box: VBoxContainer) -> void:
	var c: Vector2i = target["cell"]
	var lines: Array[String] = []
	match sim.map.get_tile(c):
		MapGrid.Tile.ROCK:
			lines.append("Rock")
		MapGrid.Tile.DEPOSIT:
			lines.append("Essence deposit: %d" % sim.map.get_deposit_amount(c))
		_:
			lines.append("Ground")
	var st := sim.items.get_stack(c)
	if not st.is_empty():
		var qn := "" if st.get("q", "") == "" else " (%s)" % sim.quality.quality_name(str(st["q"]))
		lines.append("%s%s × %d" % [sim.defs.items[st["item"]]["name"], qn, st["count"]])
	var z := sim.map.get_zone(c)
	if z != "":
		lines.append("Zone: " + str(sim.defs.zones[z]["name"]))
	for l in lines:
		add_line(box, l)
