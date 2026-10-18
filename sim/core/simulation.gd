class_name Simulation
extends RefCounted
## Root of the simulation. Owns the RNG, the tick counter and all systems.
## No rendering, no scene tree: runs headless in tests.
##
## The view changes the world only through the command methods below.

const TICKS_PER_SECOND := 10

var seed_value: int
var rng := RandomNumberGenerator.new()
var bus: Object
var defs: Defs
var tick := 0
var ticks_per_day: int
## Colonists hide in the shelter while the alarm is on.
var alarm := false
## Player rules: rule id -> enabled (defaults from data/rules.json).
var rules: Dictionary = {}
## Non-empty once the game is lost ("hq_destroyed", "colonists_dead", "planet_dead").
var game_over_reason := ""

var ledger := Ledger.new()
var map: MapGrid
var pathfinder: Pathfinder
var items: ItemSystem
var colonists: ColonistSystem
var jobs: JobSystem
var buildings: BuildingSystem
var contamination: ContaminationSystem
var threats: ThreatSystem
var storyteller: Storyteller
var crises: CrisisSystem  # region crises
# region health
var health: HealthSystem
# endregion
# region mood
var mood: MoodSystem
# endregion
# region debt
var debt: DebtSystem
# endregion

# region save-load
## SAVE/LOAD CONTRACT: every player command method MUST call
## `_record("method_name", [args...])` as its FIRST line (args: ints, bools,
## strings, Vector2i only). Saves are command logs replayed on a fresh sim
## (see sim/core/save_game.gd), so an unrecorded command is lost on load.
var command_log: Array = []  # [tick, name, args]
var replaying := false
# region crafting
var crafting: BillSystem
# region A1c
var logistics: LogisticsSystem
# endregion
var storage: StorageSettings
# region combat
var combat: CombatSystem
# region needs
var clock: WorldClock
var needs: NeedsSystem
var farming: FarmingSystem
# region contracts
var contracts: ContractSystem
# region progression
var progression: ProgressionSystem
# region idle-work
var idle_work: IdleWorkSystem
var mutation: MutationSystem  # region mutation
var ecology: EcologySystem  # region T5
var milestones: MilestoneSystem  # region R2b
# endregion
# region perks
var perks: PerkSystem
var quality: QualitySystem  # region quality
var ammo: AmmoSystem  # region ammo
# endregion
# endregion

var research: ResearchSystem  # region R2a
# region O1
## Warden's Orientation; null unless opts.tutorial is true.
var tutorial: TutorialSystem
# region C5
## Alarm militia (idle inmates rally to squad banners); no-op without squads.
var militia: Militia
# endregion
## True while step() runs (lets the tutorial tell player alarm toggles from the wave's own).
var in_step := false
# endregion
var chips: ChipSystem  # region R4b
var squads: SquadSystem  # region C1
var abilities: Abilities  # region C2
## True for buildings whose recipes produce waste (refinery, smelter): refining class.
func is_refining_building(def_id: String) -> bool:
	var d: Dictionary = defs.buildings.get(def_id, {})
	var own: String = str(d.get("recipe", ""))
	if own != "" and defs.recipes.has(own) and (defs.recipes[own]["outputs"] as Dictionary).has("waste"):
		return true
	for rid: String in defs.recipes:
		var r: Dictionary = defs.recipes[rid]
		if (r["outputs"] as Dictionary).has("waste") and (r.get("station", []) as Array).has(def_id):
			return true
	return false


func _arg_text(v: Variant) -> String:
	return v if v is String else JSON.stringify(v, "", true)


func _arg_array(v: Variant) -> Array:
	if v is String:
		var r: Variant = JSON.parse_string(v)
		return r if r is Array else []
	return v if v is Array else []


func _arg_dict(v: Variant) -> Dictionary:
	if v is String:
		var r: Variant = JSON.parse_string(v)
		return r if r is Dictionary else {}
	return v if v is Dictionary else {}


