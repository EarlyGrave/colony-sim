class_name JobSystem
extends RefCounted
## Chooses jobs for idle colonists (RimWorld-style "work givers") and keeps
## reservations so two colonists never grab the same target.
##
## Priorities come from data/jobs.json. Within one priority the nearest
## candidate wins. Fleeing overrides everything while the alarm is on.

const NO_CELL := Vector2i(-1, -1)

var sim: Simulation
## reservation key -> colonist id
var reserved: Dictionary = {}
## Provider methods sorted by priority (highest first).
var _providers: Array[Callable] = []
var _idle_retry: int


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	_idle_retry = int(sim.defs.balance["colonist"]["idle_retry_ticks"])
	var table := {
		"repair": _find_repair,
		"operate": _find_operate,
		"haul": _find_haul,
		"mine": _find_mine,
	}
	var types := table.keys()
	types.sort_custom(func(a: String, b: String) -> bool:
		return sim.defs.job_priority(a) > sim.defs.job_priority(b))
	for t in types:
		_providers.append(table[t])


func tick_colonist(c: Colonist) -> void:
	if _engineer_on_duty(c):
		_tick_engineer(c)
		return
	if sim.alarm and not c.hidden and (c.job == null or c.job.type != "flee") and not c.is_unreachable("flee", sim.tick):
		var shelter := sim.buildings.find_shelter(c.cell) if sim.buildings else null
		if shelter != null:
			end_job(c, Job.Status.FAILED, false)
			_start(c, FleeJob.new(shelter.id))
	if c.hidden:
		if sim.alarm:
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
		sim.items.drop(c.cell, c.carry_item, c.carry_count)
		c.carry_item = ""
		c.carry_count = 0
	for p in _providers:
		var job: Job = p.call(c)
		if job != null:
			return job
	return null


# --- Providers ----------------------------------------------------------------

func _deliver_carried(c: Colonist) -> Job:
	var b := _building_needing(c.carry_item, c.cell, c)
	if b != null:
		return _haul(HaulJob.Src.CARRIED, NO_CELL, -1, HaulJob.Dst.BUILDING_IN, NO_CELL, b.id, c.carry_item, c.carry_count)
	var dst := _storage_for(c.carry_item, c.cell, c)
	if dst.x < 0:
		return null
	return _haul(HaulJob.Src.CARRIED, NO_CELL, -1, HaulJob.Dst.CELL, dst, -1, c.carry_item, c.carry_count)


func _find_haul(c: Colonist) -> Job:
	var best: Job = null
	var best_d := 1 << 30
	# 1) Building outputs -> storage.
	if sim.buildings:
		for b: Building in sim.buildings.list:
			var key := "bout:%d" % b.id
			if b.output.is_empty() or not _free(c, key) or not sim.pathfinder.reachable(c.cell, b.cell):
				continue
			var d := c.cell.distance_squared_to(b.cell)
			if d >= best_d:
				continue
			for item: String in b.output:
				var dst := _storage_for(item, b.cell, c)
				if dst.x >= 0:
					best = _haul(HaulJob.Src.BUILDING_OUT, NO_CELL, b.id, HaulJob.Dst.CELL, dst, -1, item, int(b.output[item]))
					best.reservations.append(key)
					best.fail_key = key
					best_d = d
					break
	# 2) Feed buildings that need input; 3) loose stacks -> storage.
	for cell: Vector2i in sim.items.stacks:
		var key := "cell:%d,%d" % [cell.x, cell.y]
		var d := c.cell.distance_squared_to(cell)
		if d >= best_d or not _free(c, key):
			continue
		var item := sim.items.item_at(cell)
		var count := sim.items.count_at(cell)
		if not sim.pathfinder.reachable(c.cell, cell):
			continue
		var job: Job = null
		var b := _building_needing(item, cell, c)
		if b != null:
			job = _haul(HaulJob.Src.GROUND, cell, -1, HaulJob.Dst.BUILDING_IN, NO_CELL, b.id, item, mini(count, b.input_space(item)))
		elif not sim.items.is_stored(cell):
			var dst := _storage_for(item, cell, c)
			if dst.x >= 0:
				job = _haul(HaulJob.Src.GROUND, cell, -1, HaulJob.Dst.CELL, dst, -1, item, count)
		if job != null:
			job.reservations.append(key)
			job.fail_key = key
			best = job
			best_d = d
	return best


func _find_mine(c: Colonist) -> Job:
	var best := NO_CELL
	var best_d := 1 << 30
	var m := sim.map
	for i in m.mine_designated.size():
		if m.mine_designated[i] == 0:
			continue
		var cell := Vector2i(i % m.width, i / m.width)
		var key := "dep:%d,%d" % [cell.x, cell.y]
		var d := c.cell.distance_squared_to(cell)
		if d >= best_d or not _free(c, key):
			continue
		if sim.pathfinder.best_adjacent(c.cell, cell).x < 0:
			continue
		best = cell
		best_d = d
	if best.x < 0:
		return null
	var j := MineJob.new(best)
	var k := "dep:%d,%d" % [best.x, best.y]
	j.reservations.append(k)
	j.fail_key = k
	return j


func _find_operate(c: Colonist) -> Job:
	if sim.buildings == null:
		return null
	var best: Building = null
	var best_d := 1 << 30
	for b: Building in sim.buildings.list:
		var key := "op:%d" % b.id
		if not b.can_run_recipe() or not _free(c, key) or not sim.pathfinder.reachable(c.cell, b.cell):
			continue
		var d := c.cell.distance_squared_to(b.cell)
		if d < best_d:
			best = b
			best_d = d
	if best == null:
		return null
	var j := OperateJob.new(best.id)
	j.reservations.append("op:%d" % best.id)
	j.fail_key = "op:%d" % best.id
	return j


func _find_repair(c: Colonist) -> Job:
	if sim.buildings == null:
		return null
	var best: Building = null
	var best_d := 1 << 30
	for b: Building in sim.buildings.list:
		var key := "rep:%d" % b.id
		if not b.needs_repair(sim) or not _free(c, key) or not sim.pathfinder.reachable(c.cell, b.cell):
			continue
		var d := c.cell.distance_squared_to(b.cell)
		if d < best_d:
			best = b
			best_d = d
	if best == null:
		return null
	var j := RepairJob.new(best.id)
	j.reservations.append("rep:%d" % best.id)
	j.fail_key = "rep:%d" % best.id
	return j


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


func _storage_for(item: String, near: Vector2i, c: Colonist) -> Vector2i:
	return sim.items.find_storage_cell(item, near, func(cell: Vector2i) -> bool:
		return not _free(c, "dst:%d,%d" % [cell.x, cell.y]))


## Nearest working building whose input wants `item`, not already being fed.
func _building_needing(item: String, near: Vector2i, c: Colonist) -> Building:
	if sim.buildings == null:
		return null
	var best: Building = null
	var best_d := 1 << 30
	for b: Building in sim.buildings.list:
		if b.input_space(item) <= 0 or not _free(c, "bin:%d" % b.id):
			continue
		if not sim.pathfinder.reachable(near, b.cell):
			continue
		var d := near.distance_squared_to(b.cell)
		if d < best_d:
			best = b
			best_d = d
	return best
