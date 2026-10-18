class_name MapSwitcher
extends HFlowContainer
## Top-bar chips, one per map (touch-first, >= 64 px). Badges: crates in flight
## and an alarm mark for an unattended map under threat.

signal map_chosen(id: int)
signal expedition_pressed()
signal cargo_pressed()
signal recall_pressed(id: int)  # region B4

const CHIP_MIN := Vector2(120, 64)

var campaign: Object
var _sig := ""
var _timer := 0.0


func _init() -> void:
	add_theme_constant_override("h_separation", 6)
	add_theme_constant_override("v_separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func bind(c: Object) -> void:
	campaign = c
	_sig = ""
	refresh()


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= 0.25:
		_timer = 0.0
		refresh()


func chip_text(id: int) -> String:
	var t := CampaignView.label(campaign, id)
	var f := CampaignView.flight_count(campaign, id)
	if f > 0:
		t += "  [%d]" % f
	if CampaignView.is_alarm(campaign, id):
		t += "  !"
	return t


func refresh() -> void:
	var sig := str(CampaignView.active_id(campaign))
	for m: Dictionary in CampaignView.maps(campaign):
		sig += "|" + chip_text(int(m.get("id", 0)))
	if sig == _sig:
		return
	_sig = sig
	for ch in get_children():
		remove_child(ch)
		ch.queue_free()
	var active := CampaignView.active_id(campaign)
	for m: Dictionary in CampaignView.maps(campaign):
		var id := int(m.get("id", 0))
		var b := _chip(chip_text(id), id == active)
		if CampaignView.is_alarm(campaign, id):
			b.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
			b.add_theme_color_override("font_pressed_color", Color(1.0, 0.45, 0.4))
		b.name = "chip_%d" % id
		b.pressed.connect(func() -> void:
			_sig = ""
			map_chosen.emit(id))
	var e := _chip("Expedition", false)
	e.name = "expedition_btn"
	e.toggle_mode = false
	e.pressed.connect(func() -> void: expedition_pressed.emit())
	for m: Dictionary in CampaignView.maps(campaign):  # region B4: recall unattended outposts
		var rid := int(m.get("id", 0))
		if str(m.get("kind", "")) == "outpost" and rid != active:
			var rb := _chip("Recall " + CampaignView.label(campaign, rid), false)
			rb.name = "recall_%d" % rid
			rb.toggle_mode = false
			rb.pressed.connect(func() -> void:
				_sig = ""
				recall_pressed.emit(rid))
	var cg := _chip("Cargo", false)
	cg.name = "cargo_btn"
	cg.toggle_mode = false
	cg.pressed.connect(func() -> void: cargo_pressed.emit())


func _chip(text: String, on: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_pressed = on
	b.custom_minimum_size = CHIP_MIN
	b.focus_mode = Control.FOCUS_NONE
	add_child(b)
	return b
