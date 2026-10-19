class_name Contraband
extends RefCounted
## Contraband stash: despairing inmates skim refined essence into a hidden stash; a squad
## shakedown recovers it (and spikes that inmate's despair); an ignored stash feeds a black
## market (a debt installment shrinks by 1 unit, capped, and a contamination-linked wave bump).
## Numbers: data/contraband.json. No rng, stable id order. Off by default (enabled=false):
## then nothing ticks and nothing enters the state hash.
## Conservation: skimmed == stash_total() + recovered + leaked.

var sim: Simulation
var cfg: Dictionary
var stash: Dictionary = {}  # colonist id -> units hidden
var skimmed := 0
var recovered := 0
var leaked := 0
var shakedowns := 0
var blackmarkets := 0
var bump_until := -1
var bump_mult := 0.0
var _relief: Dictionary = {}  # colonist id -> installment units shaved so far
var _cooldowns: Dictionary = {}  # squad id -> tick from which a shakedown is possible
var _next_market := 0
# region N2: covert trade (Escape path)
var escape_credit := 0
var suspicion := 0.0
var sales := 0
var inspections := 0
var raids := 0
var _next_inspection := 0
# endregion


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	cfg = sim.defs.contraband


func is_enabled() -> bool:
	return bool(cfg.get("enabled", false)) or (sim.quests != null and sim.quests.flag("contraband_on"))  # region N2


func stash_total() -> int:
	var n := 0
	for id: int in stash:
		n += int(stash[id])
	return n


## Units still allowed to be skimmed: cap_pct of everything refined so far, minus what was skimmed.
func skim_budget() -> int:
	var out := sim.ledger.get_count("recipe:" + str(cfg["item"]))
	return maxi(0, int(floor(out * float(cfg["skim_cap_pct"]) / 100.0)) - skimmed)


## Threat multiplier for raid points: exactly 1.0 unless a black-market bump is active.
func wave_mult() -> float:
	if bump_until >= 0 and sim.tick < bump_until:
		return 1.0 + bump_mult
	return 1.0


func _top_holder() -> int:
	var ids: Array = stash.keys()
	ids.sort()
	var top := -1
	for id: int in ids:
		if top < 0 or int(stash[id]) > int(stash[top]):
			top = id
	return top


func tick() -> void:
	if not is_enabled() or sim.tick == 0 or sim.tick % sim.ticks_per_day != 0:
		return
	_suspicion_day()  # region N2
	var item := str(cfg["item"])
	var ids: Array = sim.debt.states.keys()
	ids.sort()
	for id: int in ids:
		var c := sim.colonists.get_by_id(id)
		var st: DebtState = sim.debt.states[id]
		if c == null or not c.alive or not (st.despair >= float(cfg["despair_min"]) or _missed(st)):  # region N2
			continue
		var n := mini(mini(int(cfg["skim_per_inmate_day"]), skim_budget()), sim.items.count_stored(item))
		if n <= 0 or not sim.items.consume_stored(item, n, c.cell):
			continue
		sim.ledger.record_consumed(item, n, "skim")
		stash[id] = int(stash.get(id, 0)) + n
		skimmed += n
	if stash_total() >= int(cfg["blackmarket_stash"]) and sim.tick >= _next_market:
		_black_market()


func _black_market() -> void:
	var n := stash_total()
	var top := _top_holder()
	leaked += n
	sim.ledger.record_event("contraband:leaked", n)
	stash.clear()
	blackmarkets += 1
	_next_market = sim.tick + int(cfg["blackmarket_cooldown_days"]) * sim.ticks_per_day
	var st: DebtState = sim.debt.states.get(top)
	if st != null and st.remaining() > 1:
		var cap := ceili(st.total * float(cfg["relief_cap_pct"]) / 100.0)
		var give := mini(int(cfg["installment_relief"]), cap - int(_relief.get(top, 0)))
		if give > 0:
			_relief[top] = int(_relief.get(top, 0)) + give
			st.paid += give
			st.period_paid += give
	bump_mult = float(cfg["wave_bump"]) + float(cfg["wave_bump_per_contam"]) * sim.contamination.level
	bump_until = sim.tick + int(cfg["wave_bump_days"]) * sim.ticks_per_day
	sim.bus.letter_received.emit(str(cfg["lines"]["title"]), str(cfg["lines"]["blackmarket"]) % n)


## "" when a shakedown by squad `sid` is possible, else a short reason.
func can_shakedown(sid: int) -> String:
	if not is_enabled():
		return "disabled"
	var s: Squad = sim.squads.get_squad(sid)
	if s == null:
		return "no_squad"
	if int(_cooldowns.get(sid, 0)) > sim.tick:
		return "cooldown"
	if stash_total() <= 0:
		return "no_stash"
	for id: int in s.members:
		var c := sim.colonists.get_by_id(id)
		if c != null and c.alive:
			return ""
	return "no_user"


