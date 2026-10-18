class_name PowerPanel
extends GamePanel
## L4: power networks and generators. Read-only (PowerReader); the only control is the overlay toggle.

var _overlay_btn: Button
var _body: VBoxContainer


## Text rows for the panel; static so tests can check them without a scene.
static func rows(sim: Simulation) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var nets := PowerReader.nets(sim)
	if nets.is_empty():
		out.append({"text": "No power network yet. Research Electrification, place a pole and a generator.", "color": Color(0.7, 0.7, 0.75)})
		return out
	for i in nets.size():
		var n: Dictionary = nets[i]
		var f := float(n["factor"])
		out.append({"text": "Net %d   %s   x%.2f" % [i + 1, PowerReader.chip_text(n), f],
			"color": PowerReader.severity_color(PowerReader.severity(f)), "head": true})
		for gid: Variant in n.get("generators", []):
			var b := sim.buildings.get_by_id(int(gid))
			if b == null:
				continue
			out.append({"text": "  " + generator_line(sim, b), "color": Color.WHITE})
		var users: Array = n.get("consumers", [])
		if not users.is_empty():
			out.append({"text": "  %d consumers, %d poles" % [users.size(), (n.get("poles", []) as Array).size()], "color": Color(0.7, 0.7, 0.75)})
	return out


static func generator_line(sim: Simulation, b: Building) -> String:
	var info := PowerReader.generator_info(sim, b.id)
	var nm := str(b.def.get("name", b.def_id))
	if b.broken:
		return "%s  BROKEN" % nm
	if info.is_empty():
		return nm
	var cap := int(info.get("fuel_cap", 0))
	var state := ("burning" if cap > 0 else "producing") if bool(info.get("burning", false)) else "idle"
	var s := "%s  %s  %d" % [nm, state, roundi(float(info.get("supply", 0.0)))]
	if cap > 0:
		s += "  fuel %d/%d %s" % [int(info.get("fuel", 0)), cap, str(info.get("fuel_item", ""))]
		if int(info.get("fuel", 0)) == 0 and not bool(info.get("burning", false)):
			s += "  NO FUEL"
	if float(info.get("overheat", 0.0)) > 0.6:
		s += "  OVERHEAT %d%%" % roundi(float(info["overheat"]) * 100.0)
	if float(info.get("waste_per_min", 0.0)) > 0.0:
		s += "  waste %.1f/min" % float(info["waste_per_min"])
	return s


func build() -> void:
	_overlay_btn = Button.new()
	_overlay_btn.toggle_mode = true
	_overlay_btn.focus_mode = Control.FOCUS_NONE
	_overlay_btn.custom_minimum_size = Vector2(0, 64)
	_overlay_btn.add_theme_font_size_override("font_size", 17)
	_overlay_btn.button_pressed = PowerReader.overlay_on
	_overlay_btn.toggled.connect(func(on: bool) -> void:
		PowerReader.overlay_on = on
		_sync_btn())
	content.add_child(_overlay_btn)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_body)
	_sync_btn()


func _sync_btn() -> void:
	_overlay_btn.text = "Power overlay: %s" % ("ON" if PowerReader.overlay_on else "off")


func refresh() -> void:
	if _body == null or sim == null:
		return
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	for r: Dictionary in rows(sim):
		var l := InspectorSection.add_line(_body, str(r["text"]), r["color"])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 17 if r.get("head", false) else 15)
	_overlay_btn.set_pressed_no_signal(PowerReader.overlay_on)
	_sync_btn()
