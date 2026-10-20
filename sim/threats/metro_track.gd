class_name MetroTrack
extends RefCounted
## Metropolis tech track (docs/design/threats_pacing.md 2b). Keyed by DEFIANCE, not pollution:
## +per unmet-quota day, +per declined audit, +per covert sale; decays on days essence was shipped.
## Drone raids (data/metro.json, faction "metropolis") never share a day with creature waves.
## Inert unless balance.metro.enabled. Deterministic: plain arithmetic, raid composition via ThreatSystem.

var sim: Simulation
var cfg: Dictionary
var defiance := 0.0
var raids_started := 0
var raids_repelled := 0  # region W4: drone raids repelled (cond raids_survived); replay-derived, not in state dump
var final_done := false
var next_raid_tick := -1
var _last_paid := 0
var _paid_init := false


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	cfg = sim.defs.balance.get("metro", {})
	if enabled():
		next_raid_tick = int(float(cfg["first_raid_day"]) * sim.ticks_per_day)


func enabled() -> bool:
	return bool(cfg.get("enabled", false))


# --- clock -----------------------------------------------------------------

func add_defiance(amount: float) -> void:
	defiance = clampf(defiance + amount, 0.0, float(cfg.get("max", 100.0)))


func note_declined_audit() -> void:
	if enabled():
		add_defiance(float(cfg["per_declined_audit"]))


func note_covert_sale(n: int) -> void:
	if enabled():
		add_defiance(float(cfg["suspicion_per_sale"]) * n)


func _paid_total() -> int:
	var t := 0
	for id: int in sim.debt.states:
		t += int(sim.debt.states[id].paid)
	return t


func _quota_total() -> int:
	var t := 0
	for id: int in sim.debt.states:
		t += int(sim.debt.states[id].quota)
	return t


## Once per day: shipping essence lowers defiance, an unmet quota raises it.
func daily() -> void:
	var paid := _paid_total()
	if not _paid_init:
		_paid_init = true
		_last_paid = paid
	var shipped := paid > _last_paid
	_last_paid = paid
	if sim.path() == "fight":  # region F2: the fight path defies the Metropolis: defiance climbs every day, shipping no longer calms it
		add_defiance(float(cfg["per_unmet_day"]))
		return
	if shipped:
		add_defiance(-float(cfg["decay_on_ship"]))
	elif _quota_total() > 0:
		add_defiance(float(cfg["per_unmet_day"]))


# --- raids -----------------------------------------------------------------

func points() -> float:
	var p := float(cfg["base"]) + float(cfg["per_defiance"]) * defiance
	if fight_path():
		p *= 1.0 + float(cfg["fight_escalation"]) * raids_started
	return p


## Fight path: the colony ignores the shuttle, defiance stays high -> raids escalate to the Collector assault.
func fight_path() -> bool:
	return defiance >= float(cfg["fight_threshold"])


## region F2e: the player picked the fight path (distinct from fight_path(), the high-defiance escalation state).
func chosen_fight() -> bool:
	return sim.path() == "fight"


func wants_final() -> bool:
	return fight_path() and not final_done and raids_started >= int(cfg["final_after_raids"])


func pick_raid() -> String:
	if wants_final():
		return "collector_assault"
	var ids: Array[String] = []
	var p := points()
	for id: String in sim.defs.raids:  # drone rows live in data/raids.json, tagged faction "metropolis"
		var r: Dictionary = sim.defs.raids[id]
		if str(r.get("faction", "creature")) != "metropolis":
			continue
		if not bool(r.get("final", false)) and float(r["min_points"]) <= p:
			ids.append(id)
	ids.sort()
	if ids.is_empty():
		return ""
	return ids[raids_started % ids.size()]


## Called every tick from ThreatSystem.tick. Returns true when a drone raid was started this tick.
func tick() -> bool:
	if not enabled():
		return false
	var th := sim.threats
	if sim.tick % sim.ticks_per_day == 0:
		daily()
	if th.wave_active or not th.awakened or sim.tick < next_raid_tick:
		return false
	if defiance < float(cfg["min_defiance"]):
		return false
	var grace := int(float(cfg["grace_days"]) * sim.ticks_per_day)
	if not chosen_fight() and not fight_path() and th.next_wave_tick >= 0 and th.next_wave_tick - sim.tick < grace:  # region F2: on the fight path the Metropolis does not wait for creature waves
		return false  # a creature wave is imminent: never stack, wait for it
	var id := pick_raid()
	if id == "":
		return false
	var pts := points()
	th.set_meta("metro_points", pts)
	th.force_raid_id = id
	th.start_wave()
	th.force_raid_id = ""
	th.remove_meta("metro_points")
	raids_started += 1
	if id == "collector_assault":
		final_done = true
	next_raid_tick = sim.tick + int(float(cfg["fight_interval_days" if chosen_fight() else "interval_days"]) * sim.ticks_per_day)  # region F2e: the fight path is raided more often
	# the pollution timer yields: no creature wave for grace_days after a drone raid ends
	th.next_wave_tick = maxi(th.next_wave_tick, th.wave_end_tick + grace)
	sim.bus.metro_raid_started.emit(id, pts)
	if id == "collector_assault":  # region EN4
		sim.fight_escape.on_collector_assault()
	return true


## A creature wave ended: drones hold off for grace_days.
func on_creature_wave_end() -> void:
	if enabled() and not (chosen_fight() and bool(cfg.get("fight_raid_after_wave", true))):  # region F2e: on the fight path the first gap after a wave is the raid window
		next_raid_tick = maxi(next_raid_tick, sim.tick + int(float(cfg["grace_days"]) * sim.ticks_per_day))
