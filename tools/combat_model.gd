extends SceneTree
## CX combat model: analytic DPS / time-to-kill tables from the data files (no simulation run).
##   godot --headless --path . -s tools/combat_model.gd [-- --skill=3 --dist=5]
## Section 1: weapon TTK vs every creature (+mutant). The Lancer row includes the volley ability.
## Section 2: seconds an inmate lasts under each creature, per role (dmg_taken_mult).
## Section 3: balance targets (also asserted by tests/test_combat_model.gd, which uses the statics).

const TPS := float(Simulation.TICKS_PER_SECOND)
const INMATE_HP := 100.0

var defs: Defs
var skill := 3
var dist := 5.0


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--skill="):
			skill = int(a.substr(8))
		if a.begins_with("--dist="):
			dist = float(a.substr(7))
	var bus: Node = load("res://autoload/event_bus.gd").new()
	defs = Simulation.new(1, bus).defs
	report()
	bus.free()
	quit()


static func hit_chance(defs_: Defs, w: Dictionary, lvl: int, d: float) -> float:
	var c: Dictionary = defs_.weapons["combat"]
	var p := float(c["hit_base"]) + float(c["hit_per_skill"]) * lvl
	if str(w["kind"]) == "ranged":
		p -= float(c["range_penalty"]) * maxf(0.0, d - 1.0)
	return clampf(p, float(c["hit_min"]), float(c["hit_max"]))


## Creature stats {hp, damage, cycle_s}. variant "" = base, "mutant" = enemies.json variant.
static func creature(defs_: Defs, id: String, variant := "") -> Dictionary:
	var d: Dictionary = defs_.enemies[id]
	var hp := float(d["max_hp"])
	var dmg := float(d.get("damage", 0.0))
	var vs: Dictionary = d.get("variants", {})
	if variant != "" and vs.has(variant):
		hp *= float(vs[variant]["hp_mult"])
		dmg *= float(vs[variant]["damage_mult"])
	var cycle := float(d["attack_cooldown_ticks"])
	if d.has("telegraph"):
		cycle += float(d["telegraph"]["windup_ticks"])
	return {"hp": hp, "damage": dmg, "cycle_s": cycle / TPS}


## Same formula as CombatSystem.resolve (region E1): flat, then armour curve with pen_pct.
static func resolve(raw: float, armor := 0.0, flat := 0.0, pen_pct := 0.0, flat_pen := 0.0) -> float:
	return CombatSystem.resolve(raw, armor, flat, pen_pct, flat_pen)


## Seconds to deal `hp` damage. volley = [shots, mult] (auto-hit burst at the start of the fight) or [].
static func ttk(defs_: Defs, weapon: String, hp: float, lvl: int, d: float, volley := [], armor := 0.0, flat := 0.0) -> float:
	var w: Dictionary = defs_.weapons["weapons"][weapon]
	var p := hit_chance(defs_, w, lvl, d)
	var cd := float(w["cooldown_ticks"])
	var dealt := 0.0
	var shots := 0
	while dealt < hp and shots < 100000:
		if not volley.is_empty() and shots < int(volley[0]):
			dealt += resolve(float(w["damage"]) * float(volley[1]), armor, flat)
		else:
			dealt += resolve(float(w["damage"]), armor, flat) * p
		shots += 1
	return float(shots) * cd / TPS


static func volley_of(defs_: Defs) -> Array:
	var v: Dictionary = defs_.weapons["abilities"]["volley"]["volley"]
	return [int(v["shots"]), float(v["dmg_mult"])]


static func role_weapon(defs_: Defs, role: String) -> String:
	return str(defs_.roles["roles"][role]["weapon"])


## Seconds a unit lasts under one creature (until INMATE_HP of damage) at damage multiplier `mult`.
static func survive_s(defs_: Defs, id: String, mult: float, variant := "") -> float:
	var cr := creature(defs_, id, variant)
	return INMATE_HP / (float(cr["damage"]) * mult / float(cr["cycle_s"]))


