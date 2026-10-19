class_name ShuttlePanel
extends GamePanel
## Release Shuttle sheet (S1 sim): parts progress, Launch button, countdown, gantry HP.
## Reads Simulation.get_shuttle_state(); the only command is Simulation.launch_shuttle().
## Assumed state keys: phase (locked/building/ready/countdown/won), parts, need, t_left (ticks), hp, hp_max.

const BTN := Vector2(64, 64)
var _sig := ""
var api: Object  ## test seam: overrides sim for state and commands


static func state_of(s: Object) -> Dictionary:
	if s != null and s.has_method("get_shuttle_state"):
		return s.get_shuttle_state()
	return {}


static func visible_for(st: Dictionary) -> bool:
	var ph := str(st.get("phase", "locked"))
	return not st.is_empty() and ph != "locked" and ph != ""


static func time_text(ticks: int, per_day: int) -> String:
	var pd := maxi(per_day, 1)
	return "%dd %dh" % [ticks / pd, (ticks % pd) * 24 / pd]


static func chip_text(st: Dictionary, per_day: int = 1200) -> String:
	if not visible_for(st):
		return ""
	match str(st.get("phase", "")):
		"countdown":
			return "Launch in " + time_text(int(st.get("t_left", 0)), per_day)
		"won":
			return "Shuttle away"
	return "Shuttle %d/%d" % [int(st.get("parts", 0)), int(st.get("need", 0))]


func refresh() -> void:
	var s := _a()
	var st := state_of(s)
	var sig := str(st)
	if sig == _sig:
		return
	_sig = sig
	for ch in content.get_children():
		content.remove_child(ch)
		ch.queue_free()
	if not visible_for(st):
		add_line("The Release Gantry is not available yet.", Color(0.7, 0.7, 0.7))
		return
	var ph := str(st.get("phase", ""))
	var per_day: int = int(s.get("ticks_per_day")) if s != null and s.get("ticks_per_day") != null else 1200
	var parts := int(st.get("parts", 0))
	var need := maxi(int(st.get("need", 1)), 1)
	add_line("Shuttle parts %d/%d" % [parts, need])
	_bar(need, parts)
	if st.has("hp"):
		var hpm := maxf(float(st.get("hp_max", 100.0)), 1.0)
		add_line("Gantry HP %d/%d" % [int(st.get("hp", 0)), int(hpm)], Color(0.9, 0.7, 0.6))
		_bar(hpm, float(st.get("hp", 0)))
	match ph:
		"building":
			add_line("Deliver parts to the Release Gantry.", Color(0.7, 0.7, 0.8))
		"ready":
			add_line("All parts in place. Launch starts a siege.", Color(1.0, 0.85, 0.4))
			var b := Button.new()
			b.text = "Launch"
			b.custom_minimum_size = BTN
			b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(func() -> void:
				if _a() != null and _a().has_method("launch_shuttle"):
					_a().launch_shuttle()
				_sig = ""
				refresh())
			content.add_child(b)
		"countdown":
			add_line("Launch in " + time_text(int(st.get("t_left", 0)), per_day) + " - defend the gantry!", Color(1.0, 0.6, 0.4))
		"won":
			add_line("The shuttle has left the planet.", Color(0.6, 0.9, 0.6))


func _bar(mx: float, v: float) -> void:
	var bar := ProgressBar.new()
	bar.max_value = mx
	bar.value = minf(v, mx)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	content.add_child(bar)


func _a() -> Object:
	return api if api != null else sim
