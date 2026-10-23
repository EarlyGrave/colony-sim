class_name TraitEvents
extends RefCounted
## Bus adapter for traits v3 (docs/gdd/03-colony/traits-v3/acquisition.md, interactions.md).
## Only created when balance.traits_v3_enabled. Translates bus signals and the day roll into
## TraitSystemV3.event() calls, trait needs (thoughts), pair bonds, and Warden letters.
## Deterministic: no rng except ONE sim.rng draw per day that seeds a child rng for bonds.

var sim: Simulation
var v3: TraitSystemV3
var params: Dictionary

var _starving: Dictionary = {}  # colonist id -> true since the last day roll
var _downed_wave: Dictionary = {}  # ids downed during the current wave
var _letter_today := false
var _mined: Dictionary = {}  # id -> had a mine job today (sampled)
var _last_type: Dictionary = {}  # id -> last sampled job type today
var _prev_type: Dictionary = {}  # id -> job type at the previous day roll
var _run_t: Dictionary = {}  # id -> job type of the current run
var _run_n: Dictionary = {}  # id -> consecutive days on that job type
var _need_ids: Dictionary = {}
var _despair_lvl := 80.0
var _hi := 70.0
var _lo := 30.0
var _sample_n := 30
var _min: Dictionary = {}  # event name -> smallest acquire threshold
var _elig: Dictionary = {}  # id -> [trait-list hash, {bond id: can bond}]
var alarm_since := 0  # tick the current alarm started (alarm_delay)


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	v3 = sim.traits_v3
	params = v3.cfg.get("event_params", {})
	_sample_n = maxi(1, int(params.get("sample_ticks", 30)))
	var ix := v3._rule_index()
	for n: String in ix:
		if (ix[n] as Dictionary).has("min"):
			_min[n] = int(ix[n]["min"])
	_need_ids = v3.cfg.get("needs", {})
	_despair_lvl = float(params.get("despair_level", 80))
	_hi = float(params.get("standing_high", 70))
	_lo = float(params.get("standing_low", 30))
	var b := sim.bus
	sim.listen(b.day_started, _on_day)
	sim.listen(b.tick_advanced, _on_tick)
	sim.listen(b.colonist_rescued, _on_rescued)
	sim.listen(b.mood_break_started, _on_break)
	sim.listen(b.colonist_downed, _on_downed)
	sim.listen(b.wave_ended, _on_wave_ended)
	sim.listen(b.injury_added, _on_injury)
	sim.listen(b.skill_leveled, _on_skill)
	sim.listen(b.riot_started, _on_riot)
	sim.listen(b.escape_stopped, _on_escape_stopped)
	sim.listen(b.colonist_starving, _on_starving)
	sim.listen(b.colonist_ate, _on_ate)
	sim.listen(b.waste_scrubbed, _on_scrubbed)
	sim.listen(b.letter_received, _on_letter)
	sim.listen(b.alarm_changed, _on_alarm)
	sim.listen(b.colonist_died, _on_gone)
	sim.listen(b.colonist_escaped, _on_gone)


# region public
## Called by MutationSystem when a colonist falls ill from tainted ground (the essence ladder).
func exposure_illness(c: Colonist) -> Array[String]:
	return _fire(c, "exposure_illness")


## Emits one named trait event for `c` and posts the Warden letters. Returns the "+id"/"-id" list.
func fire(c: Colonist, name: String) -> Array[String]:
	return _fire(c, name)
# endregion


func _fire(c: Colonist, name: String) -> Array[String]:
	if c == null or not c.alive:
		return []
	var res := v3.event(c, name)
	if not res.is_empty():
		_letters(c, res)
	return res


## Warden letters (data traits_v3.json `letters`); a ladder step posts only the new rung.
func _letters(c: Colonist, res: Array[String]) -> void:
	if sim.quests != null and sim.quests.mod("pa_silent") > 0.0:
		return
	var L: Dictionary = v3.cfg.get("letters", {})
	var title := str(params.get("letter_title", "Warden"))
	var added := false
	for r in res:
		if r.begins_with("+"):
			added = true
			var id := r.substr(1)
			var special: Dictionary = L.get("special", {})
			var text: String
			if special.has(id):
				text = str(special[id]) % c.display_name
			else:
				text = str(L.get("add", "%s is logged as %s.")) % [c.display_name, str(v3.def(id).get("name", id))]
			sim.bus.letter_received.emit(title, text)
	if added:
		return
	for r in res:
		if r.begins_with("-"):
			var id := r.substr(1)
			sim.bus.letter_received.emit(title, str(L.get("remove", "%s: %s withdrawn.")) % [c.display_name, str(v3.def(id).get("name", id))])


