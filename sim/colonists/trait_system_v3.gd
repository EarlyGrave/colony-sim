class_name TraitSystemV3
extends RefCounted
## Traits v3 (docs/gdd/03-colony/traits-v3/, data/traits_v3.json). NOT wired into the live sim:
## `balance.traits_v3_enabled` is false, so Simulation never instantiates this class and Defs
## never loads the file. Tests (and a future integration batch) construct it directly.
## State lives in c.bio: "traits_v3" (ids), "trait_counters" (event counts), "trait_links"
## (bond partner ids), "trait_log" ([{day,id,op,src}]). Deterministic: every roll takes an rng.

const PATH := "res://data/traits_v3.json"
const INNATE_CATS := ["personality", "body"]
const ACQUIRED_CATS := ["scar", "mutation", "social"]
const CATEGORIES := ["personality", "body", "background", "scar", "mutation", "social"]

var sim: Simulation
var cfg: Dictionary


## `p_cfg` overrides the data file (tests); otherwise defs.traits_v3 if loaded, else the file.
func _init(p_sim: Simulation = null, p_cfg: Dictionary = {}) -> void:
	sim = p_sim
	if not p_cfg.is_empty():
		cfg = p_cfg
	elif sim != null and sim.defs != null and not sim.defs.traits_v3.is_empty():
		cfg = sim.defs.traits_v3
	else:
		cfg = load_cfg()


static func load_cfg() -> Dictionary:
	return Defs._load_json(PATH)


static func enabled_in(defs: Defs) -> bool:
	return defs != null and bool(defs.balance.get("traits_v3_enabled", false))


# region lookup
func def(id: String) -> Dictionary:
	return cfg["traits"].get(id, {})


func ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in cfg["traits"]:
		out.append(id)
	return out


func list(c: Colonist) -> Array[String]:
	var out: Array[String] = []
	if c != null:
		for t in c.bio.get("traits_v3", []):
			out.append(str(t))
	return out


func has(c: Colonist, id: String) -> bool:
	return c != null and (c.bio.get("traits_v3", []) as Array).has(id)


func category(id: String) -> String:
	return str(def(id).get("category", ""))


func is_innate(id: String) -> bool:
	var d := def(id)
	return INNATE_CATS.has(str(d.get("category", ""))) or bool(d.get("innate", false))


func count_category(c: Colonist, cat: String) -> int:
	var n := 0
	for t in list(c):
		if category(t) == cat:
			n += 1
	return n


func icon_path(id: String) -> String:
	return "res://assets/sprites/trait_" + id.trim_prefix("t_") + ".png"


## Sum of a stat over the colonist's traits (0.0 if none).
func mod(c: Colonist, stat: String) -> float:
	var s := 0.0
	for t in list(c):
		s += float((def(t).get("effects", {}) as Dictionary).get(stat, 0.0))
	return s


func has_tag(c: Colonist, tag: String) -> bool:
	for t in list(c):
		if (def(t).get("tags", []) as Array).has(tag):
			return true
	return false


## For the colonist panel: [{id,name,category,rarity,desc,icon}] in acquisition order.
func summary(c: Colonist) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t in list(c):
		var d := def(t)
		out.append({"id": t, "name": str(d.get("name", t)), "category": category(t),
				"rarity": str(d.get("rarity", "common")), "desc": str(d.get("desc", "")), "icon": icon_path(t)})
	return out
# endregion


# region conflicts
## Why `id` cannot join `held` ("" = it can). Checks: unknown, owned, excludes (both ways),
## group clash, category slot caps (innate_max / background_count / acquired_max / mutation_max).
func conflict(held: Array, id: String) -> String:
	var d := def(id)
	if d.is_empty():
		return "unknown"
	if held.has(id):
		return "owned"
	for o in held:
		var od := def(str(o))
		if (d.get("excludes", []) as Array).has(o) or (od.get("excludes", []) as Array).has(id):
			return "excludes:" + str(o)
		if d.has("group") and str(d["group"]) == str(od.get("group", "")):
			return "group:" + str(o)
	var slots: Dictionary = cfg["slots"]
	var cat := str(d.get("category", ""))
	var n_cat := 0
	var n_innate := 0
	var n_acq := 0
	for o in held:
		var oc := category(str(o))
		if oc == cat:
			n_cat += 1
		if INNATE_CATS.has(oc):
			n_innate += 1
		if ACQUIRED_CATS.has(oc):
			n_acq += 1
	if cat == "background" and n_cat >= int(slots["background_count"]):
		return "slot:background"
	if INNATE_CATS.has(cat) and n_innate >= int(slots["innate_max"]):
		return "slot:innate"
	if cat == "mutation" and n_cat >= int(slots["mutation_max"]):
		return "slot:mutation"
	if ACQUIRED_CATS.has(cat) and n_acq >= int(slots["acquired_max"]):
		return "slot:acquired"
	return ""


