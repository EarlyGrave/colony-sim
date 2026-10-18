extends TestCase
## L4: power view. Voxel models, wire layer, HUD chip text, panel rows (real sim.power).

const SCN := preload("res://tests/scenario.gd")
const FOOT := {"power_pole": Vector2i(1, 1), "coal_generator": Vector2i(2, 2), "nitrogen_extractor": Vector2i(2, 2),
	"nitrogen_turbine": Vector2i(2, 2), "nuclear_reactor": Vector2i(3, 3), "solar_array": Vector2i(2, 2)}


func test_models_parse_fit_footprint_and_part_budget() -> void:
	var models := Building3D._v1_models()
	for id: String in FOOT:
		assert_true(models.has(id), "model " + id)
		assert_true(Building3D.is_3d(id), "height " + id)
		var parts: Array = models[id]["parts"]
		assert_true(parts.size() <= 40, "%s parts %d" % [id, parts.size()])
		var fp: Vector2i = FOOT[id]
		for p: Dictionary in parts:
			var o := Building3D._v1_vec(p["o"])
			var s := Building3D._v1_vec(p["s"])
			if p.has("g") and String(models[id]["groups"][p["g"]].get("anim", "")) == "smoke":
				continue  # smoke puffs drift out of the footprint by design
			assert_true(o.x >= -0.001 and o.z >= -0.001 and o.x + s.x <= fp.x + 0.001 and o.z + s.z <= fp.y + 0.001, "%s part %s outside footprint" % [id, p])
		for g: String in models[id].get("groups", {}):
			assert_true(models[id]["groups"][g].has("pivot"), id + " group pivot")
		var b3 := Building3D.new()
		var mt := b3._v1_type_meshes(id)
		assert_true(mt["static"] != null, id + " static mesh")
		b3.free()


func test_chip_text_three_states() -> void:
	assert_eq(PowerReader.chip_text({"supply": 80.0, "demand": 120.0}), "PWR 80/120 (67%)")
	assert_eq(PowerReader.chip_text({"supply": 245.0, "demand": 180.0}), "PWR 245/180 (100%)")
	assert_eq(PowerReader.chip_text({"supply": 0.0, "demand": 120.0}), "PWR 0/120 (0%)")
	assert_eq(PowerReader.chip_text({}), "")
	assert_eq(PowerReader.severity(1.0), 0)
	assert_eq(PowerReader.severity(0.67), 1)
	assert_eq(PowerReader.severity(0.2), 2)


func test_no_grid_is_silent() -> void:
	var sim := make_sim(5, true, 24, 24, peaceful_defs())
	assert_true(PowerReader.grid(sim) == null, "grid off before any pole")
	assert_true(PowerReader.worst_net(sim).is_empty())
	var layer := PowerLayer.new()
	layer.bind(sim)
	layer.sync(Color.WHITE)
	assert_eq(layer.draw_calls(), 0)
	layer.free()


func test_wires_one_multimesh_per_chunk_and_worst_net() -> void:
	var sim := make_sim(5, true, 64, 64, peaceful_defs())
	PowerScene.build_base(sim, sim.map_center())
	PowerReader.refresh(sim, true)
	assert_true(PowerReader.nets(sim).size() >= 1, "nets")
	var w := PowerReader.worst_net(sim)
	assert_false(w.is_empty())
	assert_eq(PowerReader.chip_text(w), PowerReader.chip_text(sim.power.worst_net()))
	var layer := PowerLayer.new()
	layer.bind(sim)
	layer.sync(Color.WHITE)
	assert_eq(layer.wire_count, sim.power.links.size() / 2)
	assert_true(layer.wire_count > 0)
	assert_true(layer.draw_calls() <= 4, "wire draw calls %d" % layer.draw_calls())
	PowerReader.overlay_on = true
	layer.sync(Color.WHITE)
	assert_eq(layer.wire_count, sim.power.links.size() / 2)
	PowerReader.overlay_on = false
	layer.free()


