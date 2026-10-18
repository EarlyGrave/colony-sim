extends SceneTree
## Belt stepping bench: 8k belts (serpentine rows) loaded with items.
## godot --headless --path . -s tools/belt_bench.gd

func _init() -> void:
	for every in [3, 12, 40]:
		_run(every)
		_run(every, true)  # L1: +200 mixed nodes
	quit()


func _run(every: int, nodes: bool = false) -> void:
	var w := 100
	var g := BeltGrid.new(w, 100, 5)
	var n := 0
	for y in range(0, 80):
		for x in w:
			var d := 1 if y % 2 == 0 else 3
			if (x == w - 1 and y % 2 == 0) or (x == 0 and y % 2 == 1):
				d = 2
			g.set_belt(Vector2i(x, y), d)
			n += 1
	if nodes:  # region L1: 200 nodes on the serpentine rows (kinds 1..4 cycle)
		for k in 200:
			var y := (k % 40) * 2
			var x := 2 + (k / 40) * 17 + (k % 7)
			g.place_node(1 + k % 4, Vector2i(x, y), 1)
	# sink at the end drains; source refills every 3 ticks per row start
	var ticks := 600
	var t0 := Time.get_ticks_usec()
	var worst := 0
	var stepsum := 0
	for t in ticks:
		if t % every == 0:
			for y in range(0, 80, 2):
				g.insert(Vector2i(0, y), 1)
		var s := Time.get_ticks_usec()
		g.step()
		stepsum += Time.get_ticks_usec() - s
		worst = maxi(worst, Time.get_ticks_usec() - s)
		g.take_ready(Vector2i(0, 79))
	var total := Time.get_ticks_usec() - t0
	print("nodes=%s every=%d " % [nodes, every], "belts=%d items=%d step_ms=%.3f avg_step_ms=%.3f worst_ms=%.3f hash=%d" % [g.belt_count, g.item_count, stepsum / 1000.0 / ticks, total / 1000.0 / ticks, worst / 1000.0, g.state_hash()])
