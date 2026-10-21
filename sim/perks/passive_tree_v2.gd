class_name PassiveTreeV2
extends RefCounted
## Passives v2: earned passive abilities ("marks" spent on a per-inmate board of six work
## details). Pure rules over data/passives_v2.json; no Simulation, no rng, no scene tree, so it
## can be unit-tested directly. NOT wired into the live sim yet (balance.passives_v2_enabled =
## false). Design: docs/gdd/03-colony/passives-v2/. Integration plan: integration.md there.
##
## Everything a consumer needs is read through mod()/has()/xp_mult() for numbers and
## rules()/has_rule() for keystone rule flags (effects `rule_<x>`: 1 — a rule change the consumer
## system implements, see data `rule_consumers`); the per-inmate state is a plain
## PassiveTreeV2.State (serialisable with to_dict/from_dict).

const DATA_PATH := "res://data/passives_v2.json"


## Per-inmate state. Plain data; rules live in PassiveTreeV2.
class State:
	extends RefCounted
	var marks_earned := 0
	var marks_spent := 0
	var allocated: Array[String] = []        ## passive ids in allocation order
	var allocated_at: Dictionary = {}        ## id -> tick (for the undo grace window)
	var deeds: Dictionary = {}               ## deed id -> true
	var counters: Dictionary = {}            ## counter key -> int (deed triggers "counter:<key>")
	var milestones: Dictionary = {}          ## skill -> highest milestone level credited
	var locked_until := -1                   ## tick until which allocation is locked (respec)
	var respecs := 0
	var legacy: Array[String] = []           ## keystone ids the NG+ dossier remembers (cost 0)
	var cache: Dictionary = {}               ## stat -> summed value (cleared on change)

	func marks_free() -> int:
		return marks_earned - marks_spent

	func to_dict() -> Dictionary:
		return {"earned": marks_earned, "spent": marks_spent, "allocated": allocated.duplicate(),
			"allocated_at": allocated_at.duplicate(), "deeds": deeds.keys(), "counters": counters.duplicate(),
			"milestones": milestones.duplicate(), "locked_until": locked_until, "respecs": respecs,
			"legacy": legacy.duplicate()}

	static func from_dict(d: Dictionary) -> State:
		var s := State.new()
		s.marks_earned = int(d.get("earned", 0))
		s.marks_spent = int(d.get("spent", 0))
		for id: Variant in d.get("allocated", []):
			s.allocated.append(str(id))
		for k: Variant in d.get("allocated_at", {}):
			s.allocated_at[str(k)] = int(d["allocated_at"][k])
		for id: Variant in d.get("deeds", []):
			s.deeds[str(id)] = true
		for k: Variant in d.get("counters", {}):
			s.counters[str(k)] = int(d["counters"][k])
		for k: Variant in d.get("milestones", {}):
			s.milestones[str(k)] = int(d["milestones"][k])
		s.locked_until = int(d.get("locked_until", -1))
		s.respecs = int(d.get("respecs", 0))
		for id: Variant in d.get("legacy", []):
			s.legacy.append(str(id))
		return s


var data: Dictionary = {}
var _defs: Dictionary = {}      ## passive id -> def (file order)
var _details: Dictionary = {}   ## detail id -> def
var _deeds: Dictionary = {}     ## deed id -> def
var _caps: Dictionary = {}
var _marks: Dictionary = {}
var _respec: Dictionary = {}
var _rules: Dictionary = {}     ## rule id -> {rule, consumer, hook}

const RULE_PREFIX := "rule_"
const RULES_CACHE_KEY := "_rules"


