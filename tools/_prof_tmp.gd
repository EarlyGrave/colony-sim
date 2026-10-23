extends SceneTree


func _init() -> void:
	var bus: Node = load("res://autoload/event_bus.gd").new()
	var d := Defs.get_default().duplicate_defs()
	d.balance["threat"]["enabled"] = false
	d.balance["traits_v3_enabled"] = true
	d.traits_v3 = TraitSystemV3.load_cfg()
	var sim := Simulation.new(3, bus, d)
	sim.start_empty(80, 80)
	for i in 250:
		var c := ColonistGenerator.generate(sim, Vector2i(2 + i % 70, 2 + i / 70))
		sim.colonists.add(c)
	var te := sim.trait_events
	te._on_day(1)
	var t := Time.get_ticks_usec()
	for i in 5:
		te._on_day(2 + i)
	print("full ", (Time.get_ticks_usec() - t) / 5000.0)
	te._need_ids = {}
	t = Time.get_ticks_usec()
	for i in 5:
		te._on_day(2 + i)
	print("no needs ", (Time.get_ticks_usec() - t) / 5000.0)
	t = Time.get_ticks_usec()
	for i in 5:
		te._bonds({"a": sim.colonists.list})
	print("bonds ", (Time.get_ticks_usec() - t) / 5000.0)
	t = Time.get_ticks_usec()
	for i in 5:
		te._essence_holders()
	print("essence ", (Time.get_ticks_usec() - t) / 5000.0)
	print("blocks ", sim.blocks.is_enabled(), " cn ", sim.colonists.list[0].bio["trait_counters"], " ", sim.colonists.list[0].bio["traits_v3"])
	var n := 0
	for c in sim.colonists.list:
		for tid in c.bio["traits_v3"]:
			if sim.traits_v3.cfg["needs"].has(tid):
				n += 1
	print("need holders ", n)
	sim.dispose()
	bus.free()
	quit()
