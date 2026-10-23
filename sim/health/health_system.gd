class_name HealthSystem
extends RefCounted
## Injuries, bleeding, capacities, downing and death of colonists.
## Numbers live in data/health.json.

var sim: Simulation
var cfg: Dictionary


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	cfg = sim.defs.health


func state_of(c: Colonist) -> HealthState:
	if c.health == null:
		c.health = HealthState.new()
		c.health.base_move_ticks = c.move_ticks
	return c.health


# --- Commands ---------------------------------------------------------------------

## Wounds a colonist. `part` "" picks a body part with sim.rng.
func apply_damage(c: Colonist, amount: float, part := "", kind := "bite") -> Injury:
	if not c.alive or amount <= 0.0:
		return null
	var dmg_taken := sim.perks.mod(c, "damage_taken")  # region perks + F11W3 (cap -0.5 on the perks + passives sum)
	var dmg_taken_p := sim.passives.mod(c, "damage_taken")
	if dmg_taken_p != 0.0:
		dmg_taken = maxf(-0.5, dmg_taken + dmg_taken_p)
	amount *= maxf(0.0, 1.0 + dmg_taken)
	amount *= sim.squads.role_mult(c.id, "dmg_taken_mult")  # region C1: Bulwark takes less
	if amount <= 0.0:
		return null
	var h := state_of(c)
	if part == "" or not cfg["parts"].has(part):
		part = _random_part()
	if not cfg["kinds"].has(kind):
		kind = "bite"
	var k: Dictionary = cfg["kinds"][kind]
	var inj := Injury.new(kind, part, amount)
	inj.bleed = float(k["bleed"])
	inj.pain = float(k["pain"])
	inj.label = str(k["name"])
	h.injuries.append(inj)
	sim.bus.injury_added.emit(c.id, part, kind, amount)
	_refresh(c, h)
	return inj


## Gives a colonist an illness lasting about `duration_ticks`.
func add_illness(c: Colonist, illness_id: String, severity: float, duration_ticks: int) -> Injury:
	if not c.alive:
		return null
	var h := state_of(c)
	var inj := Injury.new("illness", "torso", severity)
	inj.heal_per_tick = severity / float(maxi(1, duration_ticks))
	inj.illness_id = illness_id
	inj.label = str(cfg["illnesses"].get(illness_id, {"name": illness_id})["name"])
	h.injuries.append(inj)
	sim.bus.injury_added.emit(c.id, "torso", "illness", severity)
	_refresh(c, h)
	return inj


## Tends every untended injury. Quality comes from the doctor's medicine skill
## (if any). Returns the number of injuries tended.
func tend(patient: Colonist, doctor: Object = null, quality_mult := 1.0) -> int:
	if patient == null or not patient.alive or patient.health == null:
		return 0
	if sim.passives.rule(patient, "no_medicine"):  # region F11W3
		return 0
	var q := clampf(tend_quality(doctor) * quality_mult, 0.0, 1.0)
	# region perks: the doctor's perks (heal_speed, infection_chance, tend_quality)
	var doc: Colonist = doctor as Colonist
	q = clampf(q * (1.0 + sim.perks.mod(doc, "tend_quality") + sim.passives.mod(doc, "tend_quality")), 0.0, 1.0)  # F11W3
	# endregion
	var n := 0
	for i in patient.health.injuries:
		if not i.tended:
			i.tended = true
			i.tend_quality = q
			i.heal_bonus = sim.perks.mod(doc, "heal_speed") + sim.passives.mod(doc, "heal_speed")  # region perks + F11W3
			i.infection_bonus = sim.perks.mod(doc, "infection_chance") + sim.passives.mod(doc, "infection_chance")
			if doc != null and sim.passives.rule(doc, "field_tend"):  # region F11W3 (meta: no new Injury field, keeps golden dumps equal)
				i.set_meta("tended_by", doc.id)
			n += 1
	_refresh(patient, patient.health)
	return n


func tend_quality(doctor: Object) -> float:
	var t: Dictionary = cfg["tend"]
	var q := float(t["default_quality"])
	if doctor == null:
		return q
	var skills: Variant = doctor.get("skills")
	if skills is Skills:  # region doctor
		return clampf(float(t["base_quality"]) + float((skills as Skills).level("medicine")) * float(t["per_skill_level"]), 0.0, 1.0)
	var level: Variant = null
	if typeof(skills) == TYPE_DICTIONARY:
		level = (skills as Dictionary).get("medicine", null)
	elif skills is Object:
		level = (skills as Object).get("medicine")
	if typeof(level) == TYPE_DICTIONARY:
		level = (level as Dictionary).get("level", null)
	elif level is Object:
		level = (level as Object).get("level")
	if typeof(level) == TYPE_INT or typeof(level) == TYPE_FLOAT:
		q = float(t["base_quality"]) + float(level) * float(t["per_skill_level"])
	return clampf(q, 0.0, 1.0)


