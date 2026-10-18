extends TestCase

const E := 1
const S := 2
const W := 3


func _line(n: int, tpc: int = 5) -> BeltGrid:
	var g := BeltGrid.new(n + 2, 3, tpc)
	for x in n:
		g.set_belt(Vector2i(x, 1), E)
	return g


func test_item_travels_exactly_n_times_ticks_per_cell() -> void:
	for tpc in [1, 3, 5]:
		var g := _line(7, tpc)
		g.insert(Vector2i(0, 1), 4)
		var last := Vector2i(6, 1)
		for t in 7 * tpc - 1:
			g.step()
			assert_eq(g.peek_ready(last), -1, "arrived early tpc=%d t=%d" % [tpc, t])
		g.step()
		assert_eq(g.peek_ready(last), 4, "not ready after N*tpc, tpc=%d" % tpc)
		assert_eq(g.take_ready(last), 4)


func test_line_of_20_conserves_items() -> void:
	var g := _line(20)
	var made := 0
	for t in 1000:
		if t % 3 == 0 and g.insert(Vector2i(0, 1), made % 5):
			made += 1
		if t % 4 == 0:
			g.take_ready(Vector2i(19, 1))
		g.step()
		assert_eq(g.inserted, g.extracted + g.destroyed + g.item_count)
		assert_eq(g.inserted, made)
	var on_belt := 0
	for i in g.item.size():
		if g.item[i] >= 0:
			on_belt += 1
	assert_eq(on_belt, g.item_count)


func test_blocked_end_stalls_without_loss() -> void:
	var g := _line(5)
	var made := 0
	for t in 300:
		if g.insert(Vector2i(0, 1), 1):
			made += 1
		g.step()
	assert_eq(g.item_count, 5, "one item per cell when jammed")
	assert_eq(g.extracted, 0)
	assert_eq(g.inserted, made)
	assert_eq(g.take_ready(Vector2i(4, 1)), 1)


func test_loop_is_deterministic() -> void:
	var hashes: Array[int] = []
	for run in 2:
		var g := BeltGrid.new(6, 6, 2)
		for x in range(1, 5):
			g.set_belt(Vector2i(x, 1), E)
			g.set_belt(Vector2i(5 - x + 1, 4), W)
		for y in range(1, 4):
			g.set_belt(Vector2i(5, y), S)
		for y in range(2, 5):
			g.set_belt(Vector2i(1, y), 0)
		g.set_belt(Vector2i(5, 4), W)
		g.set_belt(Vector2i(1, 1), E)
		for t in 400:
			if t % 5 == 0:
				g.insert(Vector2i(2, 1), t % 7)
			g.step()
		hashes.append(g.state_hash())
		assert_eq(g.inserted, g.extracted + g.destroyed + g.item_count)
	assert_eq(hashes[0], hashes[1])


func test_head_on_and_removal_counts() -> void:
	var g := BeltGrid.new(4, 1, 1)
	g.set_belt(Vector2i(0, 0), E)
	g.set_belt(Vector2i(1, 0), W)
	g.insert(Vector2i(0, 0), 2)
	for t in 10:
		g.step()
	assert_eq(g.item_at(Vector2i(0, 0)), 2, "head-on belts must not exchange")
	assert_eq(g.remove_belt(Vector2i(0, 0)), 2)
	assert_eq(g.destroyed, 1)
	assert_eq(g.inserted, g.extracted + g.destroyed + g.item_count)


func test_merge_has_single_winner_no_dup() -> void:
	var g := BeltGrid.new(3, 3, 1)
	g.set_belt(Vector2i(0, 1), E)
	g.set_belt(Vector2i(1, 0), S)
	g.set_belt(Vector2i(1, 1), E)
	g.insert(Vector2i(0, 1), 1)
	g.insert(Vector2i(1, 0), 2)
	for t in 3:
		g.step()
	assert_eq(g.item_count, 2)
	assert_eq(g.inserted, g.extracted + g.destroyed + g.item_count)


func test_system_in_simulation() -> void:
	var sim := make_sim(1, false, 10, 10)
	var l := sim.logistics
	assert_true(l.place_belt_cell(Vector2i(2, 2), E))
	assert_true(l.place_belt_cell(Vector2i(3, 2), E))
	assert_false(l.place_belt_cell(Vector2i(-1, 2), E))
	assert_true(l.insert_item(Vector2i(2, 2), "essence_ore"))
	sim.run_ticks(10)
	assert_eq(l.take_ready_item(Vector2i(3, 2)), "essence_ore")
	assert_true(l.remove_belt_cell(Vector2i(3, 2)))
