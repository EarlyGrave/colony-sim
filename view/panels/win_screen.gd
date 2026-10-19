class_name WinScreen
extends PanelContainer
## S3: shuttle win overlay. Dim background, ending text, run stats, Continue / New Run (>= 64 px).

signal continue_pressed
signal new_run_pressed
signal next_sentence_pressed  # region N2

const BTN := Vector2(0, 64)
const FALLBACK_TEXT := "The gantry lights burn through the night. You rise above the grey sky, debt unpaid but sentence ended. Below, the planet keeps its poison and its teeth. Somebody else will be sent to dig."

var stats: Dictionary
var next_button: Button  # region N2


## 'Balance carried forward' (round(debt_left * debt_carry_frac)) + veteran lines from MetaState.ng after finish_sentence.
static func carry_lines(ng: Dictionary) -> Array[String]:
	var d: Dictionary = ng["dossier"]
	var out: Array[String] = ["Balance carried forward: %d" % int(ng["carry_debt"])]
	if not d.is_empty():
		var perk := str(d["perk_id"])
		out.append("Veteran: %s%s" % [str(d["name"]), (" (%s)" % perk.capitalize().replace("_", " ")) if perk != "" else ""])
	return out


## Stats keys: days, colonists, debt_paid, pollution (0..1).
static func stats_from(sim: Simulation) -> Dictionary:
	var s := {"days": 0, "colonists": 0, "debt_paid": 0, "pollution": 0.0}
	if sim == null:
		return s
	s["colonists"] = sim.colonists.alive_count()
	return s


static func stats_lines(st: Dictionary) -> Array[String]:
	return [
		"Days survived: %d" % int(st.get("days", 0)),
		"Colonists: %d" % int(st.get("colonists", 0)),
		"Debt paid: %d" % int(st.get("debt_paid", 0)),
		"Debt left: %d" % int(st.get("debt_left", 0)),
		"Pollution: %d%%" % int(round(float(st.get("pollution", 0.0)) * 100.0)),
	]


func _init(p_stats: Dictionary = {}, ending_text: String = "", p_ng: Dictionary = {}) -> void:
	stats = p_stats
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # region U3: scrim blocks the world
	var sc := StyleBoxFlat.new()
	sc.bg_color = ModalStyle.SCRIM_COLOR
	add_theme_stylebox_override("panel", sc)
	var c := CenterContainer.new()
	add_child(c)
	var card := PanelContainer.new()
	ModalStyle.apply(card)
	c.add_child(card)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(640, 0)
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	var t := Label.new()
	t.text = "SENTENCE ENDED"
	ModalStyle.style_label(t, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var body := Label.new()
	body.text = ending_text if ending_text != "" else FALLBACK_TEXT
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ModalStyle.style_label(body)
	box.add_child(body)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	box.add_child(grid)
	for line in stats_lines(stats):
		var l := Label.new()
		l.text = line
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ModalStyle.style_label(l)
		grid.add_child(l)
	for cl in carry_lines(p_ng) if not p_ng.is_empty() else ([] as Array[String]):  # region N2
		var cll := Label.new()
		cll.text = cl
		ModalStyle.style_label(cll)
		box.add_child(cll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var cont := _btn("Continue", func(): continue_pressed.emit())
	ModalStyle.style_button(cont, false)
	row.add_child(cont)
	next_button = _btn("Next Sentence", func(): next_sentence_pressed.emit())  # region N2
	ModalStyle.style_button(next_button, true)
	row.add_child(next_button)
	var nr := _btn("New Run", func(): new_run_pressed.emit())
	ModalStyle.style_button(nr, false)
	row.add_child(nr)


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = BTN
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	return b
