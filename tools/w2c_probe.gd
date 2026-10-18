extends Node
## W2c: script time of Hud._process (incl. panels) per frame, panels closed / research / expedition open.
## godot --headless --path . res://tools/w2c_probe.tscn
func _ready() -> void:
	var game := (load("res://view/game.tscn") as PackedScene).instantiate() as GameController
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	var sim: Simulation = game.sim
	for i in 600:
		sim.step()
	var hud: Hud = game.hud
	print("closed  ms/frame: %.3f" % _measure(hud, sim))
	hud.toggle_panel("research")
	print("research ms/frame: %.3f" % _measure(hud, sim))
	hud.close_side()
	if hud._campaign != null:
		hud.open_expedition("expedition")
		print("expedition ms/frame: %.3f" % _measure(hud, sim))
	get_tree().quit()

func _measure(hud: Hud, sim: Simulation) -> float:
	var t := 0
	for i in 400:
		if i % 2 == 0:
			sim.step()
		var a := Time.get_ticks_usec()
		hud._process(0.016)
		t += Time.get_ticks_usec() - a
	return t / 400.0 / 1000.0
