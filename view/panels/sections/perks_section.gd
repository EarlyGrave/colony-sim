extends InspectorSection
## Perks button (opens PerkPanel on this colonist) + learned active perks.
## `target["request_panel"]` is a Callable(panel_id, colonist_id) set by InspectorPanel.


func _init() -> void:
	title = "Perks"


func applies(sim: Simulation, target: Dictionary) -> bool:
	var c: Colonist = target.get("colonist")
	return c != null and c.alive and sim.perks != null


func build(sim: Simulation, target: Dictionary, box: VBoxContainer) -> void:
	var c: Colonist = target["colonist"]
	var n := c.perks.learned.size() if c.perks != null else 0
	var pts := 0
	for s: String in sim.defs.skills["skills"]:
		pts += sim.perks.points_available(c, s)
	var b := Button.new()
	b.text = "Perks (%d)%s" % [n, "  *%d" % pts if pts > 0 else ""]
	b.custom_minimum_size = Vector2(0, 64)
	b.focus_mode = Control.FOCUS_NONE
	if pts > 0:
		b.modulate = Color(0.95, 0.8, 0.3)
	var req: Callable = target.get("request_panel", Callable())
	var cid := c.id
	b.pressed.connect(func() -> void:
		if req.is_valid():
			req.call("perks", cid))
	box.add_child(b)
	if c.perks == null:
		return
	for pid: String in c.perks.learned:
		var d := sim.perks.perk_def(pid)
		if str(d.get("type", "")) != "active":
			continue
		var left := sim.perks.cooldown_left(c, pid)
		var ub := Button.new()
		ub.custom_minimum_size = Vector2(0, 64)
		ub.focus_mode = Control.FOCUS_NONE
		var nm := str(d.get("name", pid))
		if left > 0:
			ub.text = "%s (cooldown %d s)" % [nm, ceili(float(left) / Simulation.TICKS_PER_SECOND)]
			ub.disabled = true
		else:
			ub.text = "Use: " + nm
		ub.pressed.connect(func() -> void: sim.use_perk(cid, pid))
		box.add_child(ub)