## [lancer TTK with volley, rifle inmate TTK] on creature `id`.
static func lancer_vs_rifle(defs_: Defs, id: String, lvl := 3, d := 5.0) -> Array:
	var hp := float(creature(defs_, id)["hp"])
	return [ttk(defs_, role_weapon(defs_, "lancer"), hp, lvl, d, volley_of(defs_)), ttk(defs_, "rifle", hp, lvl, d)]


## B5: expected damage taken per enemy hit by a full squad vs the same number of unsquadded inmates.
## Enemies pick targets weighted by threat_mult, damage is scaled by dmg_taken_mult. Returns the
## relative change (-0.30 = 30 percent less damage, which is the death-rate proxy).
static func squad_damage_delta(defs_: Defs) -> float:
	var num := 0.0
	var den := 0.0
	for r: String in defs_.roles["order"]:
		var d: Dictionary = defs_.roles["roles"][r]
		num += float(d["threat_mult"]) * float(d["dmg_taken_mult"])
		den += float(d["threat_mult"])
	return num / den - 1.0


func report() -> void:
	var weapons: Array = defs.weapons["weapons"].keys()
	weapons.sort()
	var roles: Array = defs.roles["order"]
	print("== 1. TTK seconds (skill %d, dist %.0f): weapon vs creature ==" % [skill, dist])
	_header("attacker")
	for w: String in weapons:
		_ttk_row("weapon " + w, w, [])
	for r: String in roles:
		_ttk_row("role %s (%s)%s" % [r, role_weapon(defs, r), "+volley" if r == "lancer" else ""], role_weapon(defs, r), volley_of(defs) if r == "lancer" else [])
	print("(name* = mutant variant)")
	print("\n== 2. seconds until a %d hp unit is out, per creature and role ==" % int(INMATE_HP))
	_header("target (dmg mult)")
	var rows: Array = [["inmate unsquadded", 1.0]]
	for r: String in roles:
		rows.append([r, float(defs.roles["roles"][r]["dmg_taken_mult"])])
	for row: Array in rows:
		var line := "%-26s" % ("%s x%.2f" % [row[0], row[1]])
		for id: String in defs.enemies:
			for v in ["", "mutant"]:
				line += "%9.1f" % survive_s(defs, id, float(row[1]), v)
		print(line)
	_f3a_armour_table()  # region F3a
	f11_report(defs)  # region F11W5
	print("\n== 3. targets ==")
	var bm := float(defs.roles["roles"]["bulwark"]["dmg_taken_mult"])
	print("Bulwark lasts %.2fx an unsquadded inmate (target >= 2.0): %s" % [1.0 / bm, "OK" if 1.0 / bm >= 2.0 else "FAIL"])
	var lr := lancer_vs_rifle(defs, "brute", skill, dist)
	print("Lancer TTK on brute %.1fs vs rifle inmate %.1fs = %.0f%% (target <= 60%%): %s" % [lr[0], lr[1], 100.0 * lr[0] / lr[1], "OK" if lr[0] <= 0.6 * lr[1] else "FAIL"])
	var sd := squad_damage_delta(defs)
	print("Squad damage taken vs unsquadded %+.0f%% (B5 target <= -30%%): %s" % [100.0 * sd, "OK" if sd <= -0.30 else "FAIL"])


func _header(first: String) -> void:
	var head := "%-26s" % first
	for id: String in defs.enemies:
		head += "%9s%9s" % [id, id + "*"]
	print(head)


func _ttk_row(label: String, weapon: String, volley: Array) -> void:
	var line := "%-26s" % label
	for id: String in defs.enemies:
		for v in ["", "mutant"]:
			line += "%9.1f" % ttk(defs, weapon, float(creature(defs, id, v)["hp"]), skill, dist, volley)
	print(line)


# region F3a
## Armour columns straight from data/gear.json: {phys, energy} armour and flat of a piece.
static func gear_armor(defs_: Defs, base: String) -> Dictionary:
	var g: Dictionary = defs_.gear.get(base, {})
	var a: Dictionary = g.get("armor", {})
	var f: Dictionary = g.get("flat", {})
	return {"armor": float(a.get("phys", 0.0)), "flat": float(f.get("phys", 0.0)), "armor_e": float(a.get("energy", 0.0))}


