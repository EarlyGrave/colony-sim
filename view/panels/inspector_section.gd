class_name InspectorSection
extends RefCounted
## One section of the inspector. Subclass and register in PanelRegistry.
## `target` is a Dictionary: {"kind": "colonist"|"building"|"cell",
## "colonist": Colonist or null, "building": Building or null, "cell": Vector2i}.
## `build()` is re-run a few times per second into a fresh box.

var title := ""


func applies(_sim: Simulation, _target: Dictionary) -> bool:
	return false


func build(_sim: Simulation, _target: Dictionary, _box: VBoxContainer) -> void:
	pass


static func add_line(box: Control, text: String, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", color)
	box.add_child(l)
	return l


static func add_bar(box: Control, frac: float, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.min_value = 0.0
	b.max_value = 1.0
	b.value = clampf(frac, 0.0, 1.0)
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, 12)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	b.add_theme_stylebox_override("fill", fill)
	box.add_child(b)
	return b