func can_add(c: Colonist, id: String) -> String:
	if c == null or not c.alive:
		return "dead"
	return conflict(c.bio.get("traits_v3", []), id)
# endregion


# region grant/remove
func add(c: Colonist, id: String, source := "quest") -> bool:
	if can_add(c, id) != "":
		return false
	var arr: Array = c.bio.get("traits_v3", [])
	arr.append(id)
	c.bio["traits_v3"] = arr
	c.bio["work_speed"] = float(c.bio.get("work_speed", 1.0)) + float(def(id).get("effects", {}).get("work_speed", 0.0))
	_log(c, id, "add", source)
	return true


func remove(c: Colonist, id: String, source := "quest") -> bool:
	if not has(c, id):
		return false
	var arr: Array = c.bio.get("traits_v3", [])
	arr.erase(id)
	c.bio["traits_v3"] = arr
	c.bio["work_speed"] = float(c.bio.get("work_speed", 1.0)) - float(def(id).get("effects", {}).get("work_speed", 0.0))
	var links: Dictionary = c.bio.get("trait_links", {})
	links.erase(id)
	c.bio["trait_links"] = links
	_log(c, id, "remove", source)
	return true


func _log(c: Colonist, id: String, op: String, source: String) -> void:
	var log: Array = c.bio.get("trait_log", [])
	var day := 0
	if sim != null and sim.ticks_per_day > 0:
		day = sim.tick / sim.ticks_per_day
	log.append({"day": day, "id": id, "op": op, "src": source})
	c.bio["trait_log"] = log
# endregion


# region birth
## Weighted draw with a FIXED rng draw count: 1 (none?) + innate_max + 1 (background)
## + 1 (social?) + 1 (social pick) = innate_max + 4. `ctx.block` honours `block_only`.
func roll_birth(rng: RandomNumberGenerator, ctx: Dictionary = {}) -> Array[String]:
	var slots: Dictionary = cfg["slots"]
	var chosen: Array[String] = []
	var none := rng.randf() < float(slots["innate_none_chance"])
	for i in int(slots["innate_max"]):
		var r := rng.randf()
		if not none:
			_pick(chosen, r, "innate", ctx)
	_pick(chosen, rng.randf(), "background", ctx)
	var social := rng.randf() < float(slots["social_birth_chance"])
	var r2 := rng.randf()
	if social:
		_pick(chosen, r2, "social", ctx)
	return chosen


func _pick(chosen: Array[String], r: float, kind: String, ctx: Dictionary) -> void:
	var pool: Array[String] = []
	var total := 0.0
	for id: String in cfg["traits"]:
		var d: Dictionary = cfg["traits"][id]
		var cat := str(d.get("category", ""))
		var ok := false
		match kind:
			"innate": ok = INNATE_CATS.has(cat) or (bool(d.get("innate", false)) and cat != "background")
			"background": ok = cat == "background"
			"social": ok = cat == "social" and bool(d.get("innate", false))
		if not ok or conflict(chosen, id) != "":
			continue
		if d.has("block_only") and str(d["block_only"]) != str(ctx.get("block", "")):
			continue
		pool.append(id)
		total += _weight(id)
	var x := r * total
	for id in pool:
		x -= _weight(id)
		if x < 0.0:
			chosen.append(id)
			return


func _weight(id: String) -> float:
	return float(cfg["rarity_weight"].get(str(def(id).get("rarity", "common")), 1.0))


