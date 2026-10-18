extends TestCase
## L1: belt node kinds (splitters, merger) in BeltGrid.

const N := 0
const E := 1
const S := 2
const W := 3


## Splitter at (5,5) flowing E, feeder line on the left; out cells: left=(5,4)->N, front=(6,5)->E, right=(5,6)->S.
func _split(kind_: int) -> BeltGrid:
	var g := BeltGrid.new(12, 12, 2)
	for x in range(0, 5):
		g.set_belt(Vector2i(x, 5), E)
	g.place_node(kind_, Vector2i(5, 5), E)
	g.set_belt(Vector2i(5, 4), N)
	g.set_belt(Vector2i(6, 5), E)
	g.set_belt(Vector2i(5, 6), S)
	return g


## Run feeding items from `items` cycle; sinks drain left/front/right ends unless blocked. Returns counts per slot [l,f,r] by item.
func _run(g: BeltGrid, items: Array, ticks: int, blocked: Array = [], every: int = 1) -> Array:
	var got := [[], [], []]
	var sinks := [Vector2i(5, 4), Vector2i(6, 5), Vector2i(5, 6)]
	var fed := 0
	for t in ticks:
		if t % every == 0 and g.insert(Vector2i(0, 5), items[fed % items.size()]):
			fed += 1
		g.step()
		for s in 3:
			if s in blocked:
				continue
			var it := g.take_ready(sinks[s])
			if it >= 0:
				got[s].append(it)
		assert_eq(g.inserted, g.extracted + g.destroyed + g.item_count)
	return got


func test_basic_round_robin_even() -> void:
	var g := _split(1)
	var got := _run(g, [1], 3000)
	var tot: int = got[0].size() + got[1].size() + got[2].size()
	assert_true(tot >= 1000, "throughput %d" % tot)
	assert_true(absi(got[0].size() - got[1].size()) <= 2 and absi(got[1].size() - got[2].size()) <= 2, "even %s" % [[got[0].size(), got[1].size(), got[2].size()]])


func test_basic_blocked_output_no_loss() -> void:
	var g := _split(1)
	var got := _run(g, [1], 3000, [0])
	assert_true(got[1].size() + got[2].size() > 500)
	assert_true(absi(got[1].size() - got[2].size()) <= 2)
	assert_eq(g.destroyed, 0)


func test_priority_fill_first_then_spill() -> void:
	var g := _split(3)
	var got := _run(g, [1], 600, [], 6)  # below front capacity: no spill
	assert_eq(got[0].size() + got[2].size(), 0)
	assert_true(got[1].size() > 50)
	g = _split(3)
	got = _run(g, [1], 600, [1], 6)  # front blocked: left before right
	assert_eq(got[1].size(), 0)
	assert_true(got[0].size() > 5, "left %d" % got[0].size())
	assert_eq(got[2].size(), 0)
	g = _split(3)
	got = _run(g, [1], 600, [0, 1])  # saturated, front+left blocked: right only
	assert_true(got[2].size() > 100)


func test_priority_reopen() -> void:
	var g := _split(3)
	_run(g, [1], 200, [1])
	assert_true(g.item_at(Vector2i(6, 5)) >= 0)
	g.take_ready(Vector2i(6, 5))
	var before_l := g.extracted
	var got := _run(g, [1], 60, [0, 2])
	assert_true(got[1].size() > 0)


func test_smart_filter_and_overflow() -> void:
	var g := _split(2)
	assert_true(g.set_filter(Vector2i(5, 5), 1, "7"))  # front: item 7
	assert_true(g.set_filter(Vector2i(5, 5), 0, "any"))
	assert_true(g.set_filter(Vector2i(5, 5), 2, "overflow"))
	var got := _run(g, [7, 3, 7, 4], 3000)
	for it in got[1]:
		assert_eq(it, 7)
	assert_true(got[1].size() > 300)
	for it in got[0]:
		assert_true(it != 7, "iron leaked to any-out while front free")
	# every non-7 never on front; overflow empty while free
	assert_eq(got[2].size(), 0)
	# block front and left -> overflow receives
	g = _split(2)
	g.set_filter(Vector2i(5, 5), 1, "7")
	g.set_filter(Vector2i(5, 5), 2, "overflow")
	got = _run(g, [7, 3], 1500, [0, 1])
	assert_true(got[2].size() > 20, "overflow got %d" % got[2].size())


func test_set_filter_validation() -> void:
	var g := _split(1)
	assert_false(g.set_filter(Vector2i(5, 5), 0, "any"), "only smart nodes")
	g = _split(2)
	assert_false(g.set_filter(Vector2i(5, 5), 3, "any"))
	assert_false(g.set_filter(Vector2i(5, 5), 0, "nonsense"))


func _merge(g: BeltGrid) -> void:
	# merger at (5,5) flowing E; inputs: back (4,5)E, left (5,4)S... left of E-flow is north -> input faces S; right is south -> faces N
	g.place_node(4, Vector2i(5, 5), E)
	g.set_belt(Vector2i(4, 5), E)
	g.set_belt(Vector2i(5, 4), S)
	g.set_belt(Vector2i(5, 6), N)
	g.set_belt(Vector2i(6, 5), E)


func test_merger_fair() -> void:
	var g := BeltGrid.new(12, 12, 2)
	_merge(g)
	var a := 0
	var b := 0
	for t in 2000:
		g.insert(Vector2i(5, 4), 1)
		g.insert(Vector2i(5, 6), 2)
		g.step()
		var it := g.take_ready(Vector2i(6, 5))
		if it == 1:
			a += 1
		elif it == 2:
			b += 1
		assert_eq(g.inserted, g.extracted + g.destroyed + g.item_count)
	assert_true(a + b > 300)
	assert_true(absi(a - b) <= maxi(2, (a + b) / 50), "a=%d b=%d" % [a, b])


