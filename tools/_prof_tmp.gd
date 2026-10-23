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
	var v3 := sim.traits_v3
	var t := Time.get_ticks_usec()
	for c in sim.colonists.list:
		sim.blocks.block_of(c)
	print("block_of ", (Time.get_ticks_usec() - t) / 1000.0)
	t = Time.get_ticks_usec()
	for c in sim.colonists.list:
		v3.event(c, "day_served")
		v3.event(c, "calm_day")
	print("events ", (Time.get_ticks_usec() - t) / 1000.0)
	t = Time.get_ticks_usec()
	for c in sim.colonists.list:
		sim.debt.state_of(c)
	print("debt state ", (Time.get_ticks_usec() - t) / 1000.0)
	t = Time.get_ticks_usec()
	for c in sim.colonists.list:
		v3.can_add(c, "t_cellmate")
	print("can_add ", (Time.get_ticks_usec() - t) / 1000.0)
	t = Time.get_ticks_usec()
	sim.trait_events._bonds({"a": sim.colonists.list})
	print("bonds ", (Time.get_ticks_usec() - t) / 1000.0)
	t = Time.get_ticks_usec()
	sim.trait_events._on_day(1)
	print("on_day ", (Time.get_ticks_usec() - t) / 1000.0)
	sim.dispose()
	bus.free()
	quit()