# region doctor
## True if a patient lies in this bed / shelter.
func bed_occupied(building_id: int) -> bool:
	for c in sim.colonists.list:
		if c.alive and c.health != null and c.health.bed_id == building_id:
			return true
	return false
# endregion


# region C4
func band(c: Colonist) -> String:
	return "fit" if c.health == null else c.health.band(cfg)


## Seconds of life left while Down and bleeding, -1 otherwise.
func bleed_out_seconds(c: Colonist) -> int:
	if c.health == null or not c.health.downed:
		return -1
	var t := c.health.bleed_out_ticks()
	return -1 if t < 0 else ceili(float(t) / float(Simulation.TICKS_PER_SECOND))


## Medic hook: tends every untended injury at the configured stabilise quality.
## Returns the number of injuries stabilised.
func stabilise(c: Colonist, medic: Object = null) -> int:
	return tend(c, medic, float(cfg["band"]["stabilise_quality"]) / maxf(0.01, tend_quality(medic)))
# endregion


# --- Queries ----------------------------------------------------------------------

func is_downed(c: Colonist) -> bool:
	return c.health != null and c.health.downed


## Deterministic work throttle: false on ticks a hurt colonist loses.
## Fleeing is never throttled.
func can_act(c: Colonist) -> bool:
	var h := c.health
	if h == null or h.injuries.is_empty():
		return true
	if sim.passives.rule(c, "ignore_pain"):  # region F11W3
		return true
	if sim.alarm or (c.job != null and c.job.type == "flee"):
		return true
	h.work_acc += maxf(float(cfg["min_work_speed"]), h.manipulation * h.consciousness)
	if h.work_acc >= 1.0:
		h.work_acc -= 1.0
		return true
	return false


# --- Tick -------------------------------------------------------------------------

func tick() -> void:
	var check := int(cfg["infection"]["check_ticks"])
	for c in sim.colonists.list:
		if not c.alive or c.health == null:
			continue
		var h := c.health
		if h.is_untouched():
			continue
		if h.bed_id >= 0 and sim.buildings.get_by_id(h.bed_id) == null:  # region doctor
			h.bed_id = -1
		_bleed_and_heal(c, h)
		if check > 0 and sim.tick % check == 0:
			_infection_check(c, h)
		_refresh(c, h)


func _bleed_and_heal(c: Colonist, h: HealthState) -> void:
	var rate := h.bleed_rate()
	rate *= maxf(0.0, 1.0 + sim.passives.mod(c, "bleed_rate"))  # region F11W3
	if h.carrier_id >= 0 and sim.passives.rule(sim.colonists.get_by_id(h.carrier_id), "medic"):  # region F11W3: carried by a medic
		rate = 0.0
	if rate > 0.0:
		h.blood = maxf(0.0, h.blood - rate)
	elif h.blood < 1.0:
		h.blood = minf(1.0, h.blood + float(cfg["blood_regen_per_tick"]))
	var bonus := float(cfg["tended_heal_bonus"])
	var rest_mult := float(cfg["doctor"]["bed_heal_mult"]) if h.bed_id >= 0 else 1.0  # region doctor
	var keep: Array[Injury] = []
	var own_heal := sim.perks.mod(c, "heal_speed") + sim.passives.mod(c, "heal_speed")  # region perks + F11W3: patient's own perk + tending doctor's
	var essence_heal := sim.passives.rule(c, "essence_heal")  # region F11W3
	var on_taint := essence_heal and sim.mutation != null and sim.mutation.is_tainted(c.cell)
	for i in h.injuries:
		var mult := 1.0 + i.tend_quality * bonus if i.tended else 1.0
		if essence_heal:  # region F11W3
			mult *= 3.0 if on_taint else 0.0
		var rm := rest_mult
		if h.bed_id < 0 and i.has_meta("tended_by"):  # region F11W3
			rm = float(cfg["doctor"]["bed_heal_mult"])
		mult *= maxf(0.0, 1.0 + own_heal + i.heal_bonus)
		if i.is_illness():
			i.severity -= i.heal_per_tick * mult * rm
		else:
			if not i.tended:
				mult = float(cfg["untended_heal_mult"])
			i.severity -= float(cfg["kinds"][i.kind]["heal"]) * mult * rm
		if i.severity > 0.0:
			keep.append(i)
	h.injuries = keep


