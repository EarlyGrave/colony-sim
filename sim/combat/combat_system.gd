class_name CombatSystem
extends RefCounted
## Attack resolution for colonists, draft commands and the "fight back" /
## "retreat" reflexes of undrafted colonists. Numbers: data/weapons.json.

var sim: Simulation
var cfg: Dictionary


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	cfg = sim.defs.weapons["combat"]


func weapon_def(c: Colonist) -> Dictionary:
	return sim.defs.weapons["weapons"][c.combat.weapon]


func hit_chance(c: Colonist, w: Dictionary, dist: float) -> float:
	var p := float(cfg["hit_base"]) + float(cfg["hit_per_skill"]) * c.skills.level(str(w["skill"]))
	if str(w["kind"]) == "ranged":
		p -= float(cfg["range_penalty"]) * maxf(0.0, dist - 1.0)
	if c.health != null:
		p *= clampf(c.health.manipulation, 0.0, 1.0)
	p += sim.perks.mod(c, "hit_chance")  # region perks
	return clampf(p, float(cfg["hit_min"]), float(cfg["hit_max"]))


func enemy_by_id(id: int) -> Enemy:
	for e in sim.threats.enemies:
		if e.id == id and not e.leaving:
			return e
	return null


## Tries one attack on `e`. Returns true if an attack was made (hit or miss).
func try_attack(c: Colonist, e: Enemy) -> bool:
	if sim.tick < c.combat.next_attack_tick:
		return false
	var w := weapon_def(c)
	var dist := Vector2(c.cell).distance_to(Vector2(e.cell))
	if dist > float(w["range"]):
		return false
	if str(w["kind"]) == "ranged" and not sim.ammo.rifle_try_fire(c):  # region ammo
		return false
	c.combat.next_attack_tick = sim.tick + maxi(1, roundi(float(w["cooldown_ticks"]) / maxf(0.1, 1.0 + sim.perks.mod(c, "attack_speed"))))  # region perks
	var skill := str(w["skill"])
	if str(w["kind"]) == "ranged":
		sim.threats.shots.append([Vector2(c.cell), e.visual_pos(), sim.tick])
	# region perks
	var dmg := float(w["damage"])
	if str(w["kind"]) == "melee":
		dmg *= 1.0 + sim.perks.mod(c, "melee_damage")
	var aimed := sim.perks.consume_flag(c, "aimed_shot")
	if aimed:
		dmg *= 1.5
	# endregion
	# region C2
	var vm := sim.abilities.take_volley(c.id)
	var volley := vm != 1.0
	dmg *= vm
	# endregion
	if aimed or volley or sim.rng.randf() < hit_chance(c, w, dist):
		sim.threats.damage_enemy(e, dmg)
	if c.skills.add_xp(sim.defs, skill, float(cfg["xp_per_attack"])):
		sim.bus.skill_leveled.emit(c.id, skill, c.skills.level(skill))
	return true


func is_low_hp(c: Colonist) -> bool:
	return c.hp < c.max_hp * float(cfg["flee_hp_fraction"])


# --- Commands (called through Simulation) -----------------------------------------

func set_drafted(c: Colonist, on: bool) -> bool:
	if c == null or not c.alive:
		return false
	if c.combat.drafted == on:
		return true
	c.combat.drafted = on
	c.combat.clear_orders()
	c.hidden = false
	if on:
		if c.carry_count > 0:
			sim.items.drop(c.cell, c.carry_item, c.carry_count, c.carry_quality)
			c.carry_item = ""
			c.carry_count = 0
		sim.jobs.request_override(c, DraftJob.new())
	else:
		sim.jobs.end_job(c, Job.Status.FAILED, false)
		c.clear_path()
	sim.bus.colonist_drafted.emit(c.id, on)
	return true


func order_move(c: Colonist, cell: Vector2i) -> bool:
	if c == null or not c.alive or not c.combat.drafted:
		return false
	if not sim.map.in_bounds(cell) or not sim.map.is_passable(cell) or not sim.pathfinder.reachable(c.cell, cell):
		return false
	c.combat.target_id = -1
	c.combat.order_cell = cell
	return true


func order_attack(c: Colonist, enemy_id: int) -> bool:
	if c == null or not c.alive or not c.combat.drafted or enemy_by_id(enemy_id) == null:
		return false
	c.combat.order_cell = Vector2i(-1, -1)
	c.combat.target_id = enemy_id
	return true


# --- JobSystem hook ---------------------------------------------------------------------

## Called first thing in JobSystem.tick_colonist. Returns true if combat
## handled this colonist's tick (drafted, fighting back, or staying hidden).
func tick_colonist(c: Colonist) -> bool:
	if c.combat == null:
		return false
	if c.combat.drafted:
		if c.job == null or c.job.type != "draft":
			c.hidden = false
			sim.jobs.request_override(c, DraftJob.new())
		_run(c)
		return true
	if c.hidden:
		# Stay in the shelter while hurt and creatures are around.
		return is_low_hp(c) and not sim.threats.enemies_in_range(Vector2(c.cell), float(cfg["flee_watch_range"])).is_empty()
	var reach := sim.threats.enemies_in_range(Vector2(c.cell), float(cfg["fight_back_range"]))
	if reach.is_empty():
		if c.job != null and c.job.type == "fight":
			sim.jobs.end_job(c, Job.Status.DONE, false)
		if c.job != null and c.job.type == "retreat":
			_run(c)
			return true
		return false
	if is_low_hp(c):
		if c.job == null or c.job.type != "retreat":
			var shelter := sim.buildings.find_shelter(c.cell) if sim.buildings else null
			if shelter == null:
				return false
			sim.jobs.request_override(c, RetreatJob.new(shelter.id))
		_run(c)
		return true
	if c.job == null or c.job.type != "fight":
		sim.jobs.request_override(c, FightJob.new())
	_run(c)
	return true


func _run(c: Colonist) -> void:
	var st := c.job.tick(c, sim)
	if st != Job.Status.RUNNING:
		sim.jobs.end_job(c, st, false)
