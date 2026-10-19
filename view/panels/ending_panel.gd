class_name EndingPanel
extends GamePanel
## EV: "Ending" side sheet. Chosen path, point-of-no-return status and the next action per path.
## Reads sim only; every button calls a Simulation command. Disabled buttons show the reason as text.

const BTN_H := 64.0
const SUSP_MAX := 100.0

var _sig := ""


func refresh() -> void:
	if sim == null or sim.endings == null:
		return
	var sig := str(snapshot(sim))
	if sig == _sig:
		return
	_sig = sig
	for ch in content.get_children():
		content.remove_child(ch)
		ch.queue_free()
	var p := sim.path()
	_label("Path: " + (p.capitalize() if p != "" else "Undecided"))
	if p == "":
		_label("Choose a path in the story first.")
		return
	_label("Point of no return: " + ("PASSED, the path is locked" if sim.endings.is_locked() else "not reached"))
	match p:
		"submit":
			_build_submit()
		"fight":
			_build_fight()
		"escape":
			_build_escape()


## Cheap change signature of everything the sheet shows.
static func snapshot(s: Simulation) -> Array:
	var cb := s.contraband
	var fe := s.fight_escape
	return [s.path(), s.endings.is_locked(), s.shuttle.state(), fe.state_parts(), fe.uplink_ready(), fe.can_contact(),
		cb.escape_credit if cb != null else 0, roundi(cb.suspicion) if cb != null else 0, cb.sales if cb != null else 0]


## "" when allowed, else a short reason.
static func assault_block(s: Simulation) -> String:
	var fe := s.fight_escape
	if fe.assault_done:
		return "Collector destroyed"
	if fe.assault_active():
		return "Assault under way"
	if not fe.uplink_ready():
		return "Needs a powered Uplink Array"
	return ""


static func contact_block(s: Simulation) -> String:
	match s.fight_escape.can_contact():
		"": return ""
		"need_sales": return "Needs %d Ferry sales (%d so far)" % [int(s.fight_escape._ec().get("contact_sales", 3)), s.contraband.sales]
		"done": return "Bandits already contacted"
	return "Not on the Escape path"


static func fee_block(s: Simulation) -> String:
	var fe := s.fight_escape
	if not fe.contacted:
		return "Contact the bandits first"
	if fe.paid:
		return "Fee paid"
	if s.contraband.escape_credit < fe.bandit_fee():
		return "Needs %d credit" % fe.bandit_fee()
	return ""


static func extraction_block(s: Simulation) -> String:
	var fe := s.fight_escape
	if s.endings.won("escape"):
		return "Escaped"
	if fe.counting:
		return "Pickup under way"
	if not fe.paid:
		return "Pay the bandit fee first"
	return ""


func _build_submit() -> void:
	var st := sim.get_shuttle_state()
	_label("Seats on the manifest: %d   (release parts %d/%d)" % [int(st.get("seats", 0)), int(st.get("parts", 0)), int(st.get("need", 0))])
	var row := HBoxContainer.new()
	content.add_child(row)
	var alive := sim.colonists.alive_count()
	var seats := int(st.get("seats", 0))
	var locked := bool(st.get("t_left", 0) > 0)
	var minus := _button("Seat -", func() -> void: sim.set_manifest(seats - 1), row)
	minus.name = "ManifestMinus"
	minus.disabled = locked or seats <= 1
	var plus := _button("Seat +", func() -> void: sim.set_manifest(seats + 1), row)
	plus.name = "ManifestPlus"
	plus.disabled = locked or seats >= alive
	if locked:
		_label("Launch under way, manifest closed.")
	_label("Deliver parts and launch from the Shuttle sheet.")


func _build_fight() -> void:
	var up := sim.fight_escape.uplink()
	var ready := sim.fight_escape.uplink_ready()
	_label("Uplink: " + ("online" if ready else ("unpowered or broken" if up != null else "not built")))
	_action("StartAssault", "Start assault", assault_block(sim), func() -> void: sim.start_assault())


func _build_escape() -> void:
	var cb := sim.contraband
	_bar("Credit", float(cb.escape_credit), maxf(float(sim.fight_escape.bandit_fee()), 1.0), Color(0.4, 0.8, 0.9))
	_bar("Suspicion", cb.suspicion, SUSP_MAX, Color(0.9, 0.4, 0.3))
	_action("ContactBandits", "Contact bandits", contact_block(sim), func() -> void: sim.contact_bandits())
	_action("PayFee", "Pay fee (%d)" % sim.fight_escape.bandit_fee(), fee_block(sim), func() -> void: sim.pay_bandit_fee())
	_action("StartExtraction", "Start extraction", extraction_block(sim), func() -> void: sim.start_extraction())


func _action(nm: String, text: String, reason: String, cb: Callable) -> void:
	var b := _button(text, cb, content)
	b.name = nm
	b.disabled = reason != ""
	if reason != "":
		_label(reason).add_theme_font_size_override("font_size", 14)


func _button(text: String, cb: Callable, parent: Node) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(64, BTN_H)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(func() -> void:
		cb.call()
		_sig = ""
		refresh())
	parent.add_child(b)
	return b


func _label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.y = 40.0
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(l)
	return l


func _bar(nm: String, v: float, mx: float, col: Color) -> void:
	_label("%s %d / %d" % [nm, roundi(v), roundi(mx)])
	var bar := ProgressBar.new()
	bar.name = nm + "Bar"
	bar.max_value = mx
	bar.value = minf(v, mx)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	bar.modulate = col
	content.add_child(bar)
