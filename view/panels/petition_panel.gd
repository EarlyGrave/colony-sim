class_name PetitionPanel
extends GamePanel
## Warden-terminal sheet: sentence-commutation petition phases (E1). Read-only on sim;
## delivery goes through Simulation.deliver_petition(phase) (phase is 1-based).

const BTN := Vector2(64, 64)
var _sig := ""
var api: Object  ## test seam: overrides sim for state and commands


static func state_of(s: Object) -> Dictionary:
	return s.get_petition_state() if s != null else {}


static func chip_text(st: Dictionary) -> String:
	if st.is_empty() or not bool(st.get("enabled", false)):
		return ""
	var total := int(st.get("total", 0))
	var cur := int(st.get("phase", -1))
	if cur < 0:
		return "Petition %d/%d" % [int(st.get("done", 0)), total]
	return "Petition P%d/%d" % [cur, total]


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
		add_line("The warden terminal has no petition yet.", Color(0.7, 0.7, 0.7))
		return
	var cur := int(st.get("phase", -1))
	for row: Dictionary in st.get("phases", []):
		var p := int(row.get("phase", 0))
		var done := bool(row.get("done", false))
		add_line("P%d  %s%s" % [p, str(row.get("title", "")), "  (done)" if done else ""],
			Color(0.6, 0.9, 0.6) if done else (Color(1.0, 0.85, 0.4) if p == cur else Color(0.6, 0.6, 0.65)))
		if str(row.get("reward", "")) != "":
			add_line("Reward: %s" % str(row["reward"]), Color(0.8, 0.8, 0.9))
		if done or p != cur:
			continue
		var req: Dictionary = row.get("required", {})
		var got: Dictionary = row.get("delivered", {})
		var keys := req.keys()
		keys.sort()
		for item: String in keys:
			var need := maxf(float(req[item]), 1.0)
			var have := float(got.get(item, 0))
			add_line("%s %d/%d" % [item, int(have), int(need)])
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
			_a().deliver_petition(p)
			_sig = ""
			refresh())
		content.add_child(b)


func _a() -> Object:
	return api if api != null else sim