# region bus handlers
func _on_tick(tick: int) -> void:
	if tick % _sample_n != 0:
		return
	for c in sim.colonists.list:
		if not c.alive or c.job == null:
			continue
		var t: String = c.job.type
		_last_type[c.id] = t
		if t == "mine":
			_mined[c.id] = true


func _on_rescued(patient_id: int, _carrier: int) -> void:
	_fire(sim.colonists.get_by_id(patient_id), "rescued")


func _on_break(cid: int, _kind: String) -> void:
	_fire(sim.colonists.get_by_id(cid), "break")


func _on_downed(cid: int) -> void:
	if sim.threats != null and sim.threats.wave_active:
		_downed_wave[cid] = true
		_fire(sim.colonists.get_by_id(cid), "downed_in_wave")


func _on_wave_ended(_idx: int) -> void:
	for c in sim.colonists.list:
		if c.alive and not _downed_wave.has(c.id) and v3.has(c, "t_shellshocked"):
			_fire(c, "wave_unscathed")
	_downed_wave.clear()


func _on_injury(cid: int, _part: String, kind: String, severity: float) -> void:
	if kind != "illness" and severity >= float(params.get("heavy_injury", 20)):
		_fire(sim.colonists.get_by_id(cid), "heavy_injury")


func _on_skill(cid: int, _skill: String, level: int) -> void:
	if level == int(params.get("skill_seven", 7)):
		_fire(sim.colonists.get_by_id(cid), "skill_seven")


func _on_riot(cid: int) -> void:
	_fire(sim.colonists.get_by_id(cid), "riot")


func _on_escape_stopped(cid: int) -> void:
	_fire(sim.colonists.get_by_id(cid), "escape_stopped")


func _on_starving(cid: int) -> void:
	_starving[cid] = true


func _on_ate(cid: int, _item: String) -> void:
	var c := sim.colonists.get_by_id(cid)
	if c != null and v3.counter(c, "starving_day") > 0:
		_fire(c, "ate")


func _on_scrubbed(cid: int, _cell: Vector2i, _amount: float) -> void:
	var c := sim.colonists.get_by_id(cid)
	if c != null and not v3.has(c, "t_waste_kin"):
		_fire(c, "scrubbed_cell")


func _on_alarm(on: bool) -> void:
	if on:
		alarm_since = sim.tick


func _on_letter(_title: String, _text: String) -> void:
	_letter_today = true


## Partner died or left: pair traits go, the survivor keeps a memory counter.
func _on_gone(cid: int) -> void:
	for c in sim.colonists.list:
		if c.id == cid or not c.alive:
			continue
		for bid: Variant in params.get("bond_ids", []):
			if v3.has(c, str(bid)) and v3.partner(c, str(bid)) == cid:
				v3.break_bond(c, str(bid))
# endregion


# region daily
func _on_day(_day: int) -> void:
	var blocks_on := sim.blocks != null
	var standing_on := blocks_on and sim.blocks.is_enabled()
	var by_block: Dictionary = {}
	var live: Array = []
	for c: Colonist in sim.colonists.list:
		if not c.alive:
			continue
		live.append(c)
		var b: String = sim.blocks.block_of(c) if blocks_on else ""
		var arr: Variant = by_block.get(b)
		if arr == null:
			arr = []
			by_block[b] = arr
		arr.append(c)
	var essence_cells := _essence_holders()
	var debt := sim.debt
	var has_debt := debt != null
	var states: Dictionary = debt.states if has_debt else {}
	var need_ids := _need_ids
	var min_day: int = _min.get("day_served", 1)
	var min_calm: int = _min.get("calm_day", 1)
	var any_starving := not _starving.is_empty()
	for b: String in by_block:
		var mates: Array = by_block[b]
		var st := sim.blocks.standing_of(b) if standing_on else 50.0
		var n_mates := mates.size()
		for c: Colonist in mates:
			var bio := c.bio
			var cn: Dictionary = bio.get("trait_counters", {})
			bio["trait_counters"] = cn
			var held: Array = bio.get("traits_v3", [])
			# cheap counters: events below every rule threshold only bump the counter
			if not held.has("t_old_timer"):
				var nd := int(cn.get("day_served", 0)) + 1
				if nd < min_day:
					cn["day_served"] = nd
				else:
					_fire(c, "day_served")
			if not held.has("t_settled"):
				var nc := int(cn.get("calm_day", 0)) + 1
				if nc < min_calm:
					cn["calm_day"] = nc
				else:
					_fire(c, "calm_day")
			if has_debt:
				var ds: DebtState = states.get(c.id)
				if ds != null:
					if ds.despair >= _despair_lvl:
						_fire(c, "despair_day")
					elif cn.has("despair_day") and int(cn["despair_day"]) > 0:
						_fire(c, "despair_relief")
			if standing_on:
				if st >= _hi:
					_fire(c, "high_standing_day")
				elif st <= _lo:
					_fire(c, "low_standing_day")
			if any_starving and _starving.has(c.id):
				_fire(c, "starving_day")
			for t in held:
				if need_ids.has(t):
					_needs(c, held, n_mates, essence_cells)
					break
	_starving.clear()
	_bonds(by_block)
	# job-type memory for next day's "same job" need and rival runs
	for c: Colonist in live:
		var t: String = _last_type.get(c.id, "")
		if t != "" and _run_t.get(c.id, "") == t:
			_run_n[c.id] = int(_run_n.get(c.id, 0)) + 1
		else:
			_run_n[c.id] = 1 if t != "" else 0
		_run_t[c.id] = t
		_prev_type[c.id] = t
	_mined.clear()
	_last_type.clear()
	_letter_today = false