## Rolls and applies birth traits: ids, skill bonuses, work_speed cache, max_hp. Fixed rng draws.
func apply_birth(c: Colonist, rng: RandomNumberGenerator, ctx: Dictionary = {}) -> Array[String]:
	var chosen := roll_birth(rng, ctx)
	c.bio["traits_v3"] = []
	for id in chosen:
		add(c, id, "birth")
		var bonus: Dictionary = def(id).get("skills", {})
		if c.skills != null:
			for s: String in bonus:
				if c.skills.levels.has(s):
					c.skills.levels[s] = clampi(c.skills.level(s) + int(bonus[s]), 0, 10)
	c.max_hp = maxf(10.0, c.max_hp + mod(c, "max_hp"))
	c.hp = minf(c.hp, c.max_hp)
	return chosen
# endregion


# region acquisition
## Feeds one life event into the counters and applies the acquire/lose rules.
## Returns the ids that changed ("+id" granted, "-id" removed). No rng: thresholds only.
func event(c: Colonist, name: String, source := "") -> Array[String]:
	var out: Array[String] = []
	if c == null or not c.alive:
		return out
	var counters: Dictionary = c.bio.get("trait_counters", {})
	counters[name] = int(counters.get(name, 0)) + 1
	var ix: Dictionary = _rule_index().get(name, {})  # region F11W1: rules indexed by event name (perf at 250 inmates)
	if not ix.has("reset") and not ix.has("lose") and int(counters[name]) < int(ix.get("min", 1)):
		c.bio["trait_counters"] = counters  # fast path: below every threshold, nothing can change
		return out
	for rule: Dictionary in ix.get("reset", []):
		counters[str(rule["on"])] = 0
	c.bio["trait_counters"] = counters
	for rule: Dictionary in ix.get("lose", []):
		if not has(c, str(rule["trait"])):
			continue
		if int(counters.get(name, 0)) >= int(rule.get("count", 1)):
			if remove(c, str(rule["trait"]), source if source != "" else name):
				out.append("-" + str(rule["trait"]))
				counters[name] = 0 if rule.has("count") else int(counters.get(name, 0))
	for rule: Dictionary in ix.get("acq", []):
		var tid := str(rule["trait"])
		if has(c, tid) or _superseded(c, tid) or int(counters.get(name, 0)) < int(rule.get("count", 1)):
			continue
		if rule.has("requires") and not has(c, str(rule["requires"])):
			continue
		var removed := ""
		if rule.has("replaces") and has(c, str(rule["replaces"])):
			removed = str(rule["replaces"])
			remove(c, removed, "ladder")
		if add(c, tid, source if source != "" else name):
			if removed != "":
				out.append("-" + removed)
			out.append("+" + tid)
		elif removed != "":
			add(c, removed, "ladder")  # could not step up: keep the lower rung
	c.bio["trait_counters"] = counters
	return out


# region F11W1
var _ix: Dictionary = {}
var _up: Dictionary = {}  # trait id -> ids of the rungs that replace it


## event name -> {reset: [acquire rules], lose: [lose rules], acq: [acquire rules]}, in file order.
func _rule_index() -> Dictionary:
	if not _ix.is_empty():
		return _ix
	for rule: Dictionary in cfg["acquire"]:
		if rule.has("reset_on"):
			_ix_list(str(rule["reset_on"]), "reset").append(rule)
		_ix_list(str(rule["on"]), "acq").append(rule)
		var ixr: Dictionary = _ix[str(rule["on"])]
		ixr["min"] = mini(int(ixr.get("min", 9999)), int(rule.get("count", 1)))
		if rule.has("replaces"):
			if not _up.has(str(rule["replaces"])):
				_up[str(rule["replaces"])] = []
			(_up[str(rule["replaces"])] as Array).append(str(rule["trait"]))
	for rule: Dictionary in cfg["lose"]:
		_ix_list(str(rule["on"]), "lose").append(rule)
	return _ix


func _ix_list(name: String, kind: String) -> Array:
	if not _ix.has(name):
		_ix[name] = {}
	if not (_ix[name] as Dictionary).has(kind):
		_ix[name][kind] = []
	return _ix[name][kind]
# endregion


## True when a higher rung of a ladder (`replaces` chain) is held: lower rungs never return.
func _superseded(c: Colonist, tid: String) -> bool:
	_rule_index()  # region F11W1: replace chains are indexed (_up)
	for up: String in _up.get(tid, []):
		if has(c, up) or _superseded(c, up):
			return true
	return false