## Reads data/passives_v2.json (Defs does not load it while the flag is off).
static func load_default() -> Dictionary:
	var text := FileAccess.get_file_as_string(DATA_PATH)
	if text == "":
		push_error("PassiveTreeV2: cannot read " + DATA_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("PassiveTreeV2: invalid JSON in " + DATA_PATH)
		return {}
	var d: Dictionary = parsed
	d.erase("_comment")
	return d


func _init(p_data: Dictionary = {}) -> void:
	data = p_data if not p_data.is_empty() else load_default()
	for p: Dictionary in data.get("passives", []):
		_defs[str(p["id"])] = p
	_details = data.get("details", {})
	for d: Dictionary in data.get("deeds", []):
		_deeds[str(d["id"])] = d
	_caps = data.get("caps", {})
	_marks = data.get("marks", {})
	_respec = data.get("respec", {})
	_rules = data.get("rule_consumers", {})


# ---- data access -----------------------------------------------------------------

func ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in _defs:
		out.append(id)
	return out


func def_of(id: String) -> Dictionary:
	return _defs.get(id, {})


func details() -> Dictionary:
	return _details


func deeds() -> Dictionary:
	return _deeds


## Passive ids of one detail in data order ("pit", or "pit+stacks" for a bridge keystone).
func passives_of(detail: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in _defs:
		if str(_defs[id]["detail"]) == detail:
			out.append(id)
	return out


func tier_of(id: String) -> String:
	return str(_defs.get(id, {}).get("tier", ""))


## Keystones that cannot coexist with `id` (data `excludes`, symmetric).
func excludes_of(id: String) -> Array[String]:
	var out: Array[String] = []
	for x: Variant in _defs.get(id, {}).get("excludes", []):
		out.append(str(x))
	return out


## Rule ids a passive carries (effects `rule_<x>`), e.g. ["no_medicine", "essence_heal"].
func rules_of(id: String) -> Array[String]:
	var out: Array[String] = []
	for k: String in _defs.get(id, {}).get("effects", {}):
		if k.begins_with(RULE_PREFIX):
			out.append(k.trim_prefix(RULE_PREFIX))
	return out


## Known rule ids with their consumer (data `rule_consumers`).
func rule_consumers() -> Dictionary:
	return _rules


## Marks a passive costs this inmate (keystones remembered by the dossier are free).
func cost_of(st: State, id: String) -> int:
	if st != null and st.legacy.has(id):
		return 0
	return int(_defs.get(id, {}).get("cost", 0))


func max_keystones() -> int:
	return int(_marks.get("max_keystones", 2))


# ---- earning marks ---------------------------------------------------------------

func earn(st: State, n: int) -> int:
	if n <= 0:
		return 0
	st.marks_earned += n
	return n


## Marks for skill milestones (data marks.milestones) up to `level`, each credited once per
## skill. Returns the marks awarded.
func on_skill_level(st: State, skill: String, level: int) -> int:
	var got := 0
	var top := int(st.milestones.get(skill, 0))
	var ms: Dictionary = _marks.get("milestones", {})
	var keys: Array = ms.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return int(a) < int(b))
	for k: String in keys:
		var at := int(k)
		if at <= top or at > level:
			continue
		got += earn(st, int(ms[k]))
		top = at
	st.milestones[skill] = maxi(top, int(st.milestones.get(skill, 0)))
	return got


## Milestones at or below `level` count as already credited (a veteran joining at L6 earns the
## next mark at L10, mirroring PerkSystem.join_level).
func set_baseline(st: State, skill: String, level: int) -> void:
	var top := 0
	for k: String in _marks.get("milestones", {}):
		if int(k) <= level:
			top = maxi(top, int(k))
	st.milestones[skill] = maxi(top, int(st.milestones.get(skill, 0)))


## Grants a deed once; returns the marks awarded (0 if unknown or already held).
func grant_deed(st: State, deed_id: String) -> int:
	if not _deeds.has(deed_id) or st.deeds.has(deed_id):
		return 0
	st.deeds[deed_id] = true
	return earn(st, int(_deeds[deed_id]["marks"]))


## Bumps a counter ("installments", "rescues", "tends", ...) and resolves counter deeds.
func bump_counter(st: State, key: String, n: int = 1) -> int:
	st.counters[key] = int(st.counters.get(key, 0)) + n
	var got := 0
	for id: String in _deeds:
		var d: Dictionary = _deeds[id]
		if str(d["trigger"]) == "counter:" + key and int(st.counters[key]) >= int(d["at"]):
			got += grant_deed(st, id)
	return got


## Resolves record deeds against ColonistSystem.records[c.id] ({"kills": {by id}, "ore_mined",
## "refined", "repairs", "downs", "waves_survived"}). Returns the marks awarded.
func check_records(st: State, records: Dictionary) -> int:
	var got := 0
	for id: String in _deeds:
		var d: Dictionary = _deeds[id]
		var trig := str(d["trigger"])
		if not trig.begins_with("record:"):
			continue
		var key := trig.trim_prefix("record:")
		var v: Variant = records.get(key, 0)
		var n := 0
		if typeof(v) == TYPE_DICTIONARY:
			for x: Variant in v.values():
				n += int(x)
		else:
			n = int(v)
		if n >= int(d["at"]):
			got += grant_deed(st, id)
	return got


# ---- allocation ------------------------------------------------------------------

func has(st: State, id: String) -> bool:
	return st != null and st.allocated.has(id)


func keystones_of(st: State) -> Array[String]:
	var out: Array[String] = []
	for id in st.allocated:
		if tier_of(id) == "keystone":
			out.append(id)
	return out


func _groups_ok(st: State, p: Dictionary, without: String = "") -> bool:
	for g: Dictionary in p.get("requires_groups", []):
		var n := 0
		for r: String in g["any"]:
			if r != without and st.allocated.has(r):
				n += 1
		if n < int(g["n"]):
			return false
	return true


## "" if the passive can be allocated now, otherwise a reason code: unknown, allocated, locked,
## gate_skill, gate_deed, requires, excluded, keystone_limit, no_marks. `ctx.skills` = {skill: level}.
func can_allocate(st: State, id: String, ctx: Dictionary = {}, now: int = 0) -> String:
	if not _defs.has(id):
		return "unknown"
	if st.allocated.has(id):
		return "allocated"
	if st.locked_until >= 0 and now < st.locked_until:
		return "locked"
	var p: Dictionary = _defs[id]
	var gate: Dictionary = p.get("gate", {})
	if gate.has("skills"):
		var ok := false
		var levels: Dictionary = ctx.get("skills", {})
		for sk: String in gate["skills"]:
			if int(levels.get(sk, 0)) >= int(gate["skills"][sk]):
				ok = true
		if not ok:
			return "gate_skill"
	if gate.has("deed") and not st.deeds.has(str(gate["deed"])):
		return "gate_deed"
	if not _groups_ok(st, p):
		return "requires"
	for x: Variant in p.get("excludes", []):
		if st.allocated.has(str(x)):
			return "excluded"
	if str(p["tier"]) == "keystone" and keystones_of(st).size() >= max_keystones():
		return "keystone_limit"
	if st.marks_free() < cost_of(st, id):
		return "no_marks"
	return ""


func allocate(st: State, id: String, ctx: Dictionary = {}, now: int = 0) -> bool:
	if can_allocate(st, id, ctx, now) != "":
		return false
	st.marks_spent += cost_of(st, id)
	st.allocated.append(id)
	st.allocated_at[id] = now
	st.cache.clear()
	return true


## "" if the passive can be taken back for free (inside marks.undo_grace_ticks after allocation
## and nothing allocated depends on it), otherwise: unknown, not_allocated, grace, dependents.
func can_undo(st: State, id: String, now: int) -> String:
	if not _defs.has(id):
		return "unknown"
	if not st.allocated.has(id):
		return "not_allocated"
	if now - int(st.allocated_at.get(id, 0)) > int(_marks.get("undo_grace_ticks", 0)):
		return "grace"
	for other in st.allocated:
		if other != id and not _groups_ok(st, _defs[other], id):
			return "dependents"
	return ""


## Refunds the marks of one passive (see can_undo). Returns the marks refunded.
func undo(st: State, id: String, now: int) -> int:
	if can_undo(st, id, now) != "":
		return 0
	var back := cost_of(st, id)
	st.allocated.erase(id)
	st.allocated_at.erase(id)
	st.marks_spent -= back
	st.cache.clear()
	return back


## Price of forgetting the whole board: {"item", "count", "standing", "lockout_days"}.
## count = per_mark x marks spent x path_mult[path]; standing = keystone_standing per keystone.
func respec_cost(st: State, path: String = "") -> Dictionary:
	var mult := float(_respec.get("path_mult", {}).get(path, 1.0))
	var count := ceili(float(_respec.get("per_mark", 1)) * float(st.marks_spent) * mult)
	return {"item": str(_respec.get("item", "refined_essence")), "count": count,
		"standing": int(_respec.get("keystone_standing", 0)) * keystones_of(st).size(),
		"lockout_days": int(_respec.get("lockout_days", 0))}


func can_respec(st: State) -> bool:
	return st != null and not st.allocated.is_empty()


## Forgets every passive (marks return) and locks allocation for lockout_days. The caller pays
## respec_cost() (items / Standing) before calling; the module holds no inventory. Returns the
## marks refunded.
func respec(st: State, now: int, ticks_per_day: int) -> int:
	if not can_respec(st):
		return 0
	var back := st.marks_spent
	st.allocated.clear()
	st.allocated_at.clear()
	st.marks_spent = 0
	st.respecs += 1
	st.locked_until = now + int(_respec.get("lockout_days", 0)) * ticks_per_day
	st.cache.clear()
	return back


# ---- effect aggregation ----------------------------------------------------------

## Sum of `stat` over allocated passives (0.0 if none), with data caps (lower bounds). Cached per
## state until the allocation changes.
func mod(st: State, stat: String) -> float:
	if st == null or st.allocated.is_empty():
		return 0.0
	if st.cache.has(stat):
		return float(st.cache[stat])
	var total := 0.0
	for id in st.allocated:
		total += float(_defs[id].get("effects", {}).get(stat, 0.0))
	if _caps.has(stat) and not has_rule(st, "uncapped_" + stat):
		total = maxf(total, float(_caps[stat]))
	st.cache[stat] = total
	return total


## Rule flags of the allocated keystones: {rule id: true}, e.g. {"no_medicine": true}. Cached per
## state until the allocation changes. A consumer system reads `has_rule(st, "no_medicine")` on
## its hook line (data `rule_consumers` names the line); the module itself only aggregates.
func rules(st: State) -> Dictionary:
	if st == null or st.allocated.is_empty():
		return {}
	if st.cache.has(RULES_CACHE_KEY):
		return st.cache[RULES_CACHE_KEY]
	var out: Dictionary = {}
	for id in st.allocated:
		for k: String in _defs[id].get("effects", {}):
			if k.begins_with(RULE_PREFIX):
				out[k.trim_prefix(RULE_PREFIX)] = true
	st.cache[RULES_CACHE_KEY] = out
	return out


func has_rule(st: State, rule: String) -> bool:
	return rules(st).has(rule)


## 1 + xp_mult_all + xp_mult_<skill> (floored at 0).
func xp_mult(st: State, skill: String) -> float:
	return maxf(0.0, 1.0 + mod(st, "xp_mult_all") + mod(st, "xp_mult_" + skill))


## All summed numeric stats of a state plus "rules": [ids] (for the sheet / tests).
func summary(st: State) -> Dictionary:
	var out: Dictionary = {}
	for id in st.allocated:
		for k: String in _defs[id].get("effects", {}):
			if not k.begins_with(RULE_PREFIX):
				out[k] = mod(st, k)
	var rl: Array[String] = []
	for r: String in rules(st):
		rl.append(r)
	rl.sort()
	if not rl.is_empty():
		out["rules"] = rl
	return out


## Deterministic fingerprint of a state (allocation order matters: it is part of the replay).
func state_hash(st: State) -> String:
	return "%d/%d|%s|%s" % [st.marks_earned, st.marks_spent, ",".join(st.allocated), ",".join(st.legacy)]


# ---- NG+ dossier -------------------------------------------------------------------

## What a veteran carries into the next sentence: banked marks (capped) and the keystones the
## dossier remembers (they cost 0 next run).
func dossier_carry(st: State) -> Dictionary:
	return {"marks": mini(st.marks_spent, int(_marks.get("dossier_carry_max", 0))), "known_for": keystones_of(st)}


func apply_dossier(st: State, d: Dictionary) -> void:
	earn(st, int(d.get("marks", 0)))
	for id: Variant in d.get("known_for", []):
		if _defs.has(str(id)) and not st.legacy.has(str(id)):
			st.legacy.append(str(id))


# ---- validation (tests) --------------------------------------------------------------

## Data problems as human-readable strings (empty = valid).
func validate() -> Array[String]:
	var errs: Array[String] = []
	var consumers: Dictionary = data.get("stat_consumers", {})
	for id: String in _defs:
		var p: Dictionary = _defs[id]
		if not id.begins_with("p_"):
			errs.append(id + ": id must start with p_")
		if not ["minor", "notable", "keystone"].has(str(p.get("tier", ""))):
			errs.append(id + ": bad tier")
		if str(p.get("desc", "")).length() > 70 or str(p.get("desc", "")) == "":
			errs.append(id + ": desc length")
		if p.get("effects", {}).is_empty():
			errs.append(id + ": no effects")
		for k: String in p.get("effects", {}):
			if k.begins_with(RULE_PREFIX):
				if not _rules.has(k.trim_prefix(RULE_PREFIX)):
					errs.append(id + ": rule without consumer " + k)
				if str(p.get("tier", "")) != "keystone":
					errs.append(id + ": only keystones carry rules")
			elif not consumers.has(k):
				errs.append(id + ": stat without consumer " + k)
		for x: Variant in p.get("excludes", []):
			if not _defs.has(str(x)):
				errs.append(id + ": excludes unknown " + str(x))
			elif not _defs[str(x)].get("excludes", []).has(id):
				errs.append(id + ": excludes not symmetric with " + str(x))
		if str(p.get("tier", "")) == "keystone" and (p.get("rule", "") == "" or p.get("drawback", "") == ""):
			errs.append(id + ": keystone needs rule + drawback text")
		for g: Dictionary in p.get("requires_groups", []):
			for r: String in g["any"]:
				if not _defs.has(r):
					errs.append(id + ": requires unknown " + r)
			if int(g["n"]) > g["any"].size():
				errs.append(id + ": group n too large")
		var det := str(p["detail"])
		for part in det.split("+"):
			if not _details.has(part):
				errs.append(id + ": unknown detail " + part)
		if str(p["tier"]) == "keystone" and det.contains("+") and p["requires_groups"].size() != 2:
			errs.append(id + ": bridge keystone needs two groups")
		if not str(p.get("icon", "")).begins_with("passive_"):
			errs.append(id + ": icon name")
	for id: String in _deeds:
		var trig := str(_deeds[id]["trigger"])
		if not (trig.begins_with("record:") or trig.begins_with("counter:")):
			errs.append(id + ": bad trigger")
	return errs