## Player/campaign command: sends colonists and stored supplies away on an expedition.
## Atomic: unknown/dead/duplicate ids or supplies not in storage change nothing.
## Args are logged as JSON text (the save log holds scalars only). Returns {"ok": bool, "crew": [snapshot], "supplies": {item: n}}; snapshot =
## {name, engineer, skills{id: level}, passions{id: int}}.
func dispatch_party(ids_in: Variant, supplies_in: Variant) -> Dictionary:
	_record("dispatch_party", [_arg_text(ids_in), _arg_text(supplies_in)])  # save-load
	var ids: Array = _arg_array(ids_in)
	var supplies: Dictionary = _arg_dict(supplies_in)
	var fail := {"ok": false, "crew": [], "supplies": {}}
	if ids.is_empty() and supplies.is_empty():
		return fail  # empty ids + supplies = sling crate: removes the stacks only
	var seen := {}
	var crew_c: Array[Colonist] = []
	for id: Variant in ids:
		var c := colonists.get_by_id(int(id))
		if c == null or not c.alive or seen.has(int(id)):
			return fail
		seen[int(id)] = true
		crew_c.append(c)
	var keys: Array = supplies.keys()
	keys.sort()
	for k: String in keys:
		if int(supplies[k]) < 0 or items.count_stored(k) < int(supplies[k]):
			return fail
	for k: String in keys:
		var n := int(supplies[k])
		if n > 0:
			items.consume_stored(k, n, map_center())
			ledger.record_consumed(k, n, "expedition")
	var crew: Array = []
	for c in crew_c:
		crew.append({"name": c.display_name, "engineer": c.engineer,
				"skills": c.skills.levels.duplicate(), "passions": c.skills.passions.duplicate()})
		jobs.end_job(c, Job.Status.FAILED)
		if c.carry_count > 0:
			items.drop(c.cell, c.carry_item, c.carry_count, c.carry_quality)
			c.carry_item = ""
			c.carry_count = 0
		colonists.list.erase(c)
	return {"ok": true, "crew": crew, "supplies": supplies.duplicate()}


func _spawn_from_snapshot(cell: Vector2i, snap: Dictionary) -> Colonist:
	var c := colonists.spawn(cell)  # fixed rng draws per member
	c.display_name = str(snap.get("name", c.display_name))
	c.engineer = bool(snap.get("engineer", false))
	for sk: String in snap.get("skills", {}):
		c.skills.levels[sk] = int(snap["skills"][sk])
	for sk: String in snap.get("passions", {}):
		c.skills.passions[sk] = int(snap["passions"][sk])
	c.skills.mark_joined()
	if c.engineer:
		c.combat.weapon = str(defs.weapons["combat"]["engineer_weapon"])
	return c


## Campaign command: a recalled party walks back in next to the HQ (snapshots as dispatch_party gave them).
func receive_party(crew_in: Variant) -> int:
	_record("receive_party", [_arg_text(crew_in)])  # save-load
	var crew: Array = _arg_array(crew_in)
	var center := map_center()
	for snap: Variant in crew:
		var at := center
		for _try in 20:
			var cand := center + Vector2i(rng.randi_range(-3, 3), rng.randi_range(-3, 3))
			if cell_free_for_items(cand):
				at = cand
				break
		_spawn_from_snapshot(at, snap as Dictionary)
	return crew.size()


## Campaign command: spawns a crate of `items` within `radius` of the HQ (sim.rng picks the
## cell). Returns the number of items that were lost for lack of room.
func receive_cargo(cargo_in: Variant, radius: int) -> int:
	_record("receive_cargo", [_arg_text(cargo_in), radius])  # save-load
	var cargo: Dictionary = _arg_dict(cargo_in)
	var center := map_center()
	var at := center
	for _try in 20:
		var cand := center + Vector2i(rng.randi_range(-radius, radius), rng.randi_range(-radius, radius))
		if cell_free_for_items(cand):
			at = cand
			break
	var lost := 0
	var keys: Array = cargo.keys()
	keys.sort()
	for k: String in keys:
		var n := int(cargo[k])
		if n <= 0:
			continue
		ledger.record_produced(k, n, "cargo")
		lost += items.drop(at, k, n)
	return lost
# endregion


# region T4
var opts: Dictionary = {}  # region meta: deterministic start options
var run_summary: Dictionary = {}  # region meta
var _connections: Array = []  # [signal, callable] pairs made on the bus


func _init(p_seed: int, p_bus: Object, p_defs: Defs = null, p_opts: Dictionary = {}) -> void:
	opts = p_opts.duplicate(true)  # region meta
	seed_value = p_seed
	rng.seed = p_seed
	bus = p_bus
	defs = p_defs if p_defs != null else Defs.get_default()
	ticks_per_day = int(defs.balance["ticks_per_day"])
	for id: String in defs.rules:
		rules[id] = defs.rules[id]["default"] if defs.rules[id].has("modes") else bool(defs.rules[id]["default"])  # region T3