func counter(c: Colonist, name: String) -> int:
	return int((c.bio.get("trait_counters", {}) as Dictionary).get(name, 0))


## Trait needs: `ctx` holds booleans (see cfg.needs). Returns thought ids to add today.
func daily_needs(c: Colonist, ctx: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var needs: Dictionary = cfg.get("needs", {})
	var counters: Dictionary = c.bio.get("trait_counters", {})
	for t in list(c):
		if not needs.has(t):
			continue
		var n: Dictionary = needs[t]
		var key := "need_" + t
		if bool(ctx.get(str(n["want"]), false)):
			counters[key] = 0
		else:
			counters[key] = int(counters.get(key, 0)) + 1
		if int(counters[key]) >= int(n["days"]):
			out.append(str(n["thought"]))
	c.bio["trait_counters"] = counters
	return out
# endregion


# region bonds
## Links a pair trait between two inmates (both get it). False if either cannot take it.
func bond(a: Colonist, b: Colonist, id: String, source := "bond") -> bool:
	if a == null or b == null or a == b or can_add(a, id) != "" or can_add(b, id) != "":
		return false
	var bd: Dictionary = cfg["bonds"].get(id, {})
	for ex in bd.get("excludes", []):
		if has(a, str(ex)) or has(b, str(ex)):
			return false
	add(a, id, source)
	add(b, id, source)
	_link(a, id, b.id)
	_link(b, id, a.id)
	return true


## Daily bond roll for one candidate pair: `days` = days the two shared a block (or job).
## One rng draw per call; deterministic given the caller iterates pairs in id order.
func try_bond(a: Colonist, b: Colonist, id: String, days: int, rng: RandomNumberGenerator) -> bool:
	var bd: Dictionary = cfg["bonds"].get(id, {})
	var need := int(bd.get("days_same_block", bd.get("days_same_job", 9999)))
	var r := rng.randf()
	if days < need or r >= float(bd.get("chance", 0.0)):
		return false
	return bond(a, b, id)


func partner(c: Colonist, id: String) -> int:
	return int((c.bio.get("trait_links", {}) as Dictionary).get(id, -1))


## Partner died or left: the bond trait goes, the survivor keeps a memory counter.
func break_bond(c: Colonist, id: String) -> bool:
	if not has(c, id):
		return false
	remove(c, id, "partner_lost")
	var counters: Dictionary = c.bio.get("trait_counters", {})
	counters["lost_" + id] = int(counters.get("lost_" + id, 0)) + 1
	c.bio["trait_counters"] = counters
	return true


func _link(c: Colonist, id: String, other: int) -> void:
	var links: Dictionary = c.bio.get("trait_links", {})
	links[id] = other
	c.bio["trait_links"] = links
# endregion


# region effect helpers (one consumer each; see cfg.stats)
func carry_cap(c: Colonist, base: int) -> int:
	return maxi(base, roundi(float(base) * (1.0 + mod(c, "carry"))))


func xp_mult(c: Colonist, skill: String) -> float:
	return maxf(0.0, 1.0 + mod(c, "xp_mult_all") + mod(c, "xp_mult_" + skill))


func shift_mult(c: Colonist, night: bool) -> float:
	return maxf(0.1, 1.0 + mod(c, "work_night" if night else "work_day"))


func mutation_mult(c: Colonist) -> float:
	return maxf(0.0, 1.0 + mod(c, "mutation_risk"))


func breakage_mult(c: Colonist) -> float:
	return maxf(0.0, 1.0 + mod(c, "machine_breakage"))


func refine_speed(c: Colonist) -> float:
	return maxf(0.1, 1.0 + mod(c, "refining_speed"))


func quality_shift(c: Colonist) -> int:
	return roundi(mod(c, "quality_tier"))


func installment(c: Colonist, base: int) -> int:
	return maxi(1, roundi(float(base) * maxf(0.0, 1.0 + mod(c, "installment_pct"))))


func move_bonus(c: Colonist) -> float:
	return mod(c, "move_speed")


## Thought multiplier: thought_<id> plus the sign-wide thought_neg / thought_pos (value sign).
func thought_mult(c: Colonist, thought_id: String, value: float) -> float:
	var m := 1.0 + mod(c, "thought_" + thought_id)
	m *= 1.0 + mod(c, "thought_neg" if value < 0.0 else "thought_pos")
	return maxf(0.0, m)


func target_weight_mult(c: Colonist) -> float:
	return maxf(0.05, 1.0 + mod(c, "target_weight"))


func heal_mult(c: Colonist) -> float:
	return maxf(0.1, 1.0 + mod(c, "heal_rate"))


func severity_mult(c: Colonist, illness: bool) -> float:
	return maxf(0.0, 1.0 + mod(c, "illness_severity" if illness else "injury_severity"))


func spot_range(c: Colonist, base: int) -> int:
	return maxi(1, base + roundi(mod(c, "spot_range")))


func warning_ticks(c: Colonist) -> int:
	return roundi(mod(c, "warning_ticks"))


func alarm_delay(c: Colonist) -> int:
	return maxi(0, roundi(mod(c, "alarm_delay")))


func informant_weight(c: Colonist, base: float) -> float:
	return maxf(0.0, base + mod(c, "informant_weight"))


## Path votes this inmate adds to the block leaning ({submit, fight, escape}).
func leaning(c: Colonist) -> Dictionary:
	return {"submit": mod(c, "leaning_submit"), "fight": mod(c, "leaning_fight"), "escape": mod(c, "leaning_escape")}


## Sum of `aura_<stat>` from `mates` (block or job mates), excluding `c` itself.
func aura(c: Colonist, stat: String, mates: Array) -> float:
	var s := 0.0
	for m in mates:
		if m != c and m != null and m.alive:
			s += mod(m, "aura_" + stat)
	return s


## Work-speed multiplier for the streak mechanic: `same` = ticks on the same job type.
func streak_mult(c: Colonist, same_ticks: int, switch_window := 30) -> float:
	var m := 1.0
	if same_ticks < switch_window:
		m += mod(c, "work_switch")
	else:
		m += mod(c, "work_streak")
	return maxf(0.1, m)
# endregion


# region validation
## Data sanity for tests: ids, categories, rarities, excludes, stats registry, desc length, rules.
func validate() -> Array[String]:
	var errs: Array[String] = []
	var stats: Dictionary = cfg.get("stats", {})
	for id: String in cfg["traits"]:
		var d: Dictionary = cfg["traits"][id]
		if not id.begins_with("t_"):
			errs.append(id + ": id must start with t_")
		if not CATEGORIES.has(str(d.get("category", ""))):
			errs.append(id + ": bad category")
		if not cfg["rarity_weight"].has(str(d.get("rarity", ""))):
			errs.append(id + ": bad rarity")
		if str(d.get("desc", "")).length() > 70 or str(d.get("desc", "")) == "":
			errs.append(id + ": desc length")
		if str(d.get("name", "")) == "":
			errs.append(id + ": name")
		for ex in d.get("excludes", []):
			if not cfg["traits"].has(ex):
				errs.append(id + ": unknown exclude " + str(ex))
		if (d.get("effects", {}) as Dictionary).is_empty():
			errs.append(id + ": no effects")
		for stat: String in d.get("effects", {}):
			var known := stats.has(stat)
			for s: String in stats:
				if s.ends_with("*") and stat.begins_with(s.trim_suffix("*")):
					known = true
			if not known:
				errs.append(id + ": unregistered stat " + stat)
	for rule: Dictionary in cfg["acquire"]:
		for k in ["trait", "requires", "replaces"]:
			if rule.has(k) and not cfg["traits"].has(rule[k]):
				errs.append("acquire: unknown " + str(rule[k]))
	for rule: Dictionary in cfg["lose"]:
		if not cfg["traits"].has(rule["trait"]):
			errs.append("lose: unknown " + str(rule["trait"]))
	for t: String in cfg.get("needs", {}):
		if not t.begins_with("_") and not cfg["traits"].has(t):
			errs.append("needs: unknown " + t)
	for t: String in cfg.get("bonds", {}):
		if not t.begins_with("_") and not cfg["traits"].has(t):
			errs.append("bonds: unknown " + t)
	return errs
# endregion
