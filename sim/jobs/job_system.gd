class_name JobSystem
extends RefCounted
## Chooses jobs for idle colonists (RimWorld-style "work givers") and keeps
## reservations so two colonists never grab the same target.
##
## Per-colonist work priorities (data/work.json, Skills.priorities); within one
## priority givers run in work.json order and the nearest candidate wins. Fleeing overrides everything while the alarm is on.

const NO_CELL := Vector2i(-1, -1)

var sim: Simulation
## reservation key -> colonist id
var reserved: Dictionary = {}
## giver id -> WorkGiver (see giver_registry.gd)
var givers: Dictionary = {}
var _idle_retry: int


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	_idle_retry = int(sim.defs.balance["colonist"]["idle_retry_ticks"])
	givers = GiverRegistry.create_all(sim)


func tick_colonist(c: Colonist) -> void:
	if c.health != null and (c.health.downed or not sim.health.can_act(c)):
		return  # region health: downed / hurt colonists lose the tick
	# region combat
	if sim.combat.tick_colonist(c):
		return
	# endregion
	if _engineer_on_duty(c):
		_tick_engineer(c)
		return
	if sim.alarm and sim.threats.in_lockdown(c.cell) and not c.hidden and sim.traits.mod(c, "flee_threshold") > -1.0 and (c.job == null or c.job.type != "flee") and not c.is_unreachable("flee", sim.tick):  # region LD + PW2 (Cold Blood never flees)
		var shelter := sim.buildings.find_shelter(c.cell) if sim.buildings else null
		# region B3: rule "evacuate_low_hq": a badly hurt shelter would collapse on its occupants, so nobody hides in it
		if shelter != null and sim.milestones.b3_on() and sim.is_rule_on("evacuate_low_hq") and _b3_hurt(shelter):
			shelter = null
		# endregion
		if shelter != null:
			end_job(c, Job.Status.FAILED, false)
			_start(c, FleeJob.new(shelter.id))
	if c.hidden:
		if sim.alarm and sim.threats.in_lockdown(c.cell):  # region LD
			# region B3: evacuate a hurt shelter
			if sim.milestones.b3_on() and sim.is_rule_on("evacuate_low_hq"):
				for hb in sim.buildings.list:
					if _b3_hurt(hb) and hb.contains(c.cell):
						c.hidden = false
						return
			# endregion
			return
		c.hidden = false
	if c.is_sick(sim.tick) and (c.job == null or c.job.type != "flee"):
		end_job(c, Job.Status.FAILED, false)
		return
	if c.job == null:
		if c.idle_until > sim.tick:
			return
		var j := assign(c)
		if j == null:
			c.idle_until = sim.tick + _idle_retry
			return
		_start(c, j)
	var before := c.cell
	var st := c.job.tick(c, sim)
	c.stuck_ticks = 0 if c.cell != before or c.path.is_empty() else c.stuck_ticks + 1
	if st != Job.Status.RUNNING:
		end_job(c, st)


# --- Rule "raid_engineer" ---------------------------------------------------------

func _engineer_on_duty(c: Colonist) -> bool:
	return sim.alarm and c.engineer and sim.is_rule_on("raid_engineer") and not c.is_sick(sim.tick)


## During a raid the engineer repairs damaged turrets and hides otherwise.
func _tick_engineer(c: Colonist) -> void:
	if c.job == null or c.job.type != "repair":
		var t := _turret_needing_urgent_repair(c)
		if t != null:
			end_job(c, Job.Status.FAILED, false)
			c.hidden = false
			var j := RepairJob.new(t.id)
			j.reservations.append("rep:%d" % t.id)
			j.fail_key = "rep:%d" % t.id
			_start(c, j)
		elif c.hidden:
			return
		elif c.job == null or c.job.type != "flee":
			var shelter := sim.buildings.find_shelter(c.cell)
			end_job(c, Job.Status.FAILED, false)
			if shelter == null:
				return
			_start(c, FleeJob.new(shelter.id))
	var st := c.job.tick(c, sim)
	if st != Job.Status.RUNNING:
		end_job(c, st)


func _turret_needing_urgent_repair(c: Colonist) -> Building:
	var frac := float(sim.defs.rules["raid_engineer"]["turret_hp_fraction"])
	var reach_from := c.cell
	var best: Building = null
	var best_d := 1 << 30
	for b in sim.buildings.list:
		if not b.def.has("turret"):
			continue
		var urgent := b.broken or b.hp < b.max_hp * frac \
			or b.condition < float(sim.defs.balance["repair"]["threshold"]) * 100.0
		var key := "rep:%d" % b.id
		if not urgent or not _free(c, key) or not sim.pathfinder.reachable(reach_from, b.cell):
			continue
		var d := reach_from.distance_squared_to(b.cell)
		if d < best_d:
			best = b
			best_d = d
	return best


func _start(c: Colonist, j: Job) -> void:
	for k in j.reservations:
		reserved[k] = c.id
	c.clear_path()  # a stale path from the previous job is not progress
	c.job = j


## Ends the colonist's current job and frees its reservations.
## `mark_unreachable`: on failure, avoid that target for a while.
func end_job(c: Colonist, status: int, mark_unreachable := true) -> void:
	var j := c.job
	if j == null:
		return
	for k in j.reservations:
		if reserved.get(k, -1) == c.id:
			reserved.erase(k)
	j.on_end(c, sim)
	c.clear_path()
	c.job = null
	if status == Job.Status.FAILED and mark_unreachable and j.fail_key != "":
		c.unreachable[j.fail_key] = sim.tick + int(sim.defs.balance["colonist"]["unreachable_cooldown_ticks"])
		c.idle_until = sim.tick + _idle_retry


