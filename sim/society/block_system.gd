class_name BlockSystem
extends RefCounted
## Cell blocks: every inmate belongs to one block (Lifer / Clerk / Zealot / Informant / Fresh Fish).
## Each block has a Standing 0-100: up when members pay installments on time, down on member
## death, dock (escape) or missed installments. Low Standing multiplies the block's despair growth
## (DebtSystem._daily). Deterministic: no rng (assignment is by colonist id). Numbers: data/blocks.json.

var sim: Simulation
var cfg: Dictionary
var standing: Dictionary = {}  # block id -> float 0..100
var member_of: Dictionary = {}  # colonist id -> block id (kept out of bio so other dumps stay as they were)
var quiet: Dictionary = {}  # block id -> days without a negative event
var _informant_id := 0
var _touched := false


static func load_cfg() -> Dictionary:
	var j: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/blocks.json"))
	return j as Dictionary if j is Dictionary else {}


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	cfg = load_cfg()
	var ids: Array = cfg.get("blocks", {}).keys()
	ids.sort()
	for b: String in ids:
		standing[b] = float(cfg.get("standing_start", 50.0))
		quiet[b] = 0
	sim.listen(sim.bus.colonist_died, _on_died)
	sim.listen(sim.bus.colonist_escaped, _on_escaped)


func is_enabled() -> bool:
	return bool(cfg.get("enabled", false))


func block_of(c: Colonist) -> String:
	if c == null:
		return ""
	if not member_of.has(c.id):  # starting colonists are spawned without the generator: tag lazily (data only)
		var order: Array = cfg.get("assign_order", [])
		member_of[c.id] = str(order[posmod(c.id - 1, order.size())]) if not order.is_empty() else ""
	return str(member_of[c.id])


func standing_of(block: String) -> float:
	return float(standing.get(block, 50.0))


func informant_id() -> int:
	return _informant_id


## Multiplier for the daily despair gain of this colonist's block (1.0 at Standing 50).
func despair_mult(c: Colonist) -> float:
	if not is_enabled():
		return 1.0
	var b := block_of(c)
	if not standing.has(b):
		return 1.0
	var s := standing_of(b)
	var wk := sim.quests.mod("weak_despair_mult") if (s < float(cfg.get("thought_low", 30.0)) and sim.quests != null) else 1.0  # region W3: S2 Look away
	if s < 50.0:
		return wk * (1.0 + (50.0 - s) / 50.0 * (float(cfg["despair_mult_low_standing"]) - 1.0))
	return wk * (1.0 - (s - 50.0) / 50.0 * (1.0 - float(cfg["despair_mult_high_standing"])))


func on_installment_paid(c: Colonist) -> void:
	_change(block_of(c), float(cfg["paid_gain"]), false)


func on_installment_missed(c: Colonist) -> void:
	_change(block_of(c), -float(cfg["missed_loss_per_day"]), true)


func _on_died(id: int) -> void:
	var c := sim.colonists.get_by_id(id)
	_change(block_of(c), -float(cfg["death_loss"]), true)


func _on_escaped(id: int) -> void:
	var c := sim.colonists.get_by_id(id)
	_change(block_of(c), -float(cfg["dock_loss"]), true)


func _change(b: String, delta: float, negative: bool) -> void:
	if not is_enabled() or not standing.has(b):
		return
	var old: float = standing[b]
	standing[b] = clampf(old + delta, 0.0, 100.0)
	if negative:
		quiet[b] = 0
	if standing[b] != old:
		_touched = true
		sim.bus.block_standing_changed.emit(b, standing[b])


func has_state() -> bool:
	return _touched or _informant_id != 0


func state_parts() -> Array:
	var keys: Array = standing.keys()
	keys.sort()
	var out: Array = [_informant_id]
	for k in keys:
		out.append([k, snappedf(standing[k], 0.001), quiet[k]])
	return out


func tick() -> void:
	if not is_enabled() or sim.tick % sim.ticks_per_day != 0:
		return
	_pick_informant()
	var keys: Array = standing.keys()
	keys.sort()
	for b: String in keys:
		var s: float = standing[b]
		var reg := float(cfg["standing_regress_per_day"])
		if s > 50.0:
			standing[b] = maxf(50.0, s - reg)
		elif s < 50.0:
			standing[b] = minf(50.0, s + reg)
		quiet[b] = int(quiet[b]) + 1
		_member_thoughts(b)
		if int(quiet[b]) >= int(cfg["quiet_days"]) and standing_of(b) >= float(cfg["quiet_min_standing"]) \
				and not _members(b).is_empty():
			quiet[b] = 0
			sim.bus.letter_received.emit(str(cfg["cohesion_title"]),
					str(cfg["cohesion_text"]).replace("{block}", str(cfg["blocks"][b]["name"])))


func _members(b: String) -> Array[Colonist]:
	var out: Array[Colonist] = []
	for c in sim.colonists.list:
		if c.alive and block_of(c) == b:
			out.append(c)
	return out


func _member_thoughts(b: String) -> void:
	var s := standing_of(b)
	var id := ""
	if s >= float(cfg["thought_high"]):
		id = "block_proud"
	elif s <= float(cfg["thought_low"]):
		id = "block_shamed"
	if id == "":
		return
	for c in _members(b):
		sim.mood.add_thought(c, id)


## Exactly one Informant per run, chosen once the cell holds enough inmates (prefers a Fresh Fish).
func _pick_informant() -> void:
	if _informant_id != 0 or not standing.has("informant"):
		return
	var alive: Array[Colonist] = []
	for c in sim.colonists.list:
		if c.alive and not c.hidden:
			alive.append(c)
	if alive.size() < int(cfg["informant_min_inmates"]):
		return
	var best: Colonist = null
	for c in alive:
		var better := best == null
		if not better:
			var cf := block_of(c) == "fresh_fish"
			var bf := block_of(best) == "fresh_fish"
			better = (cf and not bf) or (cf == bf and c.id < best.id)
		if better:
			best = c
	member_of[best.id] = "informant"
	_informant_id = best.id