## Generates the map and places the starting colony.
func start_new_game() -> void:
	var cfg: Dictionary = defs.balance["map"]
	# region P1: start opts map_w/map_h override the balance size; cluster counts scale with area
	var mw := int(opts.get("map_w", cfg["width"]))
	var mh := int(opts.get("map_h", cfg["height"]))
	if mw != int(cfg["width"]) or mh != int(cfg["height"]):
		cfg = cfg.duplicate(true)
		var k := float(mw * mh) / float(int(cfg["width"]) * int(cfg["height"]))
		cfg["rock_clusters"] = maxi(1, roundi(float(cfg["rock_clusters"]) * k))
		cfg["deposit_clusters"] = maxi(1, roundi(float(cfg["deposit_clusters"]) * k))
	map = MapGrid.new(mw, mh, bus)
	# endregion
	MapGenerator.generate(map, rng, cfg)
	_init_systems()
	if opts.has("crew"):  # region R4b
		_place_crew_colony()
	else:
		_place_starting_colony()
	ecology.generate()  # region T5
	StartOpts.apply(self, opts)  # region meta


## Empty all-ground map, no colony, for test scenarios.
func start_empty(w: int, h: int) -> void:
	map = MapGrid.new(w, h, bus)
	_init_systems()


func _init_systems() -> void:
	pathfinder = Pathfinder.new(map)
	listen(bus.tile_changed, pathfinder.refresh_cell)
	items = ItemSystem.new(self)
	colonists = ColonistSystem.new(self)
	buildings = BuildingSystem.new(self)
	jobs = JobSystem.new(self)
	contamination = ContaminationSystem.new(self)
	threats = ThreatSystem.new(self)
	storyteller = Storyteller.new(self)
	crises = CrisisSystem.new(self)  # region crises
	# region health
	health = HealthSystem.new(self)
	# endregion
	# region mood
	mood = MoodSystem.new(self)
	# region crafting
	storage = StorageSettings.new(self)
	crafting = BillSystem.new(self)
	logistics = LogisticsSystem.new(self)  # region A1c
	# region combat
	combat = CombatSystem.new(self)
	# region needs
	clock = WorldClock.new(self)
	needs = NeedsSystem.new(self)
	farming = FarmingSystem.new(self)
	# endregion
	perks = PerkSystem.new(self)  # region perks
	contracts = ContractSystem.new(self)  # region contracts
	quality = QualitySystem.new(self)  # region quality
	progression = ProgressionSystem.new(self)  # region progression
	ammo = AmmoSystem.new(self)  # region ammo
	debt = DebtSystem.new(self)  # region debt
	idle_work = IdleWorkSystem.new(self)  # region idle-work
	mutation = MutationSystem.new(self)  # region mutation
	ecology = EcologySystem.new(self)  # region T5
	research = ResearchSystem.new(self)  # region R2a
	milestones = MilestoneSystem.new(self)  # region R2b
	chips = ChipSystem.new(self)  # region T4
	squads = SquadSystem.new(self)  # region C1
	abilities = Abilities.new(self)  # region C2
	if bool(opts.get("tutorial", false)):  # region O1
		tutorial = TutorialSystem.new(self)
	militia = Militia.new(self)  # region C5


func _place_starting_colony() -> void:
	var col_cfg: Dictionary = defs.balance["colony"]
	var center := map_center()
	buildings.place("hq", center - Vector2i(1, 1), false)
	var spots: Array[Vector2i] = [Vector2i(-2, 1), Vector2i(1, 2), Vector2i(2, -1), Vector2i(-2, -2), Vector2i(0, 3)]
	for i in int(col_cfg["colonists"]):
		var c := colonists.spawn(center + spots[i % spots.size()])
		c.engineer = i < int(col_cfg["engineers"])
		# region combat
		if c.engineer:
			c.combat.weapon = str(defs.weapons["combat"]["engineer_weapon"])
		# endregion
	# Starting stockpile next to the capsule, with the supplies on it.
	var sz: Array = col_cfg["start_stockpile_size"]
	var origin := center + Vector2i(3, -1)
	for y in int(sz[1]):
		for x in int(sz[0]):
			set_zone(origin + Vector2i(x, y), "stockpile")
	var start_items: Dictionary = col_cfg["start_items"]
	for item: String in start_items:
		var n := int(start_items[item])
		ledger.record_produced(item, n, "start")
		items.drop(origin, item, n)


