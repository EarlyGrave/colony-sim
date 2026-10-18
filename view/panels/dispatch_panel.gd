class_name DispatchPanel
extends GamePanel
## Sector dispatch sheet (E2): ship bundles, then pick one permanent modifier per tier.
## Assumed API: sim.dispatch_state() -> {enabled, tiers:[{title, done, picked,
## items:[{item, have, need}], choices:[{id, label}]}]}; sim.deliver_dispatch(tier: int);
## sim.pick_dispatch_modifier(tier: int, id: String).

const BTN := Vector2(64, 64)
var _sig := ""
var api: Object  ## test seam: overrides sim for state and commands


static func state_of(s: Object) -> Dictionary:
	if s != null and s.has_method("dispatch_state"):
		var d: Variant = s.call("dispatch_state")
		if d is Dictionary:
			return d
	return {}


func _cmd(m: String, args: Array) -> void:
	if _a() != null and _a().has_method(m):
		_a().callv(m, args)
	_sig = ""
	refresh()


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
		add_line("No dispatch slot available.", Color(0.7, 0.7, 0.7))
		return
	var tiers: Array = st.get("tiers", [])
	for i in tiers.size():
		var t: Dictionary = tiers[i]
		var picked := str(t.get("picked", ""))
		var done := bool(t.get("done", false))
		add_line("Tier %d  %s%s" % [i + 1, str(t.get("title", "")), "  (done)" if done else ""],
			Color(0.6, 0.9, 0.6) if done else Color(1.0, 0.85, 0.4))
		if picked != "":
			add_line("Modifier: %s" % picked, Color(0.8, 0.8, 0.9))
			continue
		if not done:
			for it: Dictionary in t.get("items", []):
				var need := maxf(float(it.get("need", 1)), 1.0)
				add_line("%s %d/%d" % [str(it.get("item", "?")), int(it.get("have", 0)), int(need)])
				var bar := ProgressBar.new()
				bar.max_value = need
				bar.value = minf(float(it.get("have", 0)), need)
				bar.show_percentage = false
				bar.custom_minimum_size = Vector2(0, 14)
				content.add_child(bar)
			var b := Button.new()
			b.text = "Ship bundle"
			b.custom_minimum_size = BTN
			b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(_cmd.bind("deliver_dispatch", [i]))
			content.add_child(b)
		else:
			add_line("Pick a modifier:")
			for c: Dictionary in t.get("choices", []):
				var cb := Button.new()
				cb.text = str(c.get("label", c.get("id", "?")))
				cb.custom_minimum_size = BTN
				cb.focus_mode = Control.FOCUS_NONE
				cb.pressed.connect(_cmd.bind("pick_dispatch_modifier", [i, str(c.get("id", ""))]))
				content.add_child(cb)


func _a() -> Object:
	return api if api != null else sim
