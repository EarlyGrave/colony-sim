extends TestCase
## O5: long-press radial menu (timing, drift, emulated mouse, slot sizes).


func _menu() -> RadialMenu:
	var m := RadialMenu.new()
	_owned_nodes.append(m)
	return m


func _fire_after(m: RadialMenu, seconds: float) -> bool:
	var fired := false
	var t := 0.0
	while t < seconds:
		fired = m.press_tick(0.01) or fired
		t += 0.01
	return fired


func test_long_press_fires_at_045() -> void:
	var m := _menu()
	m.press_begin(Vector2(300, 300))
	assert_false(_fire_after(m, 0.40), "not before 0.40 s")
	assert_true(_fire_after(m, 0.10), "fires by 0.50 s")
	assert_true(m.is_open)


func test_drift_cancels() -> void:
	var m := _menu()
	m.press_begin(Vector2(300, 300))
	m.press_move(Vector2(330, 300))
	assert_false(_fire_after(m, 1.0))
	assert_false(m.is_open)


func test_small_jitter_still_fires() -> void:
	var m := _menu()
	m.press_begin(Vector2(300, 300))
	m.press_move(Vector2(305, 303))
	assert_true(_fire_after(m, 0.6))


func test_second_finger_cancels() -> void:
	var m := _menu()
	m.press_begin(Vector2(300, 300))
	m.press_cancel()
	assert_false(_fire_after(m, 1.0))


func test_slots_big_and_five() -> void:
	var m := _menu()
	assert_eq(RadialMenu.SLOTS.size(), 8)
	assert_true(RadialMenu.SLOT_SIZE >= 64.0)
	m.open_at(Vector2(600, 400))
	for i in 5:
		for j in range(i + 1, 5):
			assert_true(m.slot_center(i).distance_to(m.slot_center(j)) >= RadialMenu.SLOT_SIZE, "slots do not overlap")


func test_release_on_slot_picks_and_swallows() -> void:
	var m := _menu()
	var got: Array[String] = []
	m.slot_picked.connect(func(id: String) -> void: got.append(id))
	m.press_begin(Vector2(600, 400))
	_fire_after(m, 0.5)
	assert_true(m.press_end(m.slot_center(0)))
	assert_eq(got, ["mine"])
	assert_false(m.is_open)


func test_release_outside_closes() -> void:
	var m := _menu()
	var got: Array[String] = []
	m.slot_picked.connect(func(id: String) -> void: got.append(id))
	m.press_begin(Vector2(600, 400))
	_fire_after(m, 0.5)
	m.press_end(m.center)
	assert_true(got.is_empty())
	assert_false(m.is_open)


func test_emulated_mouse_ignored() -> void:
	var g := GameController.new()
	_owned_nodes.append(g)
	g.radial = RadialMenu.new()
	_owned_nodes.append(g.radial)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = Vector2(300, 300)
	ev.device = InputEvent.DEVICE_ID_EMULATION
	g.o5_feed(ev)
	assert_false(g.radial.is_pressing(), "emulated press ignored")
	ev.device = 0
	g.o5_feed(ev)
	assert_true(g.radial.is_pressing(), "real mouse press tracked")
