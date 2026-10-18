extends TestCase


func _enemy_ids() -> Array:
	var f := FileAccess.open("res://data/enemies.json", FileAccess.READ)
	var d: Variant = JSON.parse_string(f.get_as_text())
	return (d as Dictionary).keys()


func test_every_enemy_has_sheet_and_frames() -> void:
	var ids := _enemy_ids()
	assert_gt(ids.size(), 0, "no enemies")
	for id: String in ids:
		assert_true(CreatureSheets.has_sheet(id), "missing sheet for " + id)
		var tex := CreatureSheets.get_sheet(id)
		assert_true(tex != null, "sheet not loadable " + id)
		assert_eq(tex.get_width(), CreatureSheets.COLS * CreatureSheets.FRAME)
		assert_eq(tex.get_height(), CreatureSheets.ROWS * CreatureSheets.FRAME)


func test_frame_rects_inside_texture() -> void:
	var tex := CreatureSheets.get_sheet("crawler")
	var bounds := Rect2i(0, 0, tex.get_width(), tex.get_height())
	for r in CreatureSheets.ROWS:
		for c in CreatureSheets.COLS:
			assert_true(bounds.encloses(CreatureSheets.frame_rect(r, c)), "rect %d,%d outside" % [r, c])
	assert_eq(CreatureSheets.frame_index(2, 1), 7)


func test_facing_rows() -> void:
	assert_eq(CreatureSheets.row_for_delta(Vector2(1, 0.1)), CreatureSheets.ROW_RIGHT)
	assert_eq(CreatureSheets.row_for_delta(Vector2(-1, 0.1)), CreatureSheets.ROW_LEFT)
	assert_eq(CreatureSheets.row_for_delta(Vector2(0.1, 1)), CreatureSheets.ROW_DOWN)
	assert_eq(CreatureSheets.row_for_delta(Vector2(0.1, -1)), CreatureSheets.ROW_UP)
	assert_eq(CreatureSheets.row_for_delta(Vector2.ZERO, CreatureSheets.ROW_LEFT), CreatureSheets.ROW_LEFT)


func test_missing_sheet_falls_back() -> void:
	assert_false(CreatureSheets.has_sheet("no_such_creature"))
	assert_true(CreatureSheets.get_sheet("no_such_creature") == null)
