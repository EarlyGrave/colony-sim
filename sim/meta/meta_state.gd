class_name MetaState
extends RefCounted
## Persistent meta-progression: legacy balance, owned unlocks, last planet.
## Pure data; file IO in view/meta_store.gd.

var defs: Defs
var balance := 0
var total_earned := 0
var runs := 0
var best_days := 0
var owned: Array = []  # unlock ids
var crate := ""  # selected crate unlock id ("" = none)
var last_run: Dictionary = {}  # summary of the previous run
var preset := "standard_term"  # region O3: selected difficulty preset id
var tutorial := true  # region R5X: Warden's Orientation toggle (default ON for a fresh profile)
var launched := false  # region R5X: false until the first new-game dialog was confirmed
var ng: Dictionary = {}  # region NG: Next Sentence block, see ng_defaults()


func _init(p_defs: Defs = null) -> void:
	defs = p_defs if p_defs != null else Defs.get_default()
	ng = ng_defaults()  # region NG


func record_run(summary: Dictionary) -> void:
	runs += 1
	last_run = summary.duplicate(true)
	balance += int(summary["legacy"])
	total_earned += int(summary["legacy"])
	best_days = maxi(best_days, int(summary["days"]))


func can_buy(id: String) -> String:
	if not defs.meta["unlocks"].has(id):
		return "unknown"
	if owned.has(id):
		return "owned"
	if balance < int(defs.meta["unlocks"][id]["cost"]):
		return "poor"
	return ""


func buy(id: String) -> bool:
	if can_buy(id) != "":
		return false
	balance -= int(defs.meta["unlocks"][id]["cost"])
	owned.append(id)
	if str(defs.meta["unlocks"][id]["kind"]) == "crate" and crate == "":
		crate = id
	return true


func select_crate(id: String) -> bool:
	if id != "" and (not owned.has(id) or str(defs.meta["unlocks"][id]["kind"]) != "crate"):
		return false
	crate = id
	return true


func can_next_batch() -> bool:
	return not last_run.is_empty() and int(last_run["days"]) >= int(defs.meta["next_batch"]["min_days"])


## Start options from owned unlocks (capabilities only).
func make_opts() -> Dictionary:
	var o := {}
	var rules: Array = []
	var un: Dictionary = defs.meta["unlocks"]
	for id: String in owned:
		if not un.has(id):
			continue
		var u: Dictionary = un[id]
		match str(u["kind"]):
			"start_rule": rules.append(str(u["rule"]))
			"start_xp": o["start_xp"] = float(o.get("start_xp", 0.0)) + float(u["amount"])
			"reveal_forecast": o["reveal_forecast"] = true
			"scout": o["scout"] = int(defs.meta["scout_cells"])
	if not rules.is_empty():
		o["start_rules"] = rules
	if crate != "" and owned.has(crate):
		o["crate"] = (un[crate]["items"] as Dictionary).duplicate()
	StartOpts.merge_preset(o, defs, preset)  # region O3
	return o


## Same planet seed, partially rolled-back contamination, new landing site.
func make_next_batch() -> Dictionary:
	var o := make_opts()
	var keep := float(defs.meta["next_batch"]["contamination_keep"])
	o["contamination"] = float(last_run.get("contamination", 0.0)) * keep
	o["site"] = int(last_run.get("site", 0)) + 1
	return {"seed": int(last_run["seed"]), "opts": o}


func to_dict() -> Dictionary:
	return {"version": 2, "balance": balance, "total": total_earned, "runs": runs,
		"best_days": best_days, "owned": owned, "crate": crate, "last_run": last_run, "preset": preset,
		"tutorial": tutorial, "launched": launched, "ng": ng.duplicate(true)}


func load_dict(d: Dictionary) -> void:
	if int(d.get("version", 1)) > 2:  # region NG: unknown future version -> safe defaults
		return
	balance = int(d.get("balance", 0))
	total_earned = int(d.get("total", 0))
	runs = int(d.get("runs", 0))
	best_days = int(d.get("best_days", 0))
	var ow: Variant = d.get("owned", [])
	owned = (ow as Array).duplicate() if ow is Array else []
	crate = str(d.get("crate", ""))
	preset = str(d.get("preset", "standard_term"))  # region O3
	tutorial = bool(d.get("tutorial", false))  # region R5X: old profiles keep today's behaviour
	launched = bool(d.get("launched", true))
	var lr: Variant = d.get("last_run", {})
	last_run = (lr as Dictionary).duplicate(true) if lr is Dictionary else {}
	for k in ["seed", "days", "legacy", "site"]:
		if last_run.has(k):
			last_run[k] = int(last_run[k])
	_load_ng(d.get("ng", {}))  # region NG


# region NG
const NG_HISTORY_CAP := 20


static func ng_defaults() -> Dictionary:
	return {"sentence": 1, "carry_debt": 0, "dossier": {}, "techs": [], "history": [],
		"prev_seed": 0, "last_preset": ""}


