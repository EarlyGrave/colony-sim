class_name NodeData
extends RefCounted
## Resource node / biome definitions (data/resources.json, data/biomes.json).
## Purity ids are stored as bytes in MapGrid.node_purity: 0 none, 1 impure, 2 normal, 3 pure.

const PURITY_IDS: Array[String] = ["", "impure", "normal", "pure"]
static var _res: Dictionary = {}
static var _biomes: Dictionary = {}
static var _res_ids: Array[String] = []


static func _load(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


static func _ensure() -> void:
	if not _res.is_empty():
		return
	_res = _load("res://data/resources.json")
	_biomes = _load("res://data/biomes.json")
	var ids: Array = _res.keys()
	ids.sort()
	_res_ids.clear()
	for k in ids:
		_res_ids.append(String(k))


static func resource_ids() -> Array[String]:
	_ensure()
	return _res_ids


## Resource byte id (1-based, sorted order) -> resource name; "" for 0.
static func res_name(r: int) -> String:
	_ensure()
	return _res_ids[r - 1] if r >= 1 and r <= _res_ids.size() else ""


static func res_index(name: String) -> int:
	_ensure()
	return _res_ids.find(name) + 1


static func resource(name: String) -> Dictionary:
	_ensure()
	return _res.get(name, {})


static func biome(id: String) -> Dictionary:
	_ensure()
	return _biomes.get(id, {})


static func purity_mult(res: String, purity: int) -> float:
	var r := resource(res)
	if r.is_empty() or purity < 1 or purity > 3:
		return 1.0
	return float(r["purity_mult"][PURITY_IDS[purity]])


## Items per 100 ticks of a node.
static func rate(res: String, purity: int) -> float:
	return float(resource(res).get("base_rate", 0.0)) * purity_mult(res, purity)
