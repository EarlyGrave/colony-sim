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