# region R4b
## Outpost start: HQ + stockpile; crew snapshots replace the random colonists, opts.supplies the start items.
func _place_crew_colony() -> void:
	var col_cfg: Dictionary = defs.balance["colony"]
	var center := map_center()
	buildings.place("hq", center - Vector2i(1, 1), false)
	var spots: Array[Vector2i] = [Vector2i(-2, 1), Vector2i(1, 2), Vector2i(2, -1), Vector2i(-2, -2), Vector2i(0, 3)]
	var crew: Array = opts["crew"]
	for i in crew.size():
		var snap: Dictionary = crew[i]
		_spawn_from_snapshot(center + spots[i % spots.size()], snap)
	var sz: Array = col_cfg["start_stockpile_size"]
	var origin := center + Vector2i(3, -1)
	for y in int(sz[1]):
		for x in int(sz[0]):
			set_zone(origin + Vector2i(x, y), "stockpile")
	var sup: Dictionary = opts.get("supplies", {})
	var keys: Array = sup.keys()
	keys.sort()
	for item: String in keys:
		var n := int(sup[item])
		if n > 0:
			ledger.record_produced(item, n, "start")
			items.drop(origin, item, n)
# endregion


# --- Tick ---------------------------------------------------------------------

## Advances the simulation by one fixed tick.
## Perf profiling (tools/perf_bench.gd, tests/test_perf_budget.gd). Off by default: one bool check per system.
## `profile` maps system name -> accumulated microseconds; the caller resets it.
var profiling: bool = false
var profile: Dictionary = {}
var _lap_t: int = 0


func _lap(key: String) -> void:
	var now := Time.get_ticks_usec()
	profile[key] = int(profile.get(key, 0)) + now - _lap_t
	_lap_t = now


func step() -> void:
	if game_over_reason != "":
		return
	tick += 1
	if profiling:
		_lap_t = Time.get_ticks_usec()
	in_step = true  # region O1
	crafting.tick()  # region crafting
	if profiling:
		_lap("crafting")
	needs.tick()  # region needs
	if profiling:
		_lap("needs")
	farming.tick()  # region needs
	if profiling:
		_lap("farming")
	colonists.tick()
	if profiling:
		_lap("colonists")
	logistics.tick()  # region A1c
	if profiling:
		_lap("logistics")
	buildings.tick_machines()  # region A2a
	if profiling:
		_lap("machines")
	chips.tick()  # region T4
	if profiling:
		_lap("chips")
	perks.tick()  # region perks
	if profiling:
		_lap("perks")
	health.tick()  # region health
	if profiling:
		_lap("health")
	debt.tick()  # region debt
	if profiling:
		_lap("debt")
	mood.tick()  # region mood
	if profiling:
		_lap("mood")
	abilities.tick()  # region C2
	if profiling:
		_lap("abilities")
	threats.tick()
	if profiling:
		_lap("threats")
	squads.tick()  # region C1
	if profiling:
		_lap("squads")
	contamination.tick()
	if profiling:
		_lap("contamination")
	mutation.tick()  # region mutation
	if profiling:
		_lap("mutation")
	ecology.tick()  # region T5
	if profiling:
		_lap("ecology")
	crises.tick()  # region crises
	if profiling:
		_lap("crises")
	storyteller.tick()
	if profiling:
		_lap("storyteller")
	if tutorial != null:  # region O1
		tutorial.tick()
	militia.tick()  # region C5
	if profiling:
		_lap("militia")
	in_step = false  # region O1
	if colonists.alive_count() == 0 and not colonists.list.is_empty():
		end_game("colonists_dead")
	if tick % ticks_per_day == 0:
		bus.day_started.emit(day())
	bus.tick_advanced.emit(tick)


func run_ticks(n: int) -> void:
	for i in n:
		step()


func end_game(reason: String) -> void:
	if game_over_reason != "":
		return
	game_over_reason = reason
	run_summary = Legacy.summarize(self, reason)  # region meta
	run_summary["site"] = int(opts.get("site", 0))  # region meta
	bus.run_ended.emit(run_summary)  # region meta
	bus.game_over.emit(reason)


func day() -> int:
	return tick / ticks_per_day


func map_center() -> Vector2i:
	return Vector2i(map.width / 2, map.height / 2)


func cell_free_for_items(c: Vector2i) -> bool:
	return map.is_passable(c) and not buildings.occupied(c)


# --- Player commands ------------------------------------------------------------