## Recovers the whole stash (back to the map centre) and spikes the biggest holder's despair.
## Costs the squad a patrol day (cooldown).
func shakedown(sid: int) -> bool:
	if can_shakedown(sid) != "":
		return false
	var top := _top_holder()
	var n := stash_total()
	var item := str(cfg["item"])
	sim.ledger.record_produced(item, n, "shakedown")
	sim.items.drop(sim.map_center(), item, n)  # a full map records the loss itself
	recovered += n
	stash.clear()
	shakedowns += 1
	suspicion = maxf(0.0, suspicion - float(cfg["shakedown_suspicion"]))  # region N2
	_cooldowns[sid] = sim.tick + int(cfg["shakedown_cooldown_days"]) * sim.ticks_per_day
	var st: DebtState = sim.debt.states.get(top)
	if st != null:
		st.despair = minf(100.0, st.despair + float(cfg["shakedown_despair"]))
	sim.bus.letter_received.emit(str(cfg["lines"]["title"]), str(cfg["lines"]["shakedown"]) % n)
	return true


## For SaveGame.state_hash: empty (not appended) until something was skimmed.
func state_parts() -> Array:
	if skimmed == 0:
		return []
	var ids: Array = stash.keys()
	ids.sort()
	var s: Array = []
	for id: int in ids:
		s.append([id, stash[id]])
	return [s, skimmed, recovered, leaked, bump_until, _next_market]


# region N2
## True when the installment is past its deadline plus grace and not covered.
func _missed(st: DebtState) -> bool:
	var dc: Dictionary = sim.defs.debt
	return sim.day() >= st.due_day + int(dc.get("grace_days", 0)) and st.period_paid < int(dc["installment"])


func covert_state_parts() -> Array:
	if suspicion <= 0.0 and escape_credit == 0 and sales == 0:
		return []
	return [escape_credit, snappedf(suspicion, 0.01), sales, inspections, raids, _next_inspection]


## "" when n refined can be sold to the Ferry now, else a short reason.
func can_covert_sale(n: int) -> String:
	if not is_enabled():
		return "disabled"
	if sim.quests == null or not sim.quests.flag("path_escape"):
		return "no_escape_path"
	if n <= 0:
		return "bad_amount"
	if sim.items.count_stored(str(cfg["item"])) < n:
		return "no_stock"
	return ""


## Sells n refined to the Ferry: +escape_credit (1:1), +suspicion (doubled while the Informant lives).
func covert_sale(n: int) -> bool:
	if can_covert_sale(n) != "":
		return false
	var item := str(cfg["item"])
	if not sim.items.consume_stored(item, n, sim.map_center()):
		return false
	sim.ledger.record_consumed(item, n, "covert_sale")
	escape_credit += n
	sales += 1
	var gain := float(cfg["suspicion_per_unit"]) * n
	if SocietyConds.informant_alive(sim):
		gain *= float(cfg["informant_suspicion_mult"])
	suspicion = minf(100.0, suspicion + gain)
	sim.ledger.record_event("contraband:covert_sale", n)
	_check_suspicion()
	return true


func _suspicion_day() -> void:
	suspicion = maxf(0.0, suspicion - float(cfg["suspicion_decay_day"]))
	_check_suspicion()


func _check_suspicion() -> void:
	if sim.tick < _next_inspection:
		return
	if suspicion >= float(cfg["raid_at"]):
		raids += 1
		_confiscate(int(cfg["raid_confiscate"]))
		suspicion = float(cfg["inspection_at"])
		_next_inspection = sim.tick + int(cfg["inspection_cooldown_days"]) * sim.ticks_per_day
		sim.bus.letter_received.emit(str(cfg["lines"]["title"]), str(cfg["lines"]["raid"]))
	elif suspicion >= float(cfg["inspection_at"]):
		inspections += 1
		_confiscate(int(cfg["inspection_confiscate"]))
		if sim.quests != null:
			sim.quests.set_mod("audit_parts_mult", float(cfg["inspection_audit_mult"]), float(cfg["inspection_days"]))
		_next_inspection = sim.tick + int(cfg["inspection_cooldown_days"]) * sim.ticks_per_day
		sim.bus.letter_received.emit(str(cfg["lines"]["title"]), str(cfg["lines"]["inspection"]))


## Warden shakedown: the stash (booked as recovered, conservation) and up to n refined are taken.
func _confiscate(n: int) -> void:
	var item := str(cfg["item"])
	var st := stash_total()
	if st > 0:
		recovered += st
		stash.clear()
	var take := mini(n, sim.items.count_stored(item))
	if take > 0 and sim.items.consume_stored(item, take, sim.map_center()):
		sim.ledger.record_consumed(item, take, "confiscated")
# endregion
