extends TestCase


func test_atmosphere_builds_and_params_sane() -> void:
	var a := Atmosphere.new()
	_owned_nodes.append(a)
	a.configure(Vector2(64, 64))
	a.set_tint(Color(0.8, 0.9, 1.0))
	assert_true(Atmosphere.FOG_BEGIN < Atmosphere.FOG_END, "fog start < end")
	assert_true(Atmosphere.FOG_BEGIN > 0.0)
	assert_true(Atmosphere.EDGE_FADE > 0.0 and Atmosphere.EDGE_DARKEN <= 1.0)
	assert_eq(a.env.fog_enabled, Atmosphere.FOG_ENABLED)
	assert_true(a.env.fog_depth_begin < a.env.fog_depth_end)


func test_selection_marker_follows_and_hides() -> void:
	var sim := make_sim(5)
	var m := SelectionMarker.new()
	_owned_nodes.append(m)
	m.refresh(sim)
	assert_true(not m.visible, "hidden with no selection")
	var c: Colonist = sim.colonists.list[0]
	m.select(c.id)
	m.refresh(sim)
	assert_true(m.visible)
	var p := c.visual_pos() + Vector2(0.5, 0.5)
	assert_true(absf(m.position.x - p.x) < 0.01 and absf(m.position.z - p.y) < 0.1, "marker at colonist")
	c.cell += Vector2i(1, 0)
	m.refresh(sim)
	var q := c.visual_pos() + Vector2(0.5, 0.5)
	assert_true(absf(m.position.x - q.x) < 0.01, "marker follows move")
	m.clear()
	m.refresh(sim)
	assert_true(not m.visible, "hidden after clear")
