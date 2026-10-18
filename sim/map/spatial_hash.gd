class_name SpatialHash
extends RefCounted
## Cell-bucket index for range queries over objects with a `cell: Vector2i`
## (enemies, colonists, ...). Buckets are `bucket` cells wide.

var bucket := 8
var _buckets: Dictionary = {}  # int key -> Array
var _where: Dictionary = {}  # object id -> int key
var count := 0


func _init(p_bucket := 8) -> void:
	bucket = maxi(1, p_bucket)


func _key(c: Vector2i) -> int:
	return (c.x / bucket + 4096) * 8192 + (c.y / bucket + 4096)


func insert(o: Object) -> void:
	var k := _key(o.cell)
	if not _buckets.has(k):
		_buckets[k] = []
	_buckets[k].append(o)
	_where[o.get_instance_id()] = k
	count += 1


func remove(o: Object) -> void:
	var oid := o.get_instance_id()
	if not _where.has(oid):
		return
	_drop(o, int(_where[oid]))
	_where.erase(oid)
	count -= 1


func has(o: Object) -> bool:
	return _where.has(o.get_instance_id())


## Call after `o.cell` changed.
func update(o: Object) -> void:
	var oid := o.get_instance_id()
	var k := _key(o.cell)
	if _where.get(oid, -1) == k:
		return
	if _where.has(oid):
		_drop(o, int(_where[oid]))
	else:
		count += 1
	if not _buckets.has(k):
		_buckets[k] = []
	_buckets[k].append(o)
	_where[oid] = k


func _drop(o: Object, k: int) -> void:
	var arr: Array = _buckets[k]
	arr.erase(o)
	if arr.is_empty():
		_buckets.erase(k)


## All objects whose cell is within Euclidean distance `r` of `pos` (unordered).
func query(pos: Vector2, r: float) -> Array:
	var out: Array = []
	var x0 := floori(pos.x - r) / bucket
	var x1 := floori(pos.x + r) / bucket
	var y0 := floori(pos.y - r) / bucket
	var y1 := floori(pos.y + r) / bucket
	var r2 := r * r
	for bx in range(maxi(x0, -4000), x1 + 1):
		for by in range(maxi(y0, -4000), y1 + 1):
			var k := (bx + 4096) * 8192 + (by + 4096)
			if not _buckets.has(k):
				continue
			for o: Object in _buckets[k]:
				if Vector2(o.cell).distance_squared_to(pos) <= r2:
					out.append(o)
	return out
