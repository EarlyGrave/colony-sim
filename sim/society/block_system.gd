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
var _succeeded := false  # region N3: M2 once per run
var _low_days: Dictionary = {}  # region N3: block -> days at/below walkout standing
var _ultimatum: Dictionary = {}  # region N3: block -> {deadline, refined0}


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
	var chap := 0.5 if _chaplain_blocks.has(b) else 1.0  # region F11W3: chaplain halves the block's despair
	var wk := chap * sim.quests.mod("weak_despair_mult") if (s < float(cfg.get("thought_low", 30.0)) and sim.quests != null) else 1.0  # region W3: S2 Look away
	if s < 50.0:
		return wk * (1.0 + (50.0 - s) / 50.0 * (float(cfg["despair_mult_low_standing"]) - 1.0))
	return wk * (1.0 - (s - 50.0) / 50.0 * (1.0 - float(cfg["despair_mult_high_standing"])))


func on_installment_paid(c: Colonist) -> void:
	_change(block_of(c), float(cfg["paid_gain"]) * maxf(0.0, 1.0 + sim.traits.mod(c, "standing_gain") + sim.passives.mod(c, "standing_gain")), false)  # region traits + F11W3


func on_installment_missed(c: Colonist) -> void:
	_change(block_of(c), -float(cfg["missed_loss_per_day"]), true)


func _on_died(id: int) -> void:
	var c := sim.colonists.get_by_id(id)
	_change(block_of(c), -float(cfg["death_loss"]), true)
	_debt_of_the_dead(c)  # region N3


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
	return _touched or _informant_id != 0 or _succeeded or not _ultimatum.is_empty()


func state_parts() -> Array:
	var keys: Array = standing.keys()
	keys.sort()
	var out: Array = [_informant_id]
	for k in keys:
		out.append([k, snappedf(standing[k], 0.001), quiet[k]])
	if _succeeded or not _ultimatum.is_empty():  # region N3 (hash part only once a moment fired)
		var uk: Array = _ultimatum.keys()
		uk.sort()
		out.append(["n3", _succeeded, uk])
	return out


func tick() -> void:
	if not is_enabled() or sim.tick % sim.ticks_per_day != 0:
		return
	_scan_chaplains()  # region F11W3
	_pick_informant()
	_succession()  # region N3
	_walkouts()  # region N3
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


# region F11W3
var _chaplain_blocks: Dictionary = {}  ## block id -> true while a living chaplain (not in a break) is a member; rebuilt daily


func _scan_chaplains() -> void:
	_chaplain_blocks.clear()
	if not sim.passives.enabled():
		return
	for c in sim.colonists.list:
		if c.alive and sim.passives.rule(c, "block_chaplain") and sim.mood.state_of(c).break_kind == "":
			_chaplain_blocks[block_of(c)] = true


## always_informant: the holder (lowest id) becomes the Informant while alive; no rng. True when handled.
func _pick_passive_informant() -> bool:
	if not sim.passives.enabled():
		return false
	for c in sim.colonists.list:
		if c.alive and sim.passives.rule(c, "always_informant"):
			if _informant_id != c.id:
				if _informant_id != 0:
					member_of.erase(_informant_id)
				member_of[c.id] = "informant"
				_informant_id = c.id
			return true
	return false
# endregion


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
	if standing.has("informant") and _pick_passive_informant():  # region F11W3
		return
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


# region N3
## Path choice (verb `path`): flag path_<id>, Standing +-leaning_delta per block (data: leaning).
func apply_path(id: String) -> void:
	if sim.quests != null:
		sim.quests.set_flag("path_" + id)
	if not is_enabled():
		return
	var lean: Dictionary = cfg.get("leaning", {})
	var ids: Array = standing.keys()
	ids.sort()
	for b: String in ids:
		var l := int((lean.get(b, {}) as Dictionary).get(id, 0))
		if l != 0:
			_change(b, l * float(cfg.get("leaning_delta", 15.0)), l < 0)


func _path_flag(id: String) -> bool:
	return sim.quests != null and sim.quests.flag(id)


func _letter(title: String, text: String) -> void:
	if sim.quests != null and sim.quests.mod("pa_silent") > 0.0:
		return
	sim.bus.letter_received.emit(title, text)


