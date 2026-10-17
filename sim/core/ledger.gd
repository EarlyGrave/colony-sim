class_name Ledger
extends RefCounted
## Bookkeeping of every item that enters or leaves the world.
## Conservation invariant: for every item,
##   items present in world == produced - consumed.

var produced: Dictionary = {}  # item_id -> int
var consumed: Dictionary = {}  # item_id -> int
var by_source: Dictionary = {}  # "source:item_id" -> int


func record_produced(item_id: String, n: int, source: String) -> void:
	produced[item_id] = int(produced.get(item_id, 0)) + n
	var k := source + ":" + item_id
	by_source[k] = int(by_source.get(k, 0)) + n


func record_consumed(item_id: String, n: int, sink: String) -> void:
	consumed[item_id] = int(consumed.get(item_id, 0)) + n
	var k := sink + ":" + item_id
	by_source[k] = int(by_source.get(k, 0)) + n


func balance_of(item_id: String) -> int:
	return int(produced.get(item_id, 0)) - int(consumed.get(item_id, 0))


func get_count(key: String) -> int:
	return int(by_source.get(key, 0))
