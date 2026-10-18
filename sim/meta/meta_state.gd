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


func _init(p_defs: Defs = null) -> void:
	defs = p_defs if p_defs != null else Defs.get_default()


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
	return {"version": 1, "balance": balance, "total": total_earned, "runs": runs,
		"best_days": best_days, "owned": owned, "crate": crate, "last_run": last_run, "preset": preset,
		"tutorial": tutorial, "launched": launched}


func load_dict(d: Dictionary) -> void:
	balance = int(d.get("balance", 0))
	total_earned = int(d.get("total", 0))
	runs = int(d.get("runs", 0))
	best_days = int(d.get("best_days", 0))
	owned = (d.get("owned", []) as Array).duplicate()
	crate = str(d.get("crate", ""))
	preset = str(d.get("preset", "standard_term"))  # region O3
	tutorial = bool(d.get("tutorial", false))  # region R5X: old profiles keep today's behaviour
	launched = bool(d.get("launched", true))
	last_run = (d.get("last_run", {}) as Dictionary).duplicate(true)
	for k in ["seed", "days", "legacy", "site"]:
		if last_run.has(k):
			last_run[k] = int(last_run[k])
