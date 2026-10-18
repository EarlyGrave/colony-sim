extends TestCase
## F2: kill feed + Warden PA banner.


func _game() -> GameController:
	var game := (load("res://view/game.tscn") as PackedScene).instantiate() as GameController
	_owned_nodes.append(game)
	var tree := Engine.get_main_loop() as SceneTree
	var host: Node = tree.current_scene if tree.current_scene != null else tree.root.get_child(tree.root.get_child_count() - 1)
	host.add_child(game)
	return game


func _sort(n: Node) -> void:
	for ch in n.get_children():
		_sort(ch)
	if n is Container:
		(n as Container).notification(Container.NOTIFICATION_SORT_CHILDREN)


func _settle(game: GameController, size: Vector2i, ui_scale: float) -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	root.content_scale_factor = ui_scale
	root.size = size
	for i in 4:
		game.hud._process(0.3)
		_sort(game.hud)


func _fresh() -> Array:
	var feed := FeedTicker.new()
	var pa := PaBanner.new()
	_owned_nodes.append(feed)
	_owned_nodes.append(pa)
	var sim := make_sim(1, true, 24, 24, peaceful_defs())
	var d := FeedDirector.new(feed, pa)
	d.bind(sim)
	return [sim, feed, pa, d]


func test_one_line_per_signal() -> void:
	var r := _fresh()
	var sim: Simulation = r[0]
	var feed: FeedTicker = r[1]
	var pa: PaBanner = r[2]
	var b = sim.bus
	var feed_n := 0
	var pa_n := 0
	var cases: Array = [
		["wave_started", [1, 1.0], false], ["wave_incoming", [Vector2i(1, 1), 10], false],
		["crisis_started", ["x", "t"], false], ["research_completed", ["hand_tools"], false],
		["map_switched", [1], false], ["outpost_lost", [1], false], ["day_started", [5], false],
		["colonist_died", [sim.colonists.list[0].id], false],
		["colonist_downed", [sim.colonists.list[0].id], true], ["building_destroyed", [3], true],
	]
	for c: Array in cases:
		var f0 := feed.line_count()
		var p0 := pa.pending() + (1 if pa.is_active() else 0)
		b.callv("emit_signal", [c[0]] + c[1])
		var df := feed.line_count() - f0
		var dp := pa.pending() + (1 if pa.is_active() else 0) - p0
		if not c[2] and dp == 0 and pa.is_active() and pa.pending() == PaBanner.MAX_QUEUE:
			dp = 1  # queue full: older dropped, still one new line
		assert_eq(df + dp, 1, str(c[0]))
		assert_eq(df == 1, bool(c[2]), str(c[0]) + " surface")
		feed_n += df
		pa_n += dp
	for t: String in feed.texts():
		assert_true(t.length() <= 70, t)
	assert_true(pa.current().length() <= 70, pa.current())
	var before := pa.pending()
	b.day_started.emit(4)
	b.day_started.emit(6)
	assert_eq(pa.pending(), before)


func test_kill_feed_cap_and_expiry() -> void:
	var r := _fresh()
	var sim: Simulation = r[0]
	var feed: FeedTicker = r[1]
	for i in 10:
		sim.bus.enemy_killed.emit(100 + i)
	assert_eq(feed.line_count(), 3)
	assert_eq(feed.get_child_count(), 3)
	feed.advance(3.0)
	assert_eq(feed.line_count(), 3)
	feed.advance(4.0)
	assert_eq(feed.line_count(), 0)
	assert_eq(feed.get_child_count(), 0)
	assert_false(feed.visible)


func test_pa_queue_max_two() -> void:
	var r := _fresh()
	var pa: PaBanner = r[2]
	for i in 6:
		pa.announce("line %d" % i)
	assert_eq(pa.current(), "line 0")
	assert_eq(pa.pending(), 2)
	pa.advance(2.6)
	assert_eq(pa.current(), "line 4")
	pa.advance(2.6)
	assert_eq(pa.current(), "line 5")
	pa.advance(2.6)
	assert_false(pa.visible)


func test_turret_kill_cause() -> void:
	var r := _fresh()
	var sim: Simulation = r[0]
	var feed: FeedTicker = r[1]
	var e := Enemy.new(77, "brute", sim.defs.enemies["brute"], Vector2i(3, 3))
	e.hp = 1.0
	sim.threats.enemies.append(e)
	sim.threats.damage_enemy(e, 5.0, "turret")
	assert_eq(feed.line_count(), 1)
	assert_eq(sim.threats.last_kill_cause(), "generic")  # only valid inside the handler


func test_layout_phone() -> void:
	var game := _game()
	game.new_game(2)
	for sz: Array in [[Vector2i(844, 390), 1.0], [Vector2i(2532, 1170), 2.55], [Vector2i(1280, 720), 1.0]]:
		_settle(game, sz[0], sz[1])
		for i in 3:
			game.sim.bus.enemy_killed.emit(500 + i)
		game.sim.bus.wave_started.emit(1, 1.0)
		_settle(game, sz[0], sz[1])
		var hud: Hud = game.hud
		var vr := hud.get_viewport().get_visible_rect()
		var br := hud.pa_banner.get_global_rect()
		var fr := hud.feed_ticker.get_global_rect()
		assert_true(vr.encloses(br), "banner inside " + str(sz[0]))
		assert_true(vr.encloses(fr), "feed inside " + str(sz[0]))
		assert_false(br.intersects(fr), "banner/feed disjoint")
		var stack := [hud._root]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			for ch in n.get_children():
				stack.append(ch)
			if n is Button and (n as Control).is_visible_in_tree():
				var cr := (n as Control).get_global_rect()
				if cr.size.x >= 63.5 and cr.size.y >= 63.5:
					assert_false(cr.intersects(br), "banner over " + (n as Button).text)
					assert_false(cr.intersects(fr), "feed over " + (n as Button).text)
		assert_eq(hud.pa_banner.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		hud.pa_banner.advance(10.0)
		hud.pa_banner.advance(10.0)
		hud.feed_ticker.advance(10.0)