func designate_mine(c: Vector2i, on: bool) -> void:
	_record("designate_mine", [c, on])  # save-load
	if map.in_bounds(c):
		map.set_mine_designated(c, on)


## zone_id "" clears the zone. Returns false if the cell can't hold a zone.
func set_zone(c: Vector2i, zone_id: String) -> bool:
	_record("set_zone", [c, zone_id])  # save-load
	if not map.in_bounds(c):
		return false
	if zone_id != "" and (not map.is_passable(c) or buildings.occupied(c) or not defs.zones.has(zone_id)):
		return false
	items.set_zone(c, zone_id)
	return true


func can_place_building(def_id: String, c: Vector2i) -> String:
	if not defs.buildings.has(def_id) or not defs.buildings[def_id].get("buildable", false):
		return "Cannot build"
	if bool(opts.get("no_refining", false)) and is_refining_building(def_id):  # region R4b
		return "No refining here"
	return buildings.placement_error(def_id, c, false)  # blueprints need no materials up front


## Player command: plans a building (blueprint). Colonists haul the materials
## and build it. Returns null if it can't be placed.
func place_building(def_id: String, c: Vector2i) -> Blueprint:
	_record("place_building", [def_id, c])  # save-load
	if can_place_building(def_id, c) != "":
		return null
	return buildings.place_blueprint(def_id, c)


## Instant placement paying the cost from storage (tests, scenarios, tools).
func place_instant(def_id: String, c: Vector2i) -> Building:
	if not defs.buildings.has(def_id) or not defs.buildings[def_id].get("buildable", false) \
			or buildings.placement_error(def_id, c) != "":
		return null
	return buildings.place(def_id, c)


## Player command: removes the building at `c` and refunds part of its cost.
func deconstruct(c: Vector2i) -> bool:
	_record("deconstruct", [c])  # save-load
	return buildings.deconstruct(c)


func set_rule(rule_id: String, on: Variant) -> void:
	_record("set_rule", [rule_id, on])  # save-load
	# region T3: mode rules (defs "modes") take a mode string, e.g. turret_target_mode
	if defs.rules.get(rule_id, {}).has("modes"):
		if str(on) in defs.rules[rule_id]["modes"] and rules.get(rule_id) != str(on):
			rules[rule_id] = str(on)
			bus.rule_changed.emit(rule_id, true)
		return
	on = bool(on)
	# endregion
	if not rules.has(rule_id) or rules[rule_id] == on or (on and not research.rule_unlocked(rule_id)):  # region R2a
		return
	rules[rule_id] = on
	bus.rule_changed.emit(rule_id, on)


## Current mode of a mode rule (region T3).
func get_rule_mode(rule_id: String) -> String:
	return str(rules.get(rule_id, ""))


# region T2
## Player command: Mourning Bell burst (x threat for a while, costs essence; shortfall becomes debt).
func trigger_bell(building_id: int) -> bool:
	_record("trigger_bell", [building_id])  # save-load
	return Decoy.trigger_bell(buildings.get_by_id(building_id), self)
# endregion


func is_rule_on(rule_id: String) -> bool:
	return bool(rules.get(rule_id, false))


# region O1
## Orientation commands (view-mirrored, recorded). No-ops unless opts.tutorial.
func tutorial_ack() -> void:
	_record("tutorial_ack", [])
	if tutorial != null:
		tutorial.ack()


func tutorial_skip_step() -> void:
	_record("tutorial_skip_step", [])
	if tutorial != null:
		tutorial.skip_step()


func tutorial_skip_all() -> void:
	_record("tutorial_skip_all", [])
	if tutorial != null:
		tutorial.skip_all()
# endregion


func set_alarm(on: bool) -> void:
	_record("set_alarm", [on])  # save-load
	if alarm == on:
		return
	alarm = on
	bus.alarm_changed.emit(on)


# region A1d
## Same order as BeltGrid: 0=N, 1=E, 2=S, 3=W.
const BELT_DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


func can_belt_cell_error(c: Vector2i) -> String:
	if not map.is_passable(c) or buildings.occupied(c) or buildings.blueprint_at(c) != null:
		return "blocked"
	return ""


