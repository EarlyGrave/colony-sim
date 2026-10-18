class_name QualitySystem
extends RefCounted
## Item quality. Quality is an attribute of a stack / carried load / building
## output unit, NOT part of the item id, so Ledger and count_world stay per
## base item (conservation unchanged). Normal quality is stored as "" so
## untracked items and old states are unaffected.
## Known limit: quality is kept on the ground, in hands and in building output;
## it is dropped when items enter a building input or a blueprint.

var sim: Simulation
var _cfg: Dictionary
var _ids: Array[String] = []


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	_cfg = p_sim.defs.quality
	for l: Dictionary in _cfg["levels"]:
		_ids.append(str(l["id"]))


func tracked(item_id: String) -> bool:
	return item_id in _cfg["tracked"]


func _level(q: String) -> Dictionary:
	for l: Dictionary in _cfg["levels"]:
		if str(l["id"]) == (q if q != "" else "normal"):
			return l
	return {"id": "normal", "name": "Standard", "mult": 1.0}


func quality_name(q: String) -> String:
	return str(_level(q)["name"])


func value_mult(q: String) -> float:
	return float(_level(q)["mult"])


## Market value of `n` units of `item_id` at quality `q`.
func value_of(item_id: String, n: int, q: String) -> float:
	return float(sim.defs.items[item_id].get("value", 0.0)) * n * value_mult(q)


## Rolls the quality of one crafted unit ("" = normal). Uses sim.rng.
func roll(item_id: String, operator: Colonist, bench_id: String) -> String:
	if not tracked(item_id):
		return ""
	if sim.perks.consume_flag(operator, "masterwork"):
		return _store("masterwork")
	var lvl := 0
	if operator != null and operator.skills != null:
		lvl = operator.skills.level(str(_cfg["skill"]))
	var noise := (sim.rng.randf() + sim.rng.randf() - 1.0) * float(_cfg["noise"])
	var score := float(_cfg["base"]) + lvl * float(_cfg["per_level"]) \
		+ sim.perks.mod(operator, "craft_quality") * float(_cfg["perk_scale"]) \
		+ float(_cfg["bench_bonus"].get(bench_id, 0.0)) + noise
	var idx := 0
	for t: float in _cfg["thresholds"]:
		if score >= t:
			idx += 1
	return _store(_ids[idx])


func _store(q: String) -> String:
	return "" if q == "normal" else q