## Seconds an unsquadded inmate lasts under one creature wearing `base` ("" = nothing). Creature hits are phys.
static func survive_armored_s(defs_: Defs, id: String, base: String, variant := "") -> float:
	var cr := creature(defs_, id, variant)
	var ga := gear_armor(defs_, base) if base != "" else {"armor": 0.0, "flat": 0.0}
	var per_hit := resolve(float(cr["damage"]), float(ga["armor"]), float(ga["flat"]))
	return INMATE_HP / (per_hit / float(cr["cycle_s"]))


func _f3a_armour_table() -> void:
	print("\n== 2b. F3a armour: seconds an unsquadded inmate lasts, without / with gear (data/gear.json) ==")
	var bases: Array = ["", "underlay", "helmet", "kevlar_vest"]
	var line := "%-26s" % "creature"
	for b: String in bases:
		var ga := gear_armor(defs, b) if b != "" else {"armor": 0.0, "flat": 0.0}
		line += "%18s" % ("%s(%d/%d)" % [b if b != "" else "none", int(ga["armor"]), int(ga["flat"])])
	line += "%10s" % "vest x"
	print(line)
	for id: String in ["crawler", "burrower", "mimic"]:
		if not defs.enemies.has(id):
			continue
		line = "%-26s" % id
		for b: String in bases:
			line += "%18.1f" % survive_armored_s(defs, id, b)
		line += "%9.2fx" % (survive_armored_s(defs, id, "kevlar_vest") / survive_armored_s(defs, id, ""))
		print(line)
# endregion


# region F11W5
## F11W5: keystone power rows + per-passive model value (data/passives_v2.json), all analytic.
const F11_LOWER_BETTER: Array[String] = ["damage_taken", "hunger", "build_cost", "craft_input", "waste_mult", "contamination_per_batch", "installment_pct", "suspicion_gain", "gear_wear", "ammo_use", "machine_breakage", "mutation_risk", "infection_chance", "bleed_rate", "break_chance", "threat_attract", "target_weight", "despair_mult", "flee_threshold", "thought_injured"]
## Model weight per unit of a stat (1.0 = a +100% multiplier). Flat stats are scaled to "fraction of a typical value".
const F11_SCALE: Dictionary = {"mood_base": 0.01, "quality_tier": 0.2, "stash_cap": 0.05, "armor_flat": 0.05, "building_hp": 1.0, "flee_threshold": 0.25, "standing_gain": 1.0}
const F11_OUTLIER := 1.5


## Short Fuse damage multiplier at a mood level (rule_rage: +1% per point under 50, cap +50%; x0.75 above 50).
static func short_fuse_mult(mood: float) -> float:
	if mood > 50.0:
		return 0.75
	return 1.0 + minf(0.5, 0.01 * (50.0 - mood))


## Dead Man Walking: damage taken x0.7, hit +0.15 (rifle at skill `lvl`, distance `d`).
static func dead_man_row(defs_: Defs, lvl: int, d: float) -> Dictionary:
	var w: Dictionary = defs_.weapons["weapons"]["rifle"]
	var base_p := hit_chance(defs_, w, lvl, d)
	var p := clampf(base_p + 0.15, 0.05, 0.95)
	return {"dps": p / base_p, "survive": 1.0 / 0.7, "power": p / base_p / 0.7}


## Armour doubled on a full non-weapon kit; Armourer's Pride is melee only, so the offence side drops to the shiv.
static func armourers_row(defs_: Defs, creature_id: String, lvl: int, d: float) -> Dictionary:
	var arm := 0.0
	var flat := 0.0
	for b: String in ["underlay", "helmet", "kevlar_vest", "greaves", "work_gloves"]:
		var ga := gear_armor(defs_, b)
		arm += float(ga["armor"])
		flat += float(ga["flat"])
	var cr := creature(defs_, creature_id)
	var base := resolve(float(cr["damage"]), arm, flat)
	var dbl := resolve(float(cr["damage"]), arm * 2.0, flat * 2.0)
	var rifle: Dictionary = defs_.weapons["weapons"]["rifle"]
	var shiv: Dictionary = defs_.weapons["weapons"]["prison_shiv"]
	var dps_r := resolve(float(rifle["damage"])) * hit_chance(defs_, rifle, lvl, d) / float(rifle["cooldown_ticks"])
	var dps_s := resolve(float(shiv["damage"])) * hit_chance(defs_, shiv, lvl, d) / float(shiv["cooldown_ticks"])
	return {"survive": base / dbl, "dps": dps_s / dps_r, "power": base / dbl * dps_s / dps_r}


