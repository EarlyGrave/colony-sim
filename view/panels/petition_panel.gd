class_name PetitionPanel
extends GamePanel
## Warden-terminal sheet: sentence-commutation petition phases (E1). Read-only on sim;
## delivery goes through Simulation.deliver_petition(phase).
## Assumed API: sim.petition_state() -> {enabled, phase, phases:[{title, done, reward,
## items:[{item, have, need}]}]}; sim.deliver_petition(phase: int).

const BTN := Vector2(64, 64)
var _sig := ""
var api: Object  ## test seam: overrides sim for state and commands


static func state_of(s: Object) -> Dictionary:
	if s != null and s.has_method("petition_state"):
		var d: Variant = s.call("petition_state")
		if d is Dictionary:
			return d
	return {}


static func chip_text(st: Dictionary) -> String:
	if st.is_empty() or not bool(st.get("enabled", true)):
		return ""
	var n := (st.get("phases", []) as Array).size()
	return "Petition P%d/%d" % [mini(int(st.get("phase", 0)) + 1, n), n]


func refresh() -> void:
	var st := state_of(api if api != null else sim)
	var sig := str(st)
	if sig == _sig:
		return
	_sig = sig
	for ch in content.get_children():
		content.remove_child(ch)
		ch.queue_free()
	if st.is_empty():
		add_line("The warden terminal has no petition yet.", Color(0.7, 0.7, 0.7))
		return
	var cur := int(st.get("phase", 0))
	var phases: Array = st.get("phases", [])
	for i in phases.size():
		var ph: Dictionary = phases[i]
		var done := bool(ph.get("done", false))
		add_line("P%d  %s%s" % [i + 1, str(ph.get("title", "")), "  (done)" if done else ""],
			Color(0.6, 0.9, 0.6) if done else (Color(1.0, 0.85, 0.4) if i == cur else Color(0.6, 0.6, 0.65)))
		if str(ph.get("reward", "")) != "":
			add_line("Reward: %s" % str(ph["reward"]), Color(0.8, 0.8, 0.9))
		if done or i != cur:
			continue
		for it: Dictionary in ph.get("items", []):
			var need := maxf(float(it.get("need", 1)), 1.0)
			var have := float(it.get("have", 0))
			add_line("%s %d/%d" % [str(it.get("item", "?")), int(have), int(need)])
			var bar := ProgressBar.new()
			bar.max_value = need
			bar.value = minf(have, need)
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(0, 14)
			content.add_child(bar)
		var b := Button.new()
		b.text = "Deliver"
		b.custom_minimum_size = BTN
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void:
			if _a() != null and _a().has_method("deliver_petition"):
				_a().call("deliver_petition", i)
			_sig = ""
			refresh())
		content.add_child(b)


func _a() -> Object:
	return api if api != null else sim
