class_name FeedDirector
extends RefCounted
## F2: turns bus facts into kill-feed lines and Warden PA announcements. View-side and cosmetic:
## never touches sim.rng or sim state. Text comes from F1's FlavorPicker
## (keys feed.<enemy>.<cause> -> feed.<enemy>.generic -> feed.generic, pa.<signal>). One signal -> exactly one line on exactly one surface:
##   feed: enemy_killed, colonist_downed, building_destroyed
##   PA:   wave_started, wave_incoming, crisis_started, research_completed, colonist_died,
##         outpost_lost, every 5th day_started
##   F6W2 PA: quest_beat -> pa.<quest>.<beat> then pa.<quest> (missing = silent); day 40/50 with a
##         path_* flag -> pa.r4_midgame.d40/d50. Nothing when sim.quests.mod("pa_silent") > 0.
##   F7W3 PA: regulation_offered -> pa.regulation.offered; regulation_chosen -> pa.regulation.<id> then
##         pa.regulation.generic. fixation_* signals are NOT shown here (Warden letters already exist).

const DAY_ASIDE_EVERY := 5
const MAX_LEN := 70

var sim: Simulation
var feed: FeedTicker
var pa: PaBanner
var _picker: FlavorPicker = FlavorPicker.load_default()
var _conns: Array = []  # [signal, Callable]


func _init(p_feed: FeedTicker, p_pa: PaBanner) -> void:
	feed = p_feed
	pa = p_pa


func bind(p_sim: Simulation) -> void:
	unbind()
	sim = p_sim
	var b: Node = sim.bus
	_c(b.enemy_killed, _on_enemy_killed)
	_c(b.colonist_downed, _on_downed)
	_c(b.colonist_died, _on_died)
	_c(b.building_destroyed, _on_building)
	_c(b.wave_started, func(_i: int, _s: float) -> void: _pa(FlavorPicker.K_PA_WAVE_STARTED, {}))
	_c(b.wave_incoming, func(_o: Vector2i, _t: int) -> void: _pa(FlavorPicker.K_PA_WAVE_INCOMING, {}))
	_c(b.crisis_started, func(_i: String, _t: String) -> void: _pa(FlavorPicker.K_PA_CRISIS_STARTED, {}))
	_c(b.research_completed, func(_i: String) -> void: _pa(FlavorPicker.K_PA_RESEARCH_COMPLETED, {}))
	if b.has_signal("outpost_lost"):
		_c(b.outpost_lost, func(_i: int) -> void: _pa(FlavorPicker.K_PA_OUTPOST_LOST, {}))
	_c(b.wave_repelled, func(_i: int) -> void: _pa(FlavorPicker.K_PA_WAVE_REPELLED, {}))
	_c(b.day_started, _on_day)
	_c(b.quest_beat, _on_quest_beat)  # region F6W2
	_c(b.regulation_offered, _on_reg_offered)  # region F7W3
	_c(b.regulation_chosen, _on_reg_chosen)  # region F7W3


func unbind() -> void:
	for pair: Array in _conns:
		var s: Signal = pair[0]
		if s.is_connected(pair[1]):
			s.disconnect(pair[1])
	_conns.clear()


func _c(s: Signal, f: Callable) -> void:
	s.connect(f)
	_conns.append([s, f])


func _on_enemy_killed(id: int) -> void:
	var kind := sim.threats.last_kill_kind()
	var cause := sim.threats.last_kill_cause()
	var name_ := str(sim.defs.enemies.get(kind, {}).get("name", "Creature"))
	var gone := MimicFace.gone_line(sim, id, kind, _picker)  # region F4f: Q15 reveal
	if gone != "":
		feed.push(gone)
		return
	var ctx := {"enemy": name_, "n": id, "cause": cause}
	var keys: Array[String] = ["feed.%s.%s" % [kind, cause], "feed.%s.generic" % kind, FlavorPicker.K_FEED_GENERIC]
	feed.push(_line(keys, ctx, id))