func test_merger_three_inputs() -> void:
	var g := BeltGrid.new(12, 12, 2)
	_merge(g)
	var c := [0, 0, 0, 0]
	for t in 3000:
		g.insert(Vector2i(4, 5), 0)
		g.insert(Vector2i(5, 4), 1)
		g.insert(Vector2i(5, 6), 2)
		g.step()
		var it := g.take_ready(Vector2i(6, 5))
		if it >= 0:
			c[it] += 1
	assert_true(absi(c[0] - c[1]) <= 3 and absi(c[1] - c[2]) <= 3, str(c))


func _lattice() -> BeltGrid:
	var g := BeltGrid.new(14, 8, 2)
	for x in range(1, 12):
		g.set_belt(Vector2i(x, 1), E)
		g.set_belt(Vector2i(12 - x, 6), W)
	for y in range(1, 6):
		g.set_belt(Vector2i(12, y + 1 if y < 5 else 5), S)
		g.set_belt(Vector2i(0, 6 - y), N)
	g.set_belt(Vector2i(12, 1), S)
	g.place_node(1, Vector2i(4, 1), E)
	g.place_node(2, Vector2i(8, 1), E)
	g.place_node(3, Vector2i(6, 6), W)
	g.place_node(4, Vector2i(3, 6), W)
	g.place_node(4, Vector2i(10, 1), E)
	g.set_belt(Vector2i(4, 2), S)
	g.set_belt(Vector2i(4, 3), S)
	g.set_belt(Vector2i(4, 4), S)
	g.set_belt(Vector2i(4, 5), S)
	g.set_filter(Vector2i(8, 1), 2, "overflow")
	return g


func test_lattice_conservation_and_determinism() -> void:
	var hashes: Array = []
	for run in 2:
		var g := _lattice()
		var hs := []
		for t in 2000:
			if t % 3 == 0:
				g.insert(Vector2i(1, 1), t % 5)
			if t % 7 == 0:
				g.take_ready(Vector2i(0, 1))
			g.step()
			assert_eq(g.inserted, g.extracted + g.destroyed + g.item_count)
			if t == 100 or t == 500 or t == 1999:
				hs.append(g.state_hash())
		hashes.append(hs)
	assert_eq(hashes[0], hashes[1])


func test_hash_unchanged_without_nodes() -> void:
	var g := BeltGrid.new(6, 3, 2)
	for x in 6:
		g.set_belt(Vector2i(x, 1), E)
	g.insert(Vector2i(0, 1), 3)
	var h0 := g.state_hash()
	g.place_node(1, Vector2i(2, 1), E)
	assert_true(g.state_hash() != h0)
	g.remove_node(Vector2i(2, 1))
	assert_eq(g.state_hash(), h0)
	assert_eq(g.node_count, 0)


func test_version_bumps() -> void:
	var g := _split(2)
	var v := g.version
	g.set_filter(Vector2i(5, 5), 0, "any")  # no change
	assert_eq(g.version, v)
	g.set_filter(Vector2i(5, 5), 0, "4")
	assert_true(g.version > v)
	v = g.version
	g.remove_node(Vector2i(5, 5))
	assert_true(g.version > v)


func test_perf_8k_belts_200_nodes() -> void:
	var g := BeltGrid.new(100, 100, 5)
	for y in 80:
		for x in 100:
			var d := 1 if y % 2 == 0 else 3
			if (x == 99 and y % 2 == 0) or (x == 0 and y % 2 == 1):
				d = 2
			g.set_belt(Vector2i(x, y), d)
	for k in 200:
		g.place_node(1 + k % 4, Vector2i(2 + (k / 40) * 17 + (k % 7), (k % 40) * 2), 1)
	var sum := 0
	for t in 300:
		if t % 12 == 0:
			for y in range(0, 80, 2):
				g.insert(Vector2i(0, y), 1)
		var s := Time.get_ticks_usec()
		g.step()
		sum += Time.get_ticks_usec() - s
		g.take_ready(Vector2i(0, 79))
	var avg := sum / 1000.0 / 300.0
	if OS.get_environment("PERF_SKIP_WALL") == "":  # timings are meaningless under sharded load
		assert_true(avg <= 1.0 * 1.5, "avg %.3f ms" % avg)


# region K4
## Splitter feeding a merger side input must take turns with a plain belt on the back input.
func test_splitter_to_merger_fair() -> void:
	var g := BeltGrid.new(12, 12, 2)
	g.place_node(4, Vector2i(5, 5), E)
	g.set_belt(Vector2i(6, 5), E)
	for x in range(0, 5):
		g.set_belt(Vector2i(x, 5), E)
	for y in range(0, 4):
		g.set_belt(Vector2i(5, y), S)
	g.place_node(1, Vector2i(5, 4), S)
	var a := 0
	var b := 0
	for t in 400:
		g.insert(Vector2i(0, 5), 2)
		g.insert(Vector2i(5, 0), 1)
		g.step()
		var it := g.take_ready(Vector2i(6, 5))
		if it == 1:
			a += 1
		elif it == 2:
			b += 1
		assert_eq(g.inserted, g.extracted + g.destroyed + g.item_count)
	assert_true(a + b > 100, "throughput %d" % (a + b))
	assert_true(absi(a - b) <= maxi(2, (a + b) / 50), "splitter=%d belt=%d" % [a, b])
# endregion