## Player command: a dragged belt path (one recorded command). Cells must be
## 4-connected in order; each belt points to the next cell, the last one uses
## `last_dir`. Atomic: any invalid cell rejects the whole path.
func place_belt(cells: Array, last_dir: int) -> bool:
	_record("place_belt", [cells, last_dir])  # save-load
	if cells.is_empty() or last_dir < 0 or last_dir > 3:
		return false
	var seen := {}
	var dirs: Array = []
	for i in cells.size():
		var c: Vector2i = cells[i]
		if seen.has(c) or can_belt_cell_error(c) != "":
			return false
		seen[c] = true
		if i + 1 < cells.size():
			var d := BELT_DIRS.find((cells[i + 1] as Vector2i) - c)
			if d < 0:
				return false
			dirs.append(d)
		else:
			dirs.append(last_dir)
	logistics.place_path(cells, dirs)
	return true


## Player command: removes the belts on `cells`; true if any was removed.
func remove_belt(cells: Array) -> bool:
	_record("remove_belt", [cells])  # save-load
	var any := false
	for c: Vector2i in cells:
		if logistics.remove_at(c):
			any = true
	return any


func set_belt_dir(c: Vector2i, dir: int) -> bool:
	_record("set_belt_dir", [c, dir])  # save-load
	return dir >= 0 and dir <= 3 and logistics.set_dir(c, dir)
# endregion


# region L2
## Belt node kinds (frozen schema): 1 splitter_basic, 2 splitter_smart, 3 splitter_priority, 4 merger.
const NODE_DEFS: Array[String] = ["", "splitter_basic", "splitter_smart", "splitter_priority", "merger"]


## Player command: places a belt node (tech-gated by kind) on a free cell or over a plain belt.
func place_belt_node(kind: int, c: Vector2i, dir: int) -> bool:
	_record("place_belt_node", [kind, c, dir])  # save-load
	if kind < 1 or kind >= NODE_DEFS.size() or dir < 0 or dir > 3 or not map.in_bounds(c):
		return false
	if not research.building_unlocked(NODE_DEFS[kind]) or can_belt_cell_error(c) != "":
		return false
	if not logistics.has_method("place_node"):
		return false
	return bool(logistics.call("place_node", kind, c, dir))


## Player command: output filter of a smart splitter. slot 0=left 1=front 2=right.
func set_splitter_filter(c: Vector2i, slot: int, value: String) -> bool:
	_record("set_splitter_filter", [c, slot, value])  # save-load
	if slot < 0 or slot > 2 or not map.in_bounds(c) or not logistics.has_method("set_filter"):
		return false
	if value != "any" and value != "overflow" and not defs.items.has(value):
		return false
	if get_belt_node_kind(c) != 2:
		return false
	return bool(logistics.call("set_filter", c, slot, value))


## Node kind at `c` (0 = plain belt or none). Safe before L1 lands.
func get_belt_node_kind(c: Vector2i) -> int:
	var k: Variant = logistics.belts.get("kind")
	if k == null or not logistics.belts.in_bounds(c):
		return 0
	return int((k as PackedByteArray)[logistics.belts.index(c)])


## Filter value of a smart output ("any" if unset).
func get_splitter_filter(c: Vector2i, slot: int) -> String:
	var f: Variant = logistics.belts.get("filters")
	if f is Dictionary and (f as Dictionary).has(logistics.belts.index(c)):
		return str((f as Dictionary)[logistics.belts.index(c)][slot])
	return "any"
# endregion


# region save-load
func _record(cmd: String, args: Array) -> void:
	if not replaying:
		command_log.append([tick, cmd, args])
# endregion


# --- Bus helpers ------------------------------------------------------------------

## Connects a system to a bus signal; undone by `dispose()`.
func listen(sig: Signal, callable: Callable) -> void:
	sig.connect(callable)
	_connections.append([sig, callable])


## Disconnects everything this simulation attached to the bus.
## Call before dropping a simulation that used a shared (autoload) bus.
func dispose() -> void:
	for pair in _connections:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])
	_connections.clear()
	# Break RefCounted cycles generically: every system object that holds
	# `sim` gets it cleared, then the reference is dropped. New systems are
	# covered automatically (no per-system lines to merge).
	if colonists:
		for c in colonists.list:
			c.job = null
	for prop in get_property_list():
		if not (prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE) or prop["type"] != TYPE_OBJECT:
			continue
		var name: String = prop["name"]
		if name in ["bus", "rng", "defs", "ledger", "map"]:
			continue
		var o: Object = get(name)
		if o != null and "sim" in o:
			o.set("sim", null)
		set(name, null)


