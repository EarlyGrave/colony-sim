extends SceneTree
## I1: cell block report. Per seed: breaks + riots with blocks off vs on, and the per-block despair spread.
## godot --headless --path . -s tools/block_report.gd [-- --days=60 --seeds=10]


func _init() -> void:
	var days := 60
	var seeds := 10
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--days="):
			days = int(a.get_slice("=", 1))
		elif a.begins_with("--seeds="):
			seeds = int(a.get_slice("=", 1))
	var off_total := 0
	var on_total := 0
	var spread_ok := 0
	for sv in range(1, seeds + 1):
		var off := _run(sv, days, false)
		var on := _run(sv, days, true)
		off_total += int(off["events"])
		on_total += int(on["events"])
		if float(on["spread"]) > 0.0:
			spread_ok += 1
		print("seed %d: events off=%d on=%d spread=%.2f standing=%s" % [sv, off["events"], on["events"], on["spread"], on["standing"]])
	print("TOTAL events off=%d on=%d (ratio %.2f); spread>0 in %d/%d" % [off_total, on_total, float(on_total) / maxf(1.0, off_total), spread_ok, seeds])
	quit()


func _run(sv: int, days: int, blocks_on: bool) -> Dictionary:
	var bus: Node = load("res://autoload/event_bus.gd").new()
	var defs := Defs.get_default().duplicate_defs()
	var sim := Simulation.new(sv, bus, defs)
	sim.start_new_game()
	sim.blocks.cfg["enabled"] = blocks_on
	var events := [0]
	bus.mood_break_started.connect(func(_id: int, _k: String) -> void: events[0] += 1)
	bus.riot_started.connect(func(_id: int) -> void: events[0] += 1)
	var f := sim.map_center() + Vector2i(3, 3)
	sim.set_zone(f, "stockpile")
	var limit := days * sim.ticks_per_day
	var spread := 0.0
	var sums: Dictionary = {}
	while sim.tick < limit and sim.game_over_reason == "":
		if sim.tick % sim.ticks_per_day == 0:
			sim.ledger.record_produced("raw_food", 30, "report")
			sim.items.drop(f, "raw_food", 30)
			sim.ledger.record_produced("refined_essence", 3, "report")
			sim.items.drop(f, "refined_essence", 3)
		sim.step()
	var per: Dictionary = {}
	for c in sim.colonists.list:
		if c.alive and sim.debt.state_of(c) != null:
			var b := sim.blocks.block_of(c)
			var arr: Array = per.get(b, [])
			arr.append(sim.debt.state_of(c).despair)
			per[b] = arr
	var means: Array[float] = []
	for b: String in per:
		var s := 0.0
		for v: float in per[b]:
			s += v
		means.append(s / per[b].size())
	if means.size() >= 2:
		spread = means.max() - means.min()
	var st: Array = []
	for k: String in sim.blocks.standing:
		st.append(snappedf(sim.blocks.standing[k], 0.1))
	sums["standing"] = st
	sim.dispose()
	bus.free()
	return {"events": events[0], "spread": spread, "standing": str(st)}