func _on_downed(id: int) -> void:
	feed.push(_line([FlavorPicker.K_FEED_COLONIST_DOWNED, FlavorPicker.K_FEED_COLONIST_GENERIC, FlavorPicker.K_FEED_GENERIC], {"who": _who(id), "victim": _who(id)}, id))


func _on_died(id: int) -> void:
	_pa(FlavorPicker.K_PA_COLONIST_DIED, {"who": _who(id), "victim": _who(id), "cause": death_cause(id)}, id)


func _on_building(id: int) -> void:
	feed.push(_line([FlavorPicker.K_FEED_BUILDING_DESTROYED, FlavorPicker.K_FEED_GENERIC], {"n": id}, id))


func _on_day(day: int) -> void:
	if _mid_pa(day):  # region F6W2: replaces the quiet-day aside
		return
	if day > 0 and day % DAY_ASIDE_EVERY == 0:
		_pa(FlavorPicker.K_PA_QUIET_DAY, {"n": day}, day)


func _pa(key: String, ctx: Dictionary, subject := 0) -> void:
	pa.announce(_line([key], ctx, subject))


func _who(id: int) -> String:
	var c: Colonist = sim.colonists.get_by_id(id)
	return c.display_name if c != null else "Inmate"


## Cosmetic cause of a colonist death from the body state; "generic" when unknown.
func death_cause(id: int) -> String:
	var c: Colonist = sim.colonists.get_by_id(id)
	if c == null or c.health == null:
		return "generic"
	var h: HealthState = c.health
	if h.injuries.is_empty():
		return "generic"
	var worst: Injury = h.injuries[0]
	for i in h.injuries:
		if i.severity > worst.severity:
			worst = i
	if worst.kind == "starvation" or worst.kind == "burn":
		return worst.kind
	return "bleed_out" if h.blood <= 0.0 else "generic"


func _line(keys: Array[String], ctx: Dictionary, subject: int) -> String:
	var c := ctx.duplicate()
	c["tick"] = sim.tick if sim != null else 0
	c["id"] = subject
	var s := _picker.pick_first(keys, c)
	return _fit(s if s != "" else "...")


func _fit(s: String) -> String:
	return s if s.length() <= MAX_LEN else s.left(MAX_LEN - 1) + "."


# region F6W2
func _pa_silent() -> bool:
	return sim.quests != null and sim.quests.mod("pa_silent") > 0.0


func _on_quest_beat(quest_id: String, beat_id: String, _text: String) -> void:
	if _pa_silent():
		return
	var keys: Array[String] = ["pa.%s.%s" % [quest_id, beat_id], "pa.%s" % quest_id]
	var s := _picker.pick_first(keys, {"tick": sim.tick, "id": beat_id})
	if s != "":
		pa.announce(_fit(s))


func _mid_pa(day: int) -> bool:
	if (day != 40 and day != 50) or _pa_silent():
		return false
	if not (sim.quests.flag("path_submit") or sim.quests.flag("path_fight") or sim.quests.flag("path_escape")):
		return false
	var s := _picker.pick_first(["pa.r4_midgame.d%d" % day], {"tick": sim.tick, "id": day})
	if s == "":
		return false
	pa.announce(_fit(s))
	return true
# endregion


# region F7W3
func _on_reg_offered(slot: int) -> void:
	_reg_pa(["pa.regulation.offered"] as Array[String], slot)


func _on_reg_chosen(slot: int, id: String, _by_timeout: bool) -> void:
	_reg_pa(["pa.regulation.%s" % id, "pa.regulation.generic"] as Array[String], slot)


func _reg_pa(keys: Array[String], slot: int) -> void:
	if _pa_silent():
		return
	var s := _picker.pick_first(keys, {"tick": sim.tick, "id": slot})
	if s != "":
		pa.announce(_fit(s))
# endregion
