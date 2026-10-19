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
	_build_branches(sim, c, box)  # region PW4
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


# region PW4: specialisation branches (chosen branch label, or pick buttons when eligible)
func _build_branches(sim: Simulation, c: Colonist, box: VBoxContainer) -> void:
	var cid := c.id
	for sk: String in sim.defs.skills["skills"]:
		var opts: Dictionary = sim.perks.branches_of(sk)
		if opts.is_empty():
			continue
		var label := str(sim.defs.skills["skills"][sk].get("label", sk))
		var cur := sim.perks.branch_of(c, sk)
		if cur != "":
			var l := Label.new()
			l.text = "%s: %s" % [label, str(opts[cur].get("name", cur))]
			l.tooltip_text = str(opts[cur].get("desc", ""))
			box.add_child(l)
		elif sim.perks.branch_pending(c, sk):
			for bid: String in opts:
				var pb := Button.new()
				pb.custom_minimum_size = Vector2(0, 64)
				pb.focus_mode = Control.FOCUS_NONE
				pb.text = "%s branch: %s\n%s" % [label, str(opts[bid].get("name", bid)), str(opts[bid].get("desc", ""))]
				pb.modulate = Color(0.95, 0.8, 0.3)
				pb.set_meta("branch_skill", sk)
				pb.set_meta("branch_id", bid)
				pb.pressed.connect(func() -> void: sim.choose_branch(cid, sk, bid))
				box.add_child(pb)
# endregion