## Full Auto: attacks +25% faster, but the inmate draws x2 target weight in a squad of `n` equal inmates.
static func full_auto_row(n: int) -> Dictionary:
	var share := 2.0 / (float(n) + 1.0) * float(n)
	return {"dps": 1.25, "taken": share, "power": 1.25 / share}


## Model value of a numeric effect set: sum of polarity * effect * scale. Rule flags are not valued.
static func passive_value(effects: Dictionary) -> float:
	var v := 0.0
	for k: String in effects:
		if k.begins_with("rule_"):
			continue
		var sgn := -1.0 if F11_LOWER_BETTER.has(k) else 1.0
		v += sgn * float(effects[k]) * float(F11_SCALE.get(k, 1.0))
	return v


## Rows {id, name, detail, tier, cost, value, per_mark, median, ratio, outlier}; median = per-mark median of the passive's detail (school card).
static func passive_rows() -> Array:
	var tree := PassiveTreeV2.new(PassiveTreeV2.load_default())
	var by_detail: Dictionary = {}
	var rows: Array = []
	for id in tree.ids():
		var d := tree.def_of(id)
		var v := passive_value(d.get("effects", {}))
		var cost := float(d["cost"])
		var row := {"id": id, "name": d["name"], "detail": str(d["detail"]), "tier": str(d["tier"]), "cost": cost, "value": v, "per_mark": v / cost}
		rows.append(row)
		if v != 0.0:
			if not by_detail.has(row["detail"]):
				by_detail[row["detail"]] = []
			(by_detail[row["detail"]] as Array).append(row["per_mark"])
	for row: Dictionary in rows:
		var arr: Array = by_detail.get(row["detail"], [])
		arr.sort()
		var med := 0.0 if arr.is_empty() else float(arr[arr.size() / 2])
		row["median"] = med
		row["ratio"] = row["per_mark"] / med if med > 0.0 else 0.0
		row["outlier"] = med > 0.0 and row["per_mark"] > F11_OUTLIER * med
	return rows


static func f11_report(defs_: Defs, lvl := 3, d := 5.0) -> void:
	print("\n== 4. F11W5 keystone rows (skill %d, dist %.0f; ratios vs the same inmate without the keystone) ==" % [lvl, d])
	var dm := dead_man_row(defs_, lvl, d)
	print("Dead Man Walking: dps x%.2f, survive x%.2f, power x%.2f (no downed / no flee not modelled; heal -50%%, mood -10)" % [dm["dps"], dm["survive"], dm["power"]])
	for m in [20, 50, 80]:
		print("Short Fuse mood %d: damage x%.2f (break chance x2)" % [m, short_fuse_mult(float(m))])
	for id: String in ["crawler", "burrower", "mimic"]:
		if defs_.enemies.has(id):
			var ar := armourers_row(defs_, id, lvl, d)
			print("Armourer's Pride vs %s: survive x%.2f, dps x%.2f (shiv vs rifle), power x%.2f" % [id, ar["survive"], ar["dps"], ar["power"]])
	var fa := full_auto_row(8)
	print("Full Auto (squad of 8): dps x%.2f, damage taken x%.2f (target weight x2), power x%.2f; ammo use 0" % [fa["dps"], fa["taken"], fa["power"]])
	var out: Array = []
	for r: Dictionary in passive_rows():
		if r["outlier"]:
			out.append("%s %.3f/mark = x%.2f of %s median" % [r["id"], r["per_mark"], r["ratio"], r["detail"]])
	print("passives > %.1fx their school median per mark: %d" % [F11_OUTLIER, out.size()])
	for l: String in out:
		print("  ", l)
# endregion