# region crafting
## Adds a bill to a bills building. Returns the bill id or -1.
func add_bill(building_id: int, recipe_id: String, mode: String, target: int) -> int:
	_record("add_bill", [building_id, recipe_id, mode, target])  # save-load
	return crafting.add_bill(buildings.get_by_id(building_id), recipe_id, mode, target)


func remove_bill(building_id: int, bill_id: int) -> bool:
	_record("remove_bill", [building_id, bill_id])  # save-load
	return crafting.remove_bill(buildings.get_by_id(building_id), bill_id)


func update_bill(building_id: int, bill_id: int, mode: String, target: int, paused: bool) -> bool:
	_record("update_bill", [building_id, bill_id, mode, target, paused])  # save-load
	return crafting.update_bill(buildings.get_by_id(building_id), bill_id, mode, target, paused)


## Filter/priority apply to the whole connected zone group containing `c`.
func set_zone_filter(c: Vector2i, item_id: String, allowed: bool) -> bool:
	_record("set_zone_filter", [c, item_id, allowed])  # save-load
	return storage.set_filter(c, item_id, allowed)


## 0 = low, 1 = normal, 2 = high (data/crafting.json "priorities").
func set_zone_priority(c: Vector2i, priority: int) -> bool:
	_record("set_zone_priority", [c, priority])  # save-load
	return storage.set_priority(c, priority)
# endregion


# region jobs-core
## Work priority of one colonist: 0 = off, 1 (first) .. work.json max_priority.
func set_work_priority(colonist_id: int, work_type: String, p: int) -> bool:
	_record("set_work_priority", [colonist_id, work_type, p])  # save-load
	var c := colonists.get_by_id(colonist_id)
	if c == null or not defs.work["types"].has(work_type):
		return false
	if p < 0 or p > int(defs.work["max_priority"]):
		return false
	if c.skills.priority(work_type) == p:
		return true
	c.skills.priorities[work_type] = p
	bus.work_priority_changed.emit(colonist_id, work_type, p)
	return true
# endregion

# region combat
## Drafted colonists ignore work and the alarm and fight.
func set_drafted(colonist_id: int, on: bool) -> bool:
	_record("set_drafted", [colonist_id, on])  # save-load
	return combat.set_drafted(colonists.get_by_id(colonist_id), on)


## Drafted colonist walks to `cell` (stops to shoot enemies in range on the way).
func order_move(colonist_id: int, cell: Vector2i) -> bool:
	_record("order_move", [colonist_id, cell])  # save-load
	return combat.order_move(colonists.get_by_id(colonist_id), cell)


func order_attack(colonist_id: int, enemy_id: int) -> bool:
	_record("order_attack", [colonist_id, enemy_id])  # save-load
	return combat.order_attack(colonists.get_by_id(colonist_id), enemy_id)
# region C1
## Squads (sim/squads). `ids_in` / `roles_in`: Array or JSON text (recorded as text). Empty roles = auto by affinity.
## Returns the squad id, or -1 if rejected (unknown/dead/already squadded member, > max size, bad role).
func form_squad(ids_in: Variant, roles_in: Variant = "[]") -> int:
	_record("form_squad", [_arg_text(ids_in), _arg_text(roles_in)])  # save-load
	return squads.form(_arg_array(ids_in), _arg_array(roles_in))


func disband_squad(sid: int) -> bool:
	_record("disband_squad", [sid])  # save-load
	return squads.disband(sid)


## Members walk to `cell` + their role offset (nearest free passable cell) and hold; clears focus.
func squad_hold(sid: int, cell: Vector2i) -> bool:
	_record("squad_hold", [sid, cell])  # save-load
	return squads.hold(sid, cell)


## All non-medic members attack enemy `enemy_id`.
func squad_focus(sid: int, enemy_id: int) -> bool:
	_record("squad_focus", [sid, enemy_id])  # save-load
	return squads.focus(sid, enemy_id)
# endregion
# region crises
func resolve_crisis(crisis_id: String, option_id: String) -> bool:
	_record("resolve_crisis", [crisis_id, option_id])  # save-load
	return crises.resolve(crisis_id, option_id)
# endregion
# region arrivals
## Answers a pending storyteller choice (wanderer: join or not; pod survivor:
## rescue or leave). Returns false for an unknown uid.
func answer_event(event_uid: int, accept: bool) -> bool:
	_record("answer_event", [event_uid, accept])  # save-load
	return storyteller.answer(event_uid, accept)
# endregion


