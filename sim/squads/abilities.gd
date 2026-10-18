class_name Abilities
extends RefCounted
## Role abilities (Bulwark taunt, Lancer volley, Medic stabilise). Command: Simulation.use_ability(sid, ability_id).
## Numbers: data/weapons.json "abilities". Integer-tick state, no rng.
## C1 API used (guarded): `sim.squads.get_squad(sid)` -> object with `members:Array[int]` and
## `role_of:Dictionary{colonist_id: role}`. Until C1 is merged tests inject squads via set_test_squad().
## C4 API used (guarded): `sim.health.stabilise(c, medic)`.

var sim: Simulation
var cfg: Dictionary
## "sid:ability" -> tick from which the ability is ready again.
var cooldowns: Dictionary = {}
var _test_squads: Dictionary = {}
## Threat flags {colonist_id: {flag: [until_tick, mult, radius]}}. Kept here, not on Colonist, so that
## Colonist's property list (dumped into storyteller/golden state) is unchanged.
var flags: Dictionary = {}
## Lancer volley {colonist_id: [shots_left, dmg_mult]} (off CombatState for the same reason).
var volley: Dictionary = {}
var _flagged: Array[int] = []  ## colonist ids holding a threat flag (ascending)


func flags_of(colonist_id: int) -> Dictionary:
	return flags.get(colonist_id, {})


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	cfg = sim.defs.weapons.get("abilities", {})


## Test hook (no C1 needed): registers {members, role_of} for squad `sid`.
func set_test_squad(sid: int, members: Array, role_of: Dictionary) -> void:
	_test_squads[sid] = {"members": members, "role_of": role_of}


func _squad(sid: int) -> Dictionary:
	if _test_squads.has(sid):
		return _test_squads[sid]
	var sq: Variant = sim.get("squads")
	if sq != null and sq.has_method("get_squad"):
		var s: Variant = sq.get_squad(sid)
		if s != null:
			return {"members": s.members, "role_of": s.role_of}
	return {}


func _user(sq: Dictionary, role: String) -> Colonist:
	var best: Colonist = null
	for id: int in sq["members"]:
		if str(sq["role_of"].get(id, "")) != role:
			continue
		var c := sim.colonists.get_by_id(id)
		if c != null and c.alive and (best == null or c.id < best.id):
			best = c
	return best


func ready_in(sid: int, ability_id: String) -> int:
	return maxi(0, int(cooldowns.get("%d:%s" % [sid, ability_id], 0)) - sim.tick)


## "" when usable, else a short reason (UI / tests).
func can_use(sid: int, ability_id: String) -> String:
	if not cfg.has(ability_id):
		return "unknown_ability"
	var a: Dictionary = cfg[ability_id]
	var sq := _squad(sid)
	if sq.is_empty():
		return "no_squad"
	var user := _user(sq, str(a["role"]))
	if user == null:
		return "no_user"
	if ready_in(sid, ability_id) > 0:
		return "cooldown"
	if sim.items.count_stored("refined_essence") < int(a["essence_cost"]):
		return "no_essence"
	if ability_id == "stabilise" and _stab_targets(user, a).is_empty():
		return "no_target"
	return ""


func _stab_targets(user: Colonist, a: Dictionary) -> Array[Colonist]:
	var out: Array[Colonist] = []
	if not sim.health.has_method("stabilise"):
		return out
	for c in sim.colonists.list:
		if c.alive and c != user and sim.health.is_downed(c) \
				and Vector2(c.cell).distance_to(Vector2(user.cell)) <= float(a["radius"]):
			out.append(c)
	return out


func use(sid: int, ability_id: String) -> bool:
	if can_use(sid, ability_id) != "":
		return false
	var a: Dictionary = cfg[ability_id]
	var user := _user(_squad(sid), str(a["role"]))
	if not sim.items.consume_stored("refined_essence", int(a["essence_cost"]), user.cell):
		return false
	cooldowns["%d:%s" % [sid, ability_id]] = sim.tick + int(a["cooldown_ticks"])
	sim.mutation.add_at(user.cell, float(a["contam_puff"]))
	var nb: Dictionary = a["noise_burst"]
	set_flag(user, "burst", sim.tick + int(nb["ticks"]), float(nb["mult"]))
	match ability_id:
		"taunt":
			var t: Dictionary = a["taunt"]
			set_flag(user, "taunt", sim.tick + int(t["ticks"]), float(t["mult"]), float(t["radius"]))
		"volley":
			volley[user.id] = [int(a["volley"]["shots"]), float(a["volley"]["dmg_mult"])]
		"stabilise":
			for c in _stab_targets(user, a):
				sim.health.call("stabilise", c, user)
	sim.bus.ability_used.emit(sid, ability_id, user.id)
	return true


## Flag entry: [until_tick, mult, radius (0 = global)].
func set_flag(c: Colonist, flag: String, until: int, mult: float, radius := 0.0) -> void:
	if not flags.has(c.id):
		flags[c.id] = {}
	flags[c.id][flag] = [until, mult, radius]
	if not _flagged.has(c.id):
		_flagged.append(c.id)
		_flagged.sort()


## Called by CombatSystem.try_attack: damage multiplier for this shot (1.0 = no volley), consuming one burst shot.
func take_volley(colonist_id: int) -> float:
	if not volley.has(colonist_id):
		return 1.0
	var v: Array = volley[colonist_id]
	v[0] = int(v[0]) - 1
	var m := float(v[1])
	if int(v[0]) <= 0:
		volley.erase(colonist_id)
	return m


func tick() -> void:
	if _flagged.is_empty():
		return
	var keep: Array[int] = []
	for id in _flagged:
		var c := sim.colonists.get_by_id(id)
		if c == null:
			continue
		var fl: Dictionary = flags_of(id)
		for f: String in fl.keys():
			if sim.tick >= int(fl[f][0]):
				fl.erase(f)
		if fl.is_empty():
			flags.erase(id)
		else:
			keep.append(id)
	_flagged = keep


## For SaveGame.state_hash: empty (so not appended) until an ability was used.
func state_parts() -> Array:
	if cooldowns.is_empty():
		return []
	var keys: Array = cooldowns.keys()
	keys.sort()
	var cds: Array = []
	for k in keys:
		cds.append([k, cooldowns[k]])
	var fl: Array = []
	for c in sim.colonists.list:
		if flags.has(c.id) or volley.has(c.id):
			fl.append([c.id, flags_of(c.id), volley.get(c.id, [])])
	return [cds, fl]
