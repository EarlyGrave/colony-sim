extends SceneTree
## Static memory + VRAM estimate of the map view layers:
##   godot --headless --path . -s tools/mem_probe.gd -- --size=250
## Headless has a dummy renderer, so VRAM is computed from the objects (RGBA8 = 4 B/px).


func _initialize() -> void:
	var size := 250
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--size="):
			size = int(a.substr(7))
	var m0 := Performance.get_monitor(Performance.MEMORY_STATIC)
	var defs := Defs.get_default().duplicate_defs()
	defs.balance["map"]["width"] = size
	defs.balance["map"]["height"] = size
	var sim := Simulation.new(1, load("res://autoload/event_bus.gd").new(), defs)
	sim.start_new_game()
	var m1 := Performance.get_monitor(Performance.MEMORY_STATIC)
	var vp := SubViewport.new()
	root.add_child(vp)
	var wv := WorldView.new()
	wv.lazy_chunks = "--lazy" in OS.get_cmdline_user_args()
	vp.add_child(wv)
	wv._ready()
	wv.bind(sim)
	var m2 := Performance.get_monitor(Performance.MEMORY_STATIC)
	var layer := ChunkLayer.new()
	root.add_child(layer)
	layer.build(size, size, vp.world_2d)
	layer.set_active(ChunkLayer.chunks_in_rect(Rect2(0, 0, 70, 40), size, size))
	if wv.lazy_chunks:
		wv._time = 1.0
		wv.set_resident_chunks(ChunkLayer.chunks_in_rect(Rect2(0, 0, 70, 40), size, size))
		wv.set_resident_chunks(ChunkLayer.chunks_in_rect(Rect2(0, 0, 70, 40), size, size))
		wv.set_resident_chunks(ChunkLayer.chunks_in_rect(Rect2(0, 0, 70, 40), size, size))
	var vram := 0.0
	for v in layer.viewports:
		if v.size.x > 1:
			vram += v.size.x * v.size.y * 4.0
	var tex := 0.0
	for img in wv._chunk_images:
		if img == null:
			continue
		tex += img.get_width() * img.get_height() * 4.0
	var m3 := Performance.get_monitor(Performance.MEMORY_STATIC)
	print("size=%d static MB: sim=%.1f worldview(images)=%.1f chunklayer=%.1f total=%.1f" % [
		size, (m1 - m0) / 1048576.0, (m2 - m1) / 1048576.0, (m3 - m2) / 1048576.0, m3 / 1048576.0])
	print("vram est MB: chunk viewports=%.1f ground ImageTextures=%.1f" % [vram / 1048576.0, tex / 1048576.0])
	quit()
