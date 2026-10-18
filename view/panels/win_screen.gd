class_name WinScreen
extends PanelContainer
## S3: shuttle win overlay. Dim background, ending text, run stats, Continue / New Run (>= 64 px).

signal continue_pressed
signal new_run_pressed

const BTN := Vector2(0, 72)
const FALLBACK_TEXT := "The gantry lights burn through the night. You rise above the grey sky, debt unpaid but sentence ended. Below, the planet keeps its poison and its teeth. Somebody else will be sent to dig."

var stats: Dictionary


## Stats keys: days, colonists, debt_paid, pollution (0..1).
static func stats_from(sim: Simulation) -> Dictionary:
	var s := {"days": 0, "colonists": 0, "debt_paid": 0, "pollution": 0.0}
	if sim == null:
		return s
	if sim.get("colonists") != null:
		s["colonists"] = sim.colonists.list.size()
	return s


static func stats_lines(st: Dictionary) -> Array[String]:
	return [
		"Days survived: %d" % int(st.get("days", 0)),
		"Colonists: %d" % int(st.get("colonists", 0)),
		"Debt paid: %d" % int(st.get("debt_paid", 0)),
		"Pollution: %d%%" % int(round(float(st.get("pollution", 0.0)) * 100.0)),
	]


func _init(p_stats: Dictionary = {}, ending_text: String = "") -> void:
	stats = p_stats
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.78)
	add_theme_stylebox_override("panel", sb)
	var c := CenterContainer.new()
	add_child(c)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(520, 0)
	box.add_theme_constant_override("separation", 10)
	c.add_child(box)
	var t := Label.new()
	t.text = "SENTENCE ENDED"
	t.add_theme_font_size_override("font_size", 28)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var body := Label.new()
	body.text = ending_text if ending_text != "" else FALLBACK_TEXT
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body)
	for line in stats_lines(stats):
		var l := Label.new()
		l.text = line
		box.add_child(l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	row.add_child(_btn("Continue", func(): continue_pressed.emit()))
	row.add_child(_btn("New Run", func(): new_run_pressed.emit()))


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = BTN
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	return b