func _infection_check(c: Colonist, h: HealthState) -> void:
	var inf: Dictionary = cfg["infection"]
	var chance := 0.0
	for i in h.injuries:
		if i.illness_id == "infection":
			return
		if cfg["kinds"][i.kind]["infectable"]:
			chance += float(inf["chance"]) * ((1.0 - i.tend_quality) if i.tended else 1.0) \
				* maxf(0.0, 1.0 + sim.perks.mod(c, "infection_chance") + sim.passives.mod(c, "infection_chance") + i.infection_bonus)  # region perks + F11W3
	if chance <= 0.0:
		return
	if sim.rng.randf() < minf(1.0, chance):
		add_illness(c, "infection", float(inf["illness_severity"]), int(inf["duration_ticks"]))


# --- Capacities / downed / death -------------------------------------------------------

func _refresh(c: Colonist, h: HealthState) -> void:
	var parts: Dictionary = cfg["parts"]
	var frac: Dictionary = {}
	var pain_sum := 0.0
	var illness := 0.0
	for p: String in parts:
		frac[p] = clampf(h.part_damage(p) / float(parts[p]["max_hp"]), 0.0, 1.0)
	for i in h.injuries:
		if i.is_illness():
			illness += i.severity
		else:
			pain_sum += i.severity * i.pain
	for p: String in ["arms", "legs"]:
		if frac[p] >= 1.0:
			h.lost[p] = true
	h.pain = clampf(pain_sum / float(cfg["pain_scale"]), 0.0, 1.0)
	h.moving = 0.0 if h.lost.has("legs") else clampf(1.0 - frac["legs"], 0.0, 1.0)
	h.manipulation = 0.0 if h.lost.has("arms") else clampf(1.0 - frac["arms"], 0.0, 1.0)
	var ok := float(cfg["blood_ok"])
	var unc := float(cfg["blood_unconscious"])
	var blood_factor := clampf((h.blood - unc) / (ok - unc), 0.0, 1.0)
	h.consciousness = clampf(1.0 - float(frac["head"]) - h.pain * float(cfg["pain_weight"]) \
		- illness * float(cfg["illness_weight"]), 0.0, 1.0) * blood_factor
	if h.moving > 0.0:
		c.move_ticks = maxi(1, roundi(h.base_move_ticks / maxf(h.moving, 0.2)))
	c.hp = clampf(c.max_hp - h.total_damage(), 0.0, c.max_hp)
	# Death: blood loss or a destroyed vital part.
	var dead := h.blood <= 0.0
	for p: String in parts:
		if parts[p]["vital"] and frac[p] >= 1.0:
			dead = true
	if dead:
		c.hp = 0.0
		sim.colonists.kill(c)
		return
	var now_downed := h.consciousness < float(cfg["downed_consciousness"]) \
		or h.moving < float(cfg["downed_moving"])
	if now_downed and sim.passives.rule(c, "no_downed"):  # region F11W3: dies instead of going down
		c.hp = 0.0
		sim.colonists.kill(c)
		return
	if now_downed and not h.downed:
		h.downed = true
		_on_downed(c)
	elif not now_downed and h.downed:
		h.downed = false
		h.bed_id = -1  # region doctor: up and about


func _on_downed(c: Colonist) -> void:
	sim.jobs.end_job(c, Job.Status.FAILED)
	c.clear_path()
	if c.carry_count > 0:
		sim.items.drop(c.cell, c.carry_item, c.carry_count, c.carry_quality)
		c.carry_item = ""
		c.carry_count = 0
	sim.colonists.rec(c)["downs"] += 1  # region F3
	sim.colonists.record_changed(c)
	sim.bus.colonist_downed.emit(c.id)


func _random_part() -> String:
	var parts: Dictionary = cfg["parts"]
	var total := 0.0
	for p: String in parts:
		total += float(parts[p]["weight"])
	var roll := sim.rng.randf() * total
	var last := ""
	for p: String in parts:
		last = p
		roll -= float(parts[p]["weight"])
		if roll <= 0.0:
			return p
	return last
