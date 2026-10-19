extends TestCase


func _defs() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/buildings.json"))


func test_every_building_has_3d_or_flat_fallback() -> void:
	for id: String in _defs().keys():
		assert_true(Building3D.has_model(id) or Building3D.FLAT_FALLBACK.has(id), "no 3D/flat entry for " + id)


func test_footprint_transform_matches_sim() -> void:
	var defs := _defs()
	for id: String in defs.keys():
		var sz := Vector2i(int(defs[id]["size"][0]), int(defs[id]["size"][1]))
		var cell := Vector2i(7, 4)
		var ft := Building3D.footprint_transform(cell, sz, 0.5)
		assert_eq(ft["size"], Vector3(sz.x, 0.5, sz.y), id)
		assert_eq(ft["center"], Vector3(cell.x + sz.x * 0.5, 0.25, cell.y + sz.y * 0.5), id)


func test_barrel_angle() -> void:
	assert_eq(Building3D.aim_angle(Vector2(3, 3), Vector2(5, 3)), 0.0)
	assert_true(absf(Building3D.aim_angle(Vector2(3, 3), Vector2(3, 1)) + PI / 2) < 0.0001)
	assert_true(absf(Building3D.aim_angle(Vector2(3, 3), Vector2(3, 6)) - PI / 2) < 0.0001)
	assert_eq(Building3D.barrel_rotation(0.5), -0.5)
