class_name PowerNet
extends RefCounted
## L3: pure topology helper for the power grid. Union-find over poles; buildings in range join the
## networks of the poles they touch. No sim access, deterministic (arrays + ascending order only).

var parent: PackedInt32Array = PackedInt32Array()


func reset(n: int) -> void:
	parent.resize(n)
	for i in n:
		parent[i] = i


func find(i: int) -> int:
	var r := i
	while parent[r] != r:
		r = parent[r]
	while parent[i] != r:  # path compression
		var nx := parent[i]
		parent[i] = r
		i = nx
	return r


## Lower index always becomes the root, so roots are canonical (= lowest building id).
func union(a: int, b: int) -> void:
	var ra := find(a)
	var rb := find(b)
	if ra == rb:
		return
	if ra < rb:
		parent[rb] = ra
	else:
		parent[ra] = rb


static func key(bx: int, by: int) -> int:
	return (bx + 512) * 4096 + (by + 512)


## Poles within reach of `b` (footprint cell nearest to the pole at distance <= pole range), ascending pole index.
## `buckets`: bucket key (see `key`) -> Array of pole indices; `size`: bucket edge in cells.
static func poles_in_reach(b: Building, buckets: Dictionary, size: int, centers: PackedVector2Array, ranges: PackedFloat32Array) -> Array[int]:
	var out: Array[int] = []
	var bx0 := float(b.cell.x)
	var bx1 := float(b.cell.x + b.size.x - 1)
	var by0 := float(b.cell.y)
	var by1 := float(b.cell.y + b.size.y - 1)
	var x0 := floori(float(b.cell.x - size) / size)
	var x1 := floori(float(b.cell.x + b.size.x - 1 + size) / size)
	var y0 := floori(float(b.cell.y - size) / size)
	var y1 := floori(float(b.cell.y + b.size.y - 1 + size) / size)
	for by in range(y0, y1 + 1):
		for bx in range(x0, x1 + 1):
			var k := key(bx, by)
			if not buckets.has(k):
				continue
			for pi: int in buckets[k]:
				var c := centers[pi]
				var dx := c.x - clampf(c.x, bx0, bx1)
				var dy := c.y - clampf(c.y, by0, by1)
				if dx * dx + dy * dy <= ranges[pi] * ranges[pi]:
					out.append(pi)
	if out.size() > 1:
		out.sort()
	return out
