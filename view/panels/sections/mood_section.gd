extends InspectorSection
## Mood bar and active thoughts for the selected colonist.


func _init() -> void:
	title = "Настроение"


func applies(_sim: Simulation, target: Dictionary) -> bool:
	return target.get("colonist") != null and _sim.mood != null


func build(sim: Simulation, target: Dictionary, box: VBoxContainer) -> void:
	var c: Colonist = target["colonist"]
	var m := sim.mood.state_of(c)
	var col := Color(0.4, 0.8, 0.4)
	if m.value < float(sim.defs.mood["extreme_threshold"]):
		col = Color(0.9, 0.2, 0.2)
	elif m.value < float(sim.defs.mood["minor_threshold"]):
		col = Color(0.9, 0.7, 0.2)
	add_line(box, "Настроение: %d / 100" % roundi(m.value))
	add_bar(box, m.value / 100.0, col)
	if m.break_kind != "":
		add_line(box, "Срыв: " + m.break_kind, Color(0.9, 0.3, 0.3))
	for t: Dictionary in m.thoughts:
		var def: Dictionary = sim.defs.mood["thoughts"].get(t["id"], {})
		add_line(box, "%+d  %s" % [int(t["value"]), str(def.get("label", t["id"]))])
