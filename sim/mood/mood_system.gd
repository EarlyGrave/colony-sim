class_name MoodSystem
extends RefCounted
## RimWorld-like basic mood: base + active thoughts; low mood causes breaks.
## Numbers and thoughts live in data/mood.json.

var sim: Simulation
var cfg: Dictionary


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	cfg = sim.defs.mood
	sim.listen(sim.bus.colonist_died, _on_colonist_died)
	sim.listen(sim.bus.wave_ended, _on_wave_ended)
	sim.listen(sim.bus.forecast_revealed, _on_forecast)


func state_of(c: Colonist) -> Mood:
	if c.mood == null:
		c.mood = Mood.new()
		c.mood.value = float(cfg["base"])
	return c.mood


## Public: other systems add a thought by id (unknown ids are ignored).
## Re-adding an active thought refreshes its duration.
func add_thought(c: Colonist, id: String) -> bool:
	if c == null or not c.alive or not cfg["thoughts"].has(id):
		return false
	var def: Dictionary = cfg["thoughts"][id]
	var m := state_of(c)
	var days := float(def["duration_days"])
	var until := -1 if days <= 0.0 else sim.tick + maxi(1, roundi(days * sim.ticks_per_day))
	var i := m.find(id)
	if i >= 0:
		m.thoughts[i]["until"] = until
		return true
	m.thoughts.append({"id": id, "value": float(def["value"]), "until": until})
	_recalc(m)
	sim.bus.thought_added.emit(c.id, id)
	return true


func mood_of(c: Colonist) -> float:
	return state_of(c).value


func _recalc(m: Mood) -> void:
	var v := float(cfg["base"])
	for t in m.thoughts:
		v += float(t["value"])
	m.value = clampf(v, 0.0, 100.0)


func tick() -> void:
	var check := int(cfg["check_ticks"])
	if check <= 0 or sim.tick % check != 0:
		return
	var day_roll := sim.tick % sim.ticks_per_day == 0
	for c in sim.colonists.list:
		if not c.alive:
			continue
		var m := state_of(c)
		if c.health != null and not c.health.injuries.is_empty():
			add_thought(c, "injured")
			# Refreshed while hurt; expires shortly after healing.
			m.thoughts[m.find("injured")]["until"] = sim.tick + check * 2
		var keep: Array[Dictionary] = []
		for t in m.thoughts:
			if int(t["until"]) < 0 or int(t["until"]) > sim.tick:
				keep.append(t)
		m.thoughts = keep
		_recalc(m)
		if m.break_kind != "" and (c.job == null or c.job.type != "mental_break"):
			m.break_kind = ""
		if day_roll:
			_roll_break(c, m)


func _roll_break(c: Colonist, m: Mood) -> void:
	if m.break_kind != "" or c.hidden or sim.health.is_downed(c):
		return
	if m.value >= float(cfg["minor_threshold"]):
		return
	var extreme := m.value < float(cfg["extreme_threshold"])
	var chance := float(cfg["extreme_chance"] if extreme else cfg["minor_chance"])
	if sim.rng.randf() >= chance:
		return
	var kind := "wander"
	if extreme and _sabotage():
		kind = "sabotage"
	m.break_kind = kind
	m.break_until = sim.tick + int(cfg["wander_ticks"])
	sim.jobs.request_override(c, BreakJob.new(kind, m.break_until, int(cfg["wander_radius"])))
	sim.bus.mood_break_started.emit(c.id, kind)


## Wrecks one random working machine; false if there is none.
func _sabotage() -> bool:
	var machines: Array[Building] = []
	for b in sim.buildings.list:
		if b.is_machine() and not b.destroyed and not b.broken:
			machines.append(b)
	if machines.is_empty():
		return false
	var b := machines[sim.rng.randi_range(0, machines.size() - 1)]
	b.condition = 0.0
	b.broken = true
	b.progress = 0
	sim.bus.building_broken.emit(b.id)
	return true


func _on_colonist_died(id: int) -> void:
	for c in sim.colonists.list:
		if c.alive and c.id != id:
			add_thought(c, "colonist_died")


func _on_wave_ended(_i: int) -> void:
	for c in sim.colonists.list:
		add_thought(c, "wave_survived")


func _on_forecast() -> void:
	for c in sim.colonists.list:
		add_thought(c, "planet_doomed")