func _load_ng(v: Variant) -> void:
	ng = ng_defaults()
	if not v is Dictionary:
		return
	var d: Dictionary = v
	ng["sentence"] = maxi(1, int(d.get("sentence", 1)))
	ng["carry_debt"] = maxi(0, int(d.get("carry_debt", 0)))
	ng["prev_seed"] = int(d.get("prev_seed", 0))
	ng["last_preset"] = str(d.get("last_preset", ""))
	var dos: Variant = d.get("dossier", {})
	if dos is Dictionary and not (dos as Dictionary).is_empty():
		var sk := {}
		var raw: Variant = (dos as Dictionary).get("skills", {})
		if raw is Dictionary:
			for k: Variant in raw:
				sk[str(k)] = int(raw[k])
		ng["dossier"] = {"name": str(dos.get("name", "")), "skills": sk, "perk_id": str(dos.get("perk_id", ""))}
	var techs: Array = []
	var traw: Variant = d.get("techs", [])
	if traw is Array:
		for t: Variant in traw:
			if defs.research.has(str(t)):
				techs.append(str(t))
	ng["techs"] = techs
	var hist: Array = []
	var hraw: Variant = d.get("history", [])
	if hraw is Array:
		for h: Variant in hraw:
			if h is Dictionary:
				hist.append({"n": int(h.get("n", 0)), "seed": int(h.get("seed", 0)), "days": int(h.get("days", 0)),
					"debt_paid": int(h.get("debt_paid", 0)), "preset": str(h.get("preset", "")), "result": str(h.get("result", ""))})
	ng["history"] = hist.slice(maxi(0, hist.size() - NG_HISTORY_CAP))


func ng_cfg() -> Dictionary:
	return defs.meta.get("ng", {"debt_carry_frac": 0.5, "tech_carry": 3, "extra_wave_mult": 0.1})


## True once at least one sentence was finished (a carry exists).
func has_ng_carry() -> bool:
	return int(ng["sentence"]) > 1


## Records a finished run (call on shuttle win). summary keys (build with Legacy.ng_snapshot(sim, result, preset)):
## seed, days, result, preset, debt_left, debt_paid, colonists [{id, name, skills, perks}], techs [ids].
func finish_sentence(summary: Dictionary) -> void:
	var cfg := ng_cfg()
	var left := int(summary.get("debt_left", 0))
	ng["carry_debt"] = roundi(left * float(cfg["debt_carry_frac"]))
	var best: Dictionary = {}
	var best_sum := -1
	for c: Variant in summary.get("colonists", []):
		var cd: Dictionary = c
		var sum := 0
		for k: Variant in cd.get("skills", {}):
			sum += int(cd["skills"][k])
		if sum > best_sum or (sum == best_sum and int(cd.get("id", 0)) < int(best.get("id", 0))):
			best_sum = sum
			best = cd
	if best.is_empty():
		ng["dossier"] = {}
	else:
		var perks: Array = best.get("perks", [])
		var sk := {}
		for k: Variant in best.get("skills", {}):
			sk[str(k)] = int(best["skills"][k])
		ng["dossier"] = {"name": str(best.get("name", "")), "skills": sk,
			"perk_id": str(perks[0]) if not perks.is_empty() else ""}
	var cand: Array = []
	for t: Variant in summary.get("techs", []):
		var id := str(t)
		if defs.research.has(id) and not cand.has(id):
			cand.append(id)
	cand.sort_custom(func(a: String, b: String) -> bool:
		var ta := int(defs.research[a]["tier"])
		var tb := int(defs.research[b]["tier"])
		return ta < tb or (ta == tb and a < b))
	ng["techs"] = cand.slice(0, int(cfg["tech_carry"]))
	var hist: Array = ng["history"]
	hist.append({"n": int(ng["sentence"]), "seed": int(summary.get("seed", 0)), "days": int(summary.get("days", 0)),
		"debt_paid": int(summary.get("debt_paid", 0)), "preset": str(summary.get("preset", preset)),
		"result": str(summary.get("result", ""))})
	ng["history"] = hist.slice(maxi(0, hist.size() - NG_HISTORY_CAP))
	ng["prev_seed"] = int(summary.get("seed", 0))
	ng["last_preset"] = str(summary.get("preset", preset))
	ng["sentence"] = int(ng["sentence"]) + 1


func _ng_cur_preset() -> String:
	return str(ng["last_preset"]) if str(ng["last_preset"]) != "" else preset


## Next preset id: one step up in presets.json `order`, clamped at the last one.
func ng_next_preset() -> String:
	var order: Array = defs.presets.get("order", [])
	var cur := _ng_cur_preset()
	var i := order.find(cur)
	if i < 0:
		return cur
	return str(order[mini(i + 1, order.size() - 1)])


func ng_seed() -> int:
	return (int(ng["prev_seed"]) * 1103515245 + int(ng["sentence"]) * 12345 + 1) & 0x7fffffff


## {"seed", "opts"} for the next sentence. Pure function of meta state (no Time/randi).
## Extra opts keys: carry_debt, veteran {name, skills, perk_id}, start_techs, sentence.
func make_ng_opts() -> Dictionary:
	var keep := preset
	var order: Array = defs.presets.get("order", [])
	var at_top := not order.is_empty() and _ng_cur_preset() == str(order[order.size() - 1])
	preset = ng_next_preset()
	var o := make_opts()
	preset = keep
	if at_top:
		var over := maxi(1, int(ng["sentence"]) - 1)
		o["wave_mult"] = minf(3.0, float(o.get("wave_mult", 1.0)) + float(ng_cfg()["extra_wave_mult"]) * over)
	if int(ng["carry_debt"]) > 0:
		o["carry_debt"] = int(ng["carry_debt"])
	var dos: Dictionary = ng["dossier"]
	if not dos.is_empty():
		o["veteran"] = dos.duplicate(true)
	if not (ng["techs"] as Array).is_empty():
		o["start_techs"] = (ng["techs"] as Array).duplicate()
	o["sentence"] = int(ng["sentence"])
	return {"seed": ng_seed(), "opts": o}
# endregion