# region ammo
func set_turret_ammo_policy(building_id: int, policy: String) -> bool:
	_record("set_turret_ammo_policy", [building_id, policy])  # save-load
	return ammo.set_policy(building_id, policy)
# endregion

# region perks
func learn_perk(colonist_id: int, perk_id: String) -> bool:
	_record("learn_perk", [colonist_id, perk_id])  # save-load
	return perks.learn(colonists.get_by_id(colonist_id), perk_id)


func use_perk(colonist_id: int, perk_id: String) -> bool:
	_record("use_perk", [colonist_id, perk_id])  # save-load
	return perks.use(colonists.get_by_id(colonist_id), perk_id)


func respec_perks(colonist_id: int) -> bool:
	_record("respec_perks", [colonist_id])  # save-load
	return perks.respec(colonists.get_by_id(colonist_id))
# endregion


# region contracts
func accept_contract(contract_id: int) -> bool:
	_record("accept_contract", [contract_id])  # save-load
	return contracts.accept(contract_id)


func decline_contract(contract_id: int) -> bool:
	_record("decline_contract", [contract_id])  # save-load
	return contracts.decline(contract_id)


func deliver_contract(contract_id: int) -> bool:
	_record("deliver_contract", [contract_id])  # save-load
	return contracts.deliver(contract_id)
# region debt
## Moves refined essence from storage into the prisoner's debt (ledger sink "debt").
func pay_debt(colonist_id: int, amount: int) -> bool:
	_record("pay_debt", [colonist_id, amount])  # save-load
	return debt.pay(colonists.get_by_id(colonist_id), amount)


## Auto-pays `per_day` essence every day while stock allows (0 = off).
func set_quota(colonist_id: int, per_day: int) -> bool:
	_record("set_quota", [colonist_id, per_day])  # save-load
	return debt.set_quota(colonists.get_by_id(colonist_id), per_day)


## After the debt is paid: stay as a free colonist (true) or leave the planet.
func choose_payoff(colonist_id: int, stay: bool) -> bool:
	_record("choose_payoff", [colonist_id, stay])  # save-load
	return debt.choose_payoff(colonists.get_by_id(colonist_id), stay)
# region idle-work
## Player-set patrol route (empty array = automatic ring around the base).
## Recorded as text because the save log holds only scalars and Vector2i.
func set_patrol_route(points: Array) -> void:
	var parts: PackedStringArray = []
	for p: Vector2i in points:
		parts.append("%d,%d" % [p.x, p.y])
	set_patrol_route_text(";".join(parts))


## Same as `set_patrol_route`, points as "x,y;x,y" (the form saved in the command log).
func set_patrol_route_text(text: String) -> void:
	_record("set_patrol_route_text", [text])  # save-load
	idle_work.set_route(IdleWorkSystem.parse_route(text))
# endregion

# region mutation
## Spends refined essence to clean the contamination field around `c`.
func purify_cell(c: Vector2i) -> bool:
	_record("purify_cell", [c])  # save-load
	return mutation.purify(c)
# endregion

# region R2a
## Makes `tech_id` the active research (front of the queue). Spends its essence
## cost once. Returns false if unknown/done/locked/unaffordable.
func set_research(tech_id: String) -> bool:
	_record("set_research", [tech_id])  # save-load
	return research.set_active(tech_id)


## Appends (on) or removes (off) `tech_id` in the research queue. Removing a tech
## with no progress refunds its essence. Returns false if nothing changed.
func queue_research(tech_id: String, on: bool) -> bool:
	_record("queue_research", [tech_id, on])  # save-load
	return research.set_queued(tech_id, on)
# endregion



# region C2
## Squad role ability (taunt / volley / stabilise). Rejected on cooldown, missing essence, no user or no target.
func use_ability(squad_id: int, ability_id: String) -> bool:
	_record("use_ability", [squad_id, ability_id])  # save-load
	return abilities.use(squad_id, ability_id)
# endregion


# region T4
## Player command: slots one `ai_chip` from storage into a bench/smelter/assembler (never a miner).
func install_chip(building_id: int) -> bool:
	_record("install_chip", [building_id])  # save-load
	return chips.install(building_id)


## Player command: takes the chip out again (it drops on the building's cell).
func remove_chip(building_id: int) -> bool:
	_record("remove_chip", [building_id])  # save-load
	return chips.remove(building_id)
# endregion


# region R2b
func deliver_audit(tier: int) -> bool:
	_record("deliver_audit", [tier])  # save-load
	return milestones.deliver(tier)
# endregion
