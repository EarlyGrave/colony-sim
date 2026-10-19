extends TestCase


func test_modal_contrast_and_sizes() -> void:
	var p := ModalStyle.PANEL_COLOR
	assert_true(p.a >= 0.95)
	assert_true(ModalStyle.SCRIM_COLOR.a >= 0.75)
	assert_true(ModalStyle.contrast(ModalStyle.TITLE_COLOR, p) >= 7.0)
	assert_true(ModalStyle.contrast(ModalStyle.BODY_COLOR, p) >= 4.5)
	assert_true(ModalStyle.contrast(ModalStyle.ACCENT_TEXT, ModalStyle.ACCENT) >= 4.5)
	var w := WinScreen.new({"days": 3})
	var btns: Array = w.find_children("*", "Button", true, false)
	assert_eq(btns.size(), 2)
	for b: Button in btns:
		assert_true(b.custom_minimum_size.y >= 64.0)
	assert_eq(w.mouse_filter, Control.MOUSE_FILTER_STOP)
	w.free()
	for id: String in ModalStyle.MODAL_IDS:
		var gp := PanelRegistry.make_panel(id)
		assert_true(gp != null, id)
		if gp != null:
			var sb := gp.get_theme_stylebox("panel") as StyleBoxFlat
			assert_true(sb.bg_color.a >= 0.95, id)
			gp.free()
