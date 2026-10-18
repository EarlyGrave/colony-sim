extends TestCase
## K4: FlowField.expand fast path equals a plain reference BFS (bounded, unbounded, incremental).


func _ref(walk: PackedByteArray, w: int, h: int, src: Array[Vector2i], maxd: int) -> PackedInt32Array:
	var d := PackedInt32Array()
	d.resize(w * h)
	d.fill(-1)
	var q: Array[int] = []
	for s in src:
		d[s.y * w + s.x] = 0
		q.append(s.y * w + s.x)
	var head := 0
	while head < q.size():
		var i := q[head]
		head += 1
		var cx := i % w
		var cy := i / w
		if maxd >= 0 and d[i] + 1 > maxd:
			continue
		for k in 8:
			var nx := cx + FlowField.DX[k]
			var ny := cy + FlowField.DY[k]
			if nx < 0 or ny < 0 or nx >= w or ny >= h or d[ny * w + nx] != -1 or walk[ny * w + nx] == 0:
				continue
			if k >= 4 and (walk[cy * w + nx] == 0 or walk[ny * w + cx] == 0):
				continue
			d[ny * w + nx] = d[i] + 1
			q.append(ny * w + nx)
	return d


func test_flow_matches_reference() -> void:
	var w := 40
	var h := 30
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var walk := PackedByteArray()
	walk.resize(w * h)
	walk.fill(1)
	for i in 220:
		walk[rng.randi() % (w * h)] = 0
	var src: Array[Vector2i] = [Vector2i(1, 1), Vector2i(38, 28)]
	for s in src:
		walk[s.y * w + s.x] = 1
	var full := FlowField.new()
	full.build(walk, w, h, src, -1, -1)
	assert_eq(full.dist, _ref(walk, w, h, src, -1), "unbounded")
	assert_true(full.complete)
	var inc := FlowField.new()
	inc.build(walk, w, h, src, -1, 0)
	while not inc.complete:
		inc.expand(37)
	assert_eq(inc.dist, full.dist, "incremental")
	var bounded := FlowField.new()
	bounded.build(walk, w, h, src, 6, -1)
	var r := _ref(walk, w, h, src, 6)
	for y in h:
		for x in w:
			assert_eq(bounded.dist_at(Vector2i(x, y)), r[y * w + x], "bounded %d,%d" % [x, y])