func test_forty_poles_few_draw_calls() -> void:
	var sim := make_sim(5, true, 64, 64, peaceful_defs())
	var c := Vector2i(34, 34)
	for i in 40:
		sim.buildings.place("power_pole", SCN.find_spot(sim, "power_pole", c + Vector2i(i % 20, (i / 20) * 4), 0), false)
	sim.run_ticks(2)
	PowerReader.refresh(sim, true)
	var layer := PowerLayer.new()
	layer.bind(sim)
	layer.sync(Color.WHITE)
	assert_eq(layer.wire_count, sim.power.links.size() / 2)
	assert_true(layer.wire_count > 20)
	assert_true(layer.draw_calls() <= 2, "draw calls %d" % layer.draw_calls())
	layer.free()


func test_panel_rows() -> void:
	var sim := make_sim(5, true, 64, 64, peaceful_defs())
	PowerReader.refresh(sim, true)
	assert_true(str(PowerPanel.rows(sim)[0]["text"]).begins_with("No power network"))
	var o: Array[int] = []
	o.assign(PowerScene.build_base(sim, sim.map_center())["order"])
	PowerReader.refresh(sim, true)
	var text := ""
	for r: Dictionary in PowerPanel.rows(sim):
		text += str(r["text"]) + "\n"
	assert_true(text.contains("Net 1   PWR"), text)
	assert_true(text.contains("fuel "), text)
	var info := PowerReader.generator_info(sim, o[0])
	assert_eq(info["fuel_item"], "coal")
	assert_true(float(info["waste_per_min"]) > 0.0)
	assert_true(PowerReader.generator_info(sim, o[3]).has("overheat"))


func _sort(n: Node) -> void:
	for ch in n.get_children():
		_sort(ch)
	if n is Container:
		(n as Container).notification(Container.NOTIFICATION_SORT_CHILDREN)


func test_hud_chip_fits_strip_at_phone_sizes() -> void:
	var game := (load("res://view/game.tscn") as PackedScene).instantiate() as GameController
	_owned_nodes.append(game)
	var tree := Engine.get_main_loop() as SceneTree
	var host: Node = tree.current_scene if tree.current_scene != null else tree.root.get_child(tree.root.get_child_count() - 1)
	host.add_child(game)
	game.sim.run_ticks(30)
	var hud := game.hud
	hud._l4_update()
	assert_false(hud._l4_chip.visible, "chip hidden before any pole")
	PowerScene.build_base(game.sim, game.sim.map_center())
	PowerReader.refresh(game.sim, true)
	var root := tree.root
	var old_size := root.size
	var old_scale := root.content_scale_factor
	for s: Array in [[Vector2i(844, 390), 1.0], [Vector2i(2532, 1170), 2.55], [Vector2i(1280, 720), 1.0]]:
		root.content_scale_factor = s[1]
		root.size = s[0]
		for i in 4:
			hud._process(0.3)
			hud._l4_update()
			_sort(hud)
		var chip: Label = hud._l4_chip
		var tag := str(s[0])
		assert_true(chip.visible and chip.text == PowerReader.chip_text(PowerReader.worst_net(game.sim)), tag + " chip text " + chip.text)
		var strip: Rect2 = hud._o4_strip.get_global_rect()
		assert_true(strip.encloses(chip.get_global_rect()), "%s chip %s inside strip %s" % [tag, chip.get_global_rect(), strip])
		var vp := hud.get_viewport().get_visible_rect().size
		assert_true(vp.y - strip.end.y >= vp.y * 0.64, "%s map share" % tag)
		var w := chip.get_theme_font("font").get_string_size(chip.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		assert_true(w <= chip.size.x + 1.0, "%s chip fits %.0f of %.0f" % [tag, w, chip.size.x])
		for other: Label in [hud._clock, hud._stats]:
			assert_false(other.get_global_rect().intersects(chip.get_global_rect()), tag + " chip overlaps " + other.text)
	root.size = old_size
	root.content_scale_factor = old_scale
