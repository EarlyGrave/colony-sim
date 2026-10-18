class_name TutorialCard
extends PanelContainer
## Warden's Orientation card: current lesson, its reason, and two skip buttons.
## Read-only view over `sim.tutorial`; the only writes are the recorded sim
## commands `tutorial_skip_step()` / `tutorial_skip_all()`.

const STEP_COUNT := 12
const DATA_PATH := "res://data/tutorial.json"

var sim: Simulation
var step_index := -1
var title_label: Label
var reason_label: Label
var skip_step_btn: Button
var skip_all_btn: Button


## Lesson definitions: sim.tutorial.steps if present, else data/tutorial.json,
## else generic placeholders (keeps the UI usable before the data lands).
static func lessons(p_sim: Simulation = null) -> Array:
	if p_sim != null and p_sim.get("tutorial") != null:
		var t: Object = p_sim.get("tutorial")
		var s: Variant = t.get("steps")
		if s is Array and not (s as Array).is_empty():
			return s
	if FileAccess.file_exists(DATA_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Array and not (parsed as Array).is_empty():
			return parsed
		if parsed is Dictionary and (parsed as Dictionary).get("steps") is Array:
			return (parsed as Dictionary)["steps"]
	var out: Array = []
	for i in STEP_COUNT:
		out.append({"id": "step_%d" % (i + 1), "title": "Lesson %d" % (i + 1), "text": "", "reason": "", "target": {}, "nudge_ticks": 600})
	return out


## Current step index, lesson count when finished/skipped, -1 when there is no tutorial.
static func current_step(p_sim: Simulation) -> int:
	if p_sim == null or p_sim.get("tutorial") == null:
		return -1
	var t: Object = p_sim.get("tutorial")
	if t.get("skipped") == true:
		return lessons(p_sim).size()
	var v: Variant = t.get("step")
	return int(v) if v != null else -1


func _init() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 0)
	row.add_child(box)
	title_label = Label.new()
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(title_label)
	reason_label = Label.new()
	reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason_label.add_theme_font_size_override("font_size", 15)
	reason_label.modulate = Color(0.85, 0.8, 0.6)
	reason_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(reason_label)
	skip_step_btn = _btn(row, "Skip step")
	skip_step_btn.pressed.connect(func() -> void:
		if sim != null and sim.has_method("tutorial_skip_step"):
			sim.call("tutorial_skip_step"))
	skip_all_btn = _btn(row, "Skip all")
	skip_all_btn.pressed.connect(func() -> void:
		if sim != null and sim.has_method("tutorial_skip_all"):
			sim.call("tutorial_skip_all"))


func _btn(parent: Control, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(100, 64)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 17)
	parent.add_child(b)
	return b


## Fills the labels for lesson `idx` (0-based).
func show_step(idx: int) -> void:
	step_index = idx
	var all := lessons(sim)
	if idx < 0 or idx >= all.size():
		return
	var d: Dictionary = all[idx]
	title_label.text = "Orientation %d/%d  %s: %s" % [idx + 1, all.size(), str(d.get("title", "")), str(d.get("text", ""))]
	reason_label.text = str(d.get("reason", ""))
	reason_label.visible = reason_label.text != ""


func bind(p_sim: Simulation) -> void:
	sim = p_sim
	step_index = -1


## Called every HUD frame; keeps the shown lesson in sync with the sim.
func refresh() -> void:
	var s := current_step(sim)
	if s != step_index and s >= 0 and s < lessons(sim).size():
		show_step(s)
