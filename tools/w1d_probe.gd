extends SceneTree
## Times sim.colonists.tick() on a 250x250 map with 8 colonists and a bot-like colony
## (refinery, dump, beds, farm, workbench, chain). Peaceful (no enemies are spawned).
## godot --headless --path . -s tools/w1d_probe.gd -- --ticks=3000
const Scenario := preload("res://tests/scenario.gd")


func _init() -> void:
	var ticks := 3000
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ticks="):
			ticks = int(a.get_slice("=", 1))
	var bus: Node = load("res://autoload/event_bus.gd").new()
	var sim := Simulation.new(1, bus, null, {"map_w": 250, "map_h": 250})
	sim.start_new_game()
	Scenario.standard_colony(sim, 3)
	var center := sim.map_center()
	while sim.colonists.list.size() < 8:
		sim.colonists.spawn(center + Vector2i(sim.colonists.list.size() % 4, 2))
	var field := Scenario.find_zone_spot(sim, center + Vector2i(6, 6), Vector2i(3, 3))
	for y in 3:
		for x in 3:
			sim.set_zone(field + Vector2i(x, y), "growing")
	var bench := sim.buildings.place("workbench", Scenario.find_spot(sim, "workbench", center + Vector2i(-4, -4), 0), false)
	if bench != null:
		sim.add_bill(bench.id, "essence_rounds", "until", 20)
	var spent := 0
	for i in ticks:
		sim.tick += 1
		sim.crafting.tick()
		sim.needs.tick()
		sim.farming.tick()
		var t := Time.get_ticks_usec()
		sim.colonists.tick()
		spent += Time.get_ticks_usec() - t
		sim.perks.tick()
		sim.health.tick()
		sim.debt.tick()
		sim.mood.tick()
		sim.threats.tick()
		sim.contamination.tick()
		sim.mutation.tick()
		sim.crises.tick()
		sim.storyteller.tick()
		bus.tick_advanced.emit(sim.tick)
		if sim.tick == 1500:
			Scenario.designate_nearest_deposits(sim, 16)
			Scenario.build_chain(sim, true)
	print("colonists.tick avg %.4f ms over %d ticks (colonists=%d stacks=%d)" % [spent / 1000.0 / ticks, ticks, sim.colonists.list.size(), sim.items.stacks.size()])
	sim.dispose()
	bus.free()
	quit()
