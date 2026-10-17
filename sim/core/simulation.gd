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
# region health
var health: HealthSystem
# endregion
# region mood
var mood: MoodSystem
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
var storage: StorageSettings
# region combat
var combat: CombatSystem
# endregion

var _connections: Array = []  # [signal, callable] pairs made on the bus


func _init(p_seed: int, p_bus: Object, p_defs: Defs = null) -> void:
	seed_value = p_seed
	rng.seed = p_seed
	bus = p_bus
	defs = p_defs if p_defs != null else Defs.get_default()
	ticks_per_day = int(defs.balance["ticks_per_day"])
	for id: String in defs.rules:
		rules[id] = bool(defs.rules[id]["default"])


## Generates the map and places the starting colony.
func start_new_game() -> void:
	var cfg: Dictionary = defs.balance["map"]
	map = MapGrid.new(int(cfg["width"]), int(cfg["height"]), bus)
	MapGenerator.generate(map, rng, cfg)
	_init_systems()
	_place_starting_colony()


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
	# region health
	health = HealthSystem.new(self)
	# endregion
	# region mood
	mood = MoodSystem.new(self)
	# region crafting
	storage = StorageSettings.new(self)
	crafting = BillSystem.new(self)
	# region combat
	combat = CombatSystem.new(self)
	# endregion


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


# --- Tick ---------------------------------------------------------------------

## Advances the simulation by one fixed tick.
func step() -> void:
	if game_over_reason != "":
		return
	tick += 1
	crafting.tick()  # region crafting
	colonists.tick()
	health.tick()  # region health
	mood.tick()  # region mood
	threats.tick()
	contamination.tick()
	storyteller.tick()
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
		return "Нельзя построить"
	return buildings.placement_error(def_id, c)


func place_building(def_id: String, c: Vector2i) -> Building:
	_record("place_building", [def_id, c])  # save-load
	if can_place_building(def_id, c) != "":
		return null
	return buildings.place(def_id, c)


## Player command: removes the building at `c` and refunds part of its cost.
func deconstruct(c: Vector2i) -> bool:
	_record("deconstruct", [c])  # save-load
	return buildings.deconstruct(c)


func set_rule(rule_id: String, on: bool) -> void:
	_record("set_rule", [rule_id, on])  # save-load
	if not rules.has(rule_id) or rules[rule_id] == on:
		return
	rules[rule_id] = on
	bus.rule_changed.emit(rule_id, on)


func is_rule_on(rule_id: String) -> bool:
	return bool(rules.get(rule_id, false))


func set_alarm(on: bool) -> void:
	_record("set_alarm", [on])  # save-load
	if alarm == on:
		return
	alarm = on
	bus.alarm_changed.emit(on)


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
	# Break RefCounted cycles (systems hold a reference back to the sim).
	for sys: Object in [items, colonists, jobs, buildings, contamination, threats, storyteller, health]:
		if sys != null:
			sys.set("sim", null)
	if colonists:
		for c in colonists.list:
			c.job = null
	# region combat
	if combat != null:
		combat.sim = null
		combat = null
	# endregion
	items = null
	colonists = null
	jobs = null
	buildings = null
	contamination = null
	threats = null
	storyteller = null
	if mood != null:  # region mood
		mood.sim = null
	mood = null


# region crafting
## Adds a bill to a bills building. Returns the bill id or -1.
func add_bill(building_id: int, recipe_id: String, mode: String, target: int) -> int:
	return crafting.add_bill(buildings.get_by_id(building_id), recipe_id, mode, target)


func remove_bill(building_id: int, bill_id: int) -> bool:
	return crafting.remove_bill(buildings.get_by_id(building_id), bill_id)


func update_bill(building_id: int, bill_id: int, mode: String, target: int, paused: bool) -> bool:
	return crafting.update_bill(buildings.get_by_id(building_id), bill_id, mode, target, paused)


## Filter/priority apply to the whole connected zone group containing `c`.
func set_zone_filter(c: Vector2i, item_id: String, allowed: bool) -> bool:
	return storage.set_filter(c, item_id, allowed)


## 0 = low, 1 = normal, 2 = high (data/crafting.json "priorities").
func set_zone_priority(c: Vector2i, priority: int) -> bool:
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
	health = null

# region combat
## Drafted colonists ignore work and the alarm and fight.
func set_drafted(colonist_id: int, on: bool) -> bool:
	return combat.set_drafted(colonists.get_by_id(colonist_id), on)


## Drafted colonist walks to `cell` (stops to shoot enemies in range on the way).
func order_move(colonist_id: int, cell: Vector2i) -> bool:
	return combat.order_move(colonists.get_by_id(colonist_id), cell)


func order_attack(colonist_id: int, enemy_id: int) -> bool:
	return combat.order_attack(colonists.get_by_id(colonist_id), enemy_id)
# endregion