func is_reserved(key: String) -> bool:
	return reserved.has(key)


func _free(c: Colonist, key: String) -> bool:
	return not reserved.has(key) and not c.is_unreachable(key, sim.tick)


## Picks the best job for an idle colonist, or null.
func assign(c: Colonist) -> Job:
	if c.carry_count > 0:
		var j := _deliver_carried(c)
		if j != null:
			return j
		# Nowhere to put it: drop it here and carry on.
		sim.items.drop(c.cell, c.carry_item, c.carry_count, c.carry_quality)
		c.carry_item = ""
		c.carry_count = 0
	for t in work_order(c):
		for gid: String in sim.defs.work["types"][t]["givers"]:
			var g: WorkGiver = givers.get(gid)
			if g == null:
				continue
			var job: Job = g.find(c)
			if job != null:
				return job
	return null


## Enabled work types for `c`: priority 1..max first, then data/work.json order.
func work_order(c: Colonist) -> Array[String]:
	var out: Array[String] = []
	for p in range(1, int(sim.defs.work["max_priority"]) + 1):
		for t: String in sim.defs.work["types"]:
			if c.skills.priority(t) == p:
				out.append(t)
	return out


## Call once per working tick of `work_type`: grants skill xp and returns the
## work-speed multiplier (1.0 for unskilled work).
func work_tick(c: Colonist, work_type: String) -> float:
	var skill: String = sim.defs.work["types"][work_type]["skill"]
	var generic := maxf(0.0, 1.0 + sim.perks.mod(c, "work_speed"))  # region perks
	if skill == "":
		return generic
	var mult := c.skills.speed_mult(sim.defs, skill)
	mult *= float(c.bio.get("work_speed", 1.0))  # region arrivals
	sim.progression.award(c, skill, float(sim.defs.skills["xp_per_work_tick"]), "work", false)  # region progression
	return mult * generic


## Hook for needs / draft / downed: interrupts the current job and runs `job`.
func request_override(c: Colonist, job: Job) -> void:
	end_job(c, Job.Status.FAILED, false)
	_start(c, job)


# --- Providers ----------------------------------------------------------------

func _deliver_carried(c: Colonist) -> Job:
	var b := _building_needing(c.carry_item, c.cell, c)
	if b != null:
		return _haul(HaulJob.Src.CARRIED, NO_CELL, -1, HaulJob.Dst.BUILDING_IN, NO_CELL, b.id, c.carry_item, c.carry_count)
	var dst := _storage_for(c.carry_item, c.cell, c, c.carry_quality)
	if dst.x < 0:
		return null
	return _haul(HaulJob.Src.CARRIED, NO_CELL, -1, HaulJob.Dst.CELL, dst, -1, c.carry_item, c.carry_count)


# --- Helpers ------------------------------------------------------------------

func _haul(src: int, src_cell: Vector2i, src_b: int, dst: int, dst_cell: Vector2i, dst_b: int, item: String, amount: int) -> HaulJob:
	var j := HaulJob.new()
	j.src = src
	j.src_cell = src_cell
	j.src_building = src_b
	j.dst = dst
	j.dst_cell = dst_cell
	j.dst_building = dst_b
	j.item = item
	j.amount = amount
	if dst == HaulJob.Dst.CELL:
		j.reservations.append("dst:%d,%d" % [dst_cell.x, dst_cell.y])
	else:
		j.reservations.append("bin:%d" % dst_b)
	return j


func _storage_for(item: String, near: Vector2i, c: Colonist, q := "") -> Vector2i:
	return sim.items.find_storage_cell(item, near, func(cell: Vector2i) -> bool:
		return not _free(c, "dst:%d,%d" % [cell.x, cell.y]), q)


## "Ore reserve" rule: how much of `want` may leave `cell` for a building input.
## Stored ore may only be taken down to the reserve; loose ore is kept for
## storage until the reserve is filled.
func _reserve_limited(item: String, cell: Vector2i, want: int) -> int:
	if item != "essence_ore" or not sim.is_rule_on("ore_reserve"):
		return want
	var surplus := sim.items.count_stored(item) - int(sim.defs.rules["ore_reserve"]["amount"])
	if not sim.items.is_stored(cell):
		return want if surplus >= 0 else 0
	return clampi(surplus, 0, want)


## Nearest working building whose input wants `item`, not already being fed.
func _building_needing(item: String, near: Vector2i, c: Colonist, skip_id := -1) -> Building:
	if sim.buildings == null:
		return null
	var best: Building = null
	var best_d := 1 << 30
	for b: Building in sim.buildings.list:
		if b.id == skip_id or b.input_space(item) <= 0 or not _free(c, "bin:%d" % b.id):
			continue
		if not sim.pathfinder.reachable(near, b.cell):
			continue
		var d := near.distance_squared_to(b.cell)
		if d < best_d:
			best = b
			best_d = d
	return best


# region B3
func _b3_hurt(b: Building) -> bool:
	return b.def.get("shelter", false) and b.hp < b.max_hp * float(sim.defs.rules["evacuate_low_hq"]["hq_hp_fraction"])
# endregion
