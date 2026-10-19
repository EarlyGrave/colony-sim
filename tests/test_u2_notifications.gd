extends TestCase
## U2: notification stack (max 2 visible, dismiss, expiry, dedupe, clear of speed buttons).


func _host() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.current_scene if tree.current_scene != null else tree.root.get_child(tree.root.get_child_count() - 1)


func _stack() -> NotificationStack:
	var s := NotificationStack.new()
	_owned_nodes.append(s)
	var tree := Engine.get_main_loop() as SceneTree
	_host().add_child(s)
	return s


func test_max_two_visible_and_overflow() -> void:
	var s := _stack()
	s.push("a")
	s.push("b")
	s.push("c")
	assert_eq(s.visible_count(), 2)
	assert_eq(s.count(), 3)
	assert_eq(s.get_child_count(), 3, "two items plus the +N chip")


func test_dismiss_and_clear() -> void:
	var s := _stack()
	s.push("a")
	s.push("b")
	s.dismiss("a")
	assert_eq(s.count(), 1)
	s.clear()
	assert_eq(s.count(), 0)
	assert_false(s.visible)


func test_expiry_real_delta() -> void:
	var s := _stack()
	s.push("info")
	s.push("wave", "wave")
	s.push("warn", "warn")
	s.tick(5.9)
	assert_eq(s.count(), 3)
	s.tick(0.2)
	assert_eq(s.count(), 2, "info expired at 6 s")
	s.tick(4.0)
	assert_eq(s.count(), 1, "wave expired at 10 s")
	s.tick(10.0)
	assert_eq(s.count(), 0, "warning expired at 20 s")


func test_dedupe() -> void:
	var s := _stack()
	s.push("same")
	s.push("same")
	assert_eq(s.count(), 1)


func test_item_tap_area() -> void:
	var s := _stack()
	s.push("a")
	var b := s.get_child(0) as Button
	assert_true(b.custom_minimum_size.y >= 64.0)


func test_clear_of_speed_buttons() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var game := (load("res://view/game.tscn") as PackedScene).instantiate() as GameController
	_owned_nodes.append(game)
	_host().add_child(game)
	var hud := game.hud
	hud.show_message("hello")
	hud.show_message("world")
	var st: NotificationStack = hud._u2_stack
	assert_eq(st.visible_count(), 2)
	var vp := Vector2(844, 390)
	var r := Rect2(vp.x - 8.0 - NotificationStack.WIDTH, 76.0, NotificationStack.WIDTH, 2 * NotificationStack.ITEM_H + 4)
	for b in hud._speed_buttons:
		var br := Rect2(b.global_position, b.size)
		assert_false(br.intersects(r) and br.position.y > 0.0 and br.end.y > 76.0 and br.position.x > r.position.x, "speed button under stack")
