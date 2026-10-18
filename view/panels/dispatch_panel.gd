class_name DispatchPanel
extends GamePanel
## Sector dispatch sheet (E2): ship the next tier's bundle and pick one permanent modifier with it.
## Commands: Simulation.dispatch_sector(tier, modifier_id); state: get_sector_state().

const BTN := Vector2(64, 64)
var _sig := ""
var api: Object  ## test seam: overrides sim for state and commands


static func state_of(s: Object) -> Dictionary:
	return s.get_sector_state() if s != null else {}


func _ship(tier: int, id: String) -> void:
	_a().dispatch_sector(tier, id)
	_sig = ""
	refresh()


func refresh() -> void:
	var st := state_of(_a())
	var sig := str(st)
	if sig == _sig:
		return
	_sig = sig
	for ch in content.get_children():
		content.remove_child(ch)
		ch.queue_free()
	if st.is_empty() or not bool(st.get("enabled", false)):
		add_line("No dispatch slot available.", Color(0.7, 0.7, 0.7))
		return
	var mods: Array = st.get("modifiers", [])
	var used: Array = []
	for t: Dictionary in st.get("tiers", []):
		if bool(t.get("done", false)):
			used.append(str(t.get("pick", "")))
	var shown_open := false
	for t: Dictionary in st.get("tiers", []):
		var n := int(t.get("tier", 0))
		var done := bool(t.get("done", false))
		add_line("Tier %d  %s%s" % [n, str(t.get("name", "")), "  (done)" if done else ""],
			Color(0.6, 0.9, 0.6) if done else (Color(1.0, 0.85, 0.4) if not shown_open else Color(0.6, 0.6, 0.65)))
		if done:
			for m: Dictionary in mods:
				if str(m.get("id", "")) == str(t.get("pick", "")):
					add_line("Modifier: %s" % str(m.get("name", "")), Color(0.8, 0.8, 0.9))
			continue
		if shown_open:
			continue
		shown_open = true
		var bundle: Dictionary = t.get("bundle", {})
		var have: Dictionary = t.get("have", {})
		var keys := bundle.keys()
		keys.sort()
		for item: String in keys:
			var need := maxf(float(bundle[item]), 1.0)
			add_line("%s %d/%d" % [item, int(have.get(item, 0)), int(need)])
			var bar := ProgressBar.new()
			bar.max_value = need
			bar.value = minf(float(have.get(item, 0)), need)
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(0, 14)
			content.add_child(bar)
		add_line("Ship the bundle and pick a modifier:")
		for m: Dictionary in mods:
			if used.has(str(m.get("id", ""))):
				continue
			var cb := Button.new()
			cb.text = "Ship: %s" % str(m.get("name", m.get("id", "?")))
			cb.custom_minimum_size = BTN
			cb.focus_mode = Control.FOCUS_NONE
			cb.disabled = not bool(t.get("available", false))
			cb.pressed.connect(_ship.bind(n, str(m.get("id", ""))))
			content.add_child(cb)


func _a() -> Object:
	return api if api != null else sim
