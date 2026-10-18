extends InspectorSection
## Injury list for the selected colonist (text from HealthPanel).


func _init() -> void:
	title = "Health"


func applies(_sim: Simulation, target: Dictionary) -> bool:
	return target.get("colonist") != null


func build(sim: Simulation, target: Dictionary, box: VBoxContainer) -> void:
	add_line(box, HealthPanel.build(target["colonist"], sim.defs))
