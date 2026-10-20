extends TestCase
## F8: gear icon files, loader and fallbacks.


func test_every_gear_base_has_a_16px_alpha_icon() -> void:
	var sim := make_sim(3, false, 40, 40, peaceful_defs())
	var gear: Dictionary = sim.defs.gear
	var n := 0
	for base: String in gear.keys():
		if base.begins_with("_") or not gear[base] is Dictionary:
			continue
		n += 1
		var path := "res://assets/sprites/gear_%s.png" % base
		assert_true(ResourceLoader.exists(path), "icon file for " + base)
		var t := GearIcons.texture(base)
		assert_eq(t.get_size(), Vector2(16, 16), base + " size")
		var img := t.get_image()
		assert_true(img.detect_alpha() != Image.ALPHA_NONE, base + " has alpha")
		assert_eq(img.get_pixel(0, 0).a, 0.0, base + " corner transparent")
	assert_true(n >= 9, "found the gear bases")


func test_fallback_is_non_null() -> void:
	var t := GearIcons.texture("nope")
	assert_true(t != null, "fallback texture")
	assert_eq(t.get_size(), Vector2(16, 16))
	assert_true(GearIcons.texture("nope", "head") != null)


func test_frame_per_rarity_and_socket() -> void:
	var sim := make_sim(3, false, 40, 40, peaceful_defs())
	for rarity: String in sim.defs.equipment["rarity"].keys():
		var f := GearIcons.frame(rarity)
		assert_true(f != null, "frame " + rarity)
		assert_eq(f.get_size(), Vector2(16, 16))
	assert_true(GearIcons.frame("nope") == null)
	assert_eq(GearIcons.socket().get_size(), Vector2(16, 16))