func _needs(c: Colonist, held: Array, mates_n: int, essence_cells: Array) -> void:
	var cur: String = _last_type.get(c.id, "")
	var ctx := {
		"mined_today": _mined.has(c.id),
		"research_active": sim.research != null and sim.research.active() != "",
		"letter_today": _letter_today,
		"same_job": cur == "" or not _prev_type.has(c.id) or _prev_type[c.id] == "" or _prev_type[c.id] == cur,
		"block_mate_alive": mates_n > 1,
		"near_essence": held.has("t_essence_hum") and _near(c.cell, essence_cells),
	}
	for tid in v3.daily_needs(c, ctx):
		sim.mood.add_thought(c, tid)


## Cells holding refined essence (only scanned when someone has Hums).
func _essence_holders() -> Array:
	var hum := false
	for c in sim.colonists.list:
		if c.alive and v3.has(c, "t_essence_hum"):
			hum = true
			break
	var out: Array = []
	if not hum:
		return out
	var items: Array = params.get("essence_items", [])
	for cell: Vector2i in sim.items.stacks:
		if items.has(sim.items.item_at(cell)):
			out.append(cell)
	return out


func _near(cell: Vector2i, cells: Array) -> bool:
	var r := int(params.get("essence_radius", 6))
	for o: Vector2i in cells:
		if absi(o.x - cell.x) <= r and absi(o.y - cell.y) <= r:
			return true
	return false


## Pair bonds: ONE child-rng draw per eligible inmate (partner = next eligible mate in id order; a rival must
## share the job type and the block).
func _bonds(by_block: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = sim.rng.randi()
	var bonds: Dictionary = v3.cfg.get("bonds", {})
	var blocks: Array = by_block.keys()
	blocks.sort()
	for bid: Variant in params.get("bond_ids", []):
		var id := str(bid)
		if not bonds.has(id):
			continue
		var job_pair := (bonds[id] as Dictionary).has("days_same_job")
		for b in blocks:
			var arr: Array = by_block[b]
			if not job_pair:
				_pair_seq(arr, id, false, rng)
				continue
			var groups: Dictionary = {}  # job type -> members (block order)
			for c: Colonist in arr:
				var t: String = _run_t.get(c.id, "")
				if t != "":
					if not groups.has(t):
						groups[t] = []
					(groups[t] as Array).append(c)
			var types: Array = groups.keys()
			types.sort()
			for t in types:
				_pair_seq(groups[t], id, true, rng)


func _pair_seq(arr: Array, id: String, job_pair: bool, rng: RandomNumberGenerator) -> void:
	var bd: Dictionary = v3.cfg["bonds"][id]
	var need := int(bd.get("days_same_block", bd.get("days_same_job", 9999)))
	var n := arr.size()
	for i in n:
		var a: Colonist = arr[i]
		if not a.alive or _days(a, job_pair) < need or not _can_bond(a, id):
			continue
		for j in range(i + 1, n):
			var o: Colonist = arr[j]
			if not o.alive or _days(o, job_pair) < need or not _can_bond(o, id):
				continue
			if v3.try_bond(a, o, id, mini(_days(a, job_pair), _days(o, job_pair)), rng):
				_letters(a, ["+" + id] as Array[String])
			break


## Cached `can_add(c, id) == ""`, keyed by a hash of the trait list (changes only when traits change).
func _can_bond(c: Colonist, id: String) -> bool:
	var h := (c.bio.get("traits_v3", []) as Array).hash()
	var e: Variant = _elig.get(c.id)
	if e == null or e[0] != h:
		e = [h, {}]
		_elig[c.id] = e
	var m: Dictionary = e[1]
	if not m.has(id):
		m[id] = v3.can_add(c, id) == ""
	return m[id]


func _days(c: Colonist, job_pair: bool) -> int:
	if job_pair:
		return int(_run_n.get(c.id, 0))
	return v3.counter(c, "day_served")
# endregion
