extends InspectorSection
## Contamination value of the selected cell and a purify button.


func _init() -> void:
	title = "Заражение"


func applies(sim: Simulation, target: Dictionary) -> bool:
	return target.get("kind") == "cell" and sim.mutation != null and sim.mutation.value_at(target["cell"]) > 0.01


func build(sim: Simulation, target: Dictionary, box: VBoxContainer) -> void:
	var c: Vector2i = target["cell"]
	var v := sim.mutation.value_at(c)
	var state := "слабое заражение"
	if sim.mutation.is_mutated(c):
		state = "мутировавшая"
	elif sim.mutation.is_tainted(c):
		state = "заражённая"
	add_line(box, "Клетка %s: %.2f" % [state, v])
	var btn := Button.new()
	btn.text = "Очистить (%d эссенции)" % int(sim.defs.mutation["purify_cost"])
	btn.custom_minimum_size = Vector2(64, 64)
	btn.pressed.connect(func() -> void: sim.purify_cell(c))
	box.add_child(btn)