## M1 Debt of the Dead: the open installment moves to the block (+pct of each member's remaining debt).
func _debt_of_the_dead(c: Colonist) -> void:
	if not is_enabled() or c == null or sim.debt == null or _path_flag("path_fight"):
		return
	var st := sim.debt.state_of(c)
	if st == null or st.remaining() <= 0:
		return
	var b := block_of(c)
	var pct := float(cfg.get("debt_of_dead_pct", 1.0))
	for m in _members(b):
		if m.id == c.id:
			continue
		var ms := sim.debt.state_of(m)
		if ms != null and ms.remaining() > 0:
			ms.total += ceili(ms.remaining() * pct / 100.0)
	_letter(str(cfg["debt_of_dead_title"]), str(cfg["debt_of_dead_text"]).replace("{id}", str(4000 + c.id)))


## M2 Informant Succession: once per run, the highest-Standing block supplies the new Informant.
func _succession() -> void:
	if _succeeded or _informant_id == 0:
		return
	var old := sim.colonists.get_by_id(_informant_id)
	if old != null and old.alive and not sim.debt.gone.has(old.id):
		return
	var best := ""
	var ids: Array = standing.keys()
	ids.sort()
	for b: String in ids:
		if b == "informant" or _members(b).is_empty():
			continue
		if best == "" or standing_of(b) > standing_of(best):
			best = b
	if best == "":
		return
	var pick: Colonist = _members(best)[0]
	_succeeded = true
	member_of[pick.id] = "informant"
	_informant_id = pick.id
	if sim.quests != null:
		sim.quests.set_flag("informant_succeeded")
	_change(best, -float(cfg["succession_loss"]), true)
	_letter(str(cfg["succession_title"]), str(cfg["succession_text"]))


## M3 Walkout: Standing <= 15 for 3 days -> ultimatum; unmet -> two most despairing members run for the dock.
func _walkouts() -> void:
	var ids: Array = standing.keys()
	ids.sort()
	for b: String in ids:
		if _ultimatum.has(b):
			if sim.day() >= int(_ultimatum[b]["deadline"]):
				_resolve_ultimatum(b)
			continue
		if standing_of(b) <= float(cfg.get("walkout_standing", 15.0)) and not _members(b).is_empty():
			_low_days[b] = int(_low_days.get(b, 0)) + 1
			if int(_low_days[b]) >= int(cfg.get("walkout_days", 3)):
				_low_days[b] = 0
				_ultimatum[b] = {"deadline": sim.day() + int(cfg.get("walkout_deadline_days", 2)),
						"refined0": int(sim.ledger.produced.get("refined_essence", 0))}
				_touched = true
				var key := "walkout_text_fight" if _path_flag("path_fight") else "walkout_text"
				_letter(str(cfg["walkout_title"]), str(cfg[key]).replace("{block}", str(cfg["blocks"][b]["name"])))
		else:
			_low_days[b] = 0


func _ultimatum_met(b: String) -> bool:
	if _path_flag("path_fight"):
		return int(sim.ledger.produced.get("refined_essence", 0)) <= int(_ultimatum[b]["refined0"])
	var inst := int(sim.defs.debt["installment"])
	for m in _members(b):
		var st := sim.debt.state_of(m)
		if st != null and st.remaining() > 0 and st.period_paid < inst:
			return false
	return true


func _resolve_ultimatum(b: String) -> void:
	var met := _ultimatum_met(b)
	_ultimatum.erase(b)
	var nm := str(cfg["blocks"][b]["name"])
	if met:
		_change(b, float(cfg.get("walkout_gain", 20.0)), false)
		for m in _members(b):
			sim.mood.add_thought(m, "block_proud")
		_letter(str(cfg["walkout_met_title"]), str(cfg["walkout_met_text"]).replace("{block}", nm))
		return
	var ms := _members(b)
	ms.sort_custom(func(x: Colonist, y: Colonist) -> bool:
		var dx := sim.debt.state_of(x).despair if sim.debt.state_of(x) != null else 0.0
		var dy := sim.debt.state_of(y).despair if sim.debt.state_of(y) != null else 0.0
		return dx > dy or (dx == dy and x.id < y.id))
	for i in mini(int(cfg.get("walkout_breakers", 2)), ms.size()):
		sim.jobs.request_override(ms[i], sim.debt.start_break(ms[i], "escape"))
	_letter(str(cfg["walkout_failed_title"]), str(cfg["walkout_failed_text"]).replace("{block}", nm))
# endregion
