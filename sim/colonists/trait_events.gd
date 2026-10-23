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
var _run: Dictionary = {}  # id -> [job type, consecutive days on it]
var _sample_n := 30
var alarm_since := 0  # tick the current alarm started (alarm_delay)


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	v3 = sim.traits_v3
	params = v3.cfg.get("event_params", {})
	_sample_n = maxi(1, int(params.get("sample_ticks", 30)))
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
	var live: Array[Colonist] = []
	var blocks_n: Dictionary = {}
	for c in sim.colonists.list:
		if c.alive:
			live.append(c)
			var b := sim.blocks.block_of(c) if sim.blocks != null else ""
			blocks_n[b] = int(blocks_n.get(b, 0)) + 1
	var by_block: Dictionary = {}
	var despair_lvl := float(params.get("despair_level", 80))
	var hi := float(params.get("standing_high", 70))
	var lo := float(params.get("standing_low", 30))
	var essence_cells := _essence_holders()
	for c in live:
		var b := sim.blocks.block_of(c) if sim.blocks != null else ""
		if not by_block.has(b):
			by_block[b] = [] as Array[Colonist]
		(by_block[b] as Array[Colonist]).append(c)
		if not v3.has(c, "t_old_timer"):
			_fire(c, "day_served")
		if not v3.has(c, "t_settled"):
			_fire(c, "calm_day")
		var ds: DebtState = sim.debt.state_of(c) if sim.debt != null else null
		if ds != null:
			if ds.despair >= despair_lvl:
				_fire(c, "despair_day")
			elif v3.counter(c, "despair_day") > 0:
				_fire(c, "despair_relief")
		if sim.blocks != null and sim.blocks.is_enabled():
			var st := sim.blocks.standing_of(b)
			if st >= hi:
				_fire(c, "high_standing_day")
			elif st <= lo:
				_fire(c, "low_standing_day")
		if _starving.has(c.id):
			_fire(c, "starving_day")
		_needs(c, b, int(blocks_n.get(b, 0)), essence_cells)
	_starving.clear()
	_bonds(by_block)
	# job-type memory for next day's "same job" need and rival runs
	for c in live:
		var t: String = _last_type.get(c.id, "")
		var run: Array = _run.get(c.id, ["", 0])
		_run[c.id] = [t, int(run[1]) + 1 if run[0] == t and t != "" else (1 if t != "" else 0)]
		_prev_type[c.id] = t
	_mined.clear()
	_last_type.clear()
	_letter_today = false


func _needs(c: Colonist, _block: String, mates_n: int, essence_cells: Array) -> void:
	var needs: Dictionary = v3.cfg.get("needs", {})
	var any := false
	for t in v3.list(c):
		if needs.has(t):
			any = true
			break
	if not any:
		return
	var cur: String = _last_type.get(c.id, "")
	var ctx := {
		"mined_today": _mined.has(c.id),
		"research_active": sim.research != null and sim.research.active() != "",
		"letter_today": _letter_today,
		"same_job": cur == "" or not _prev_type.has(c.id) or _prev_type[c.id] == "" or _prev_type[c.id] == cur,
		"block_mate_alive": mates_n > 1,
		"near_essence": v3.has(c, "t_essence_hum") and _near(c.cell, essence_cells),
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


## Pair bonds: ONE child-rng draw per eligible inmate (partner = next eligible block mate in id order).
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
			for i in arr.size():
				var a: Colonist = arr[i]
				if not a.alive or v3.has(a, id) or v3.can_add(a, id) != "":
					continue
				var days_a := _days(a, job_pair)
				for j in range(i + 1, arr.size()):
					var o: Colonist = arr[j]
					if not o.alive or v3.has(o, id) or v3.can_add(o, id) != "":
						continue
					if job_pair and (_run.get(o.id, ["", 0])[0] != _run.get(a.id, ["", 1])[0] or _run.get(a.id, ["", 0])[0] == ""):
						continue
					if v3.try_bond(a, o, id, mini(days_a, _days(o, job_pair)), rng):
						_letters(a, ["+" + id] as Array[String])
					break
		# loop ends; both partners carry the trait


func _days(c: Colonist, job_pair: bool) -> int:
	if job_pair:
		return int(_run.get(c.id, ["", 0])[1])
	return v3.counter(c, "day_served")
# endregion
