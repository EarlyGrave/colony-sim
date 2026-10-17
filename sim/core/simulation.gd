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


func _place_starting_colony() -> void:
	var col_cfg: Dictionary = defs.balance["colony"]
	var center := map_center()
	buildings.place("hq", center - Vector2i(1, 1), false)
	var spots: Array[Vector2i] = [Vector2i(-2, 1), Vector2i(1, 2), Vector2i(2, -1), Vector2i(-2, -2), Vector2i(0, 3)]
	for i in int(col_cfg["colonists"]):
		var c := colonists.spawn(center + spots[i % spots.size()])
		c.engineer = i < int(col_cfg["engineers"])
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
	colonists.tick()
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
	if map.in_bounds(c):
		map.set_mine_designated(c, on)


## zone_id "" clears the zone. Returns false if the cell can't hold a zone.
func set_zone(c: Vector2i, zone_id: String) -> bool:
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
	if can_place_building(def_id, c) != "":
		return null
	return buildings.place(def_id, c)


## Player command: removes the building at `c` and refunds part of its cost.
func deconstruct(c: Vector2i) -> bool:
	return buildings.deconstruct(c)


func set_rule(rule_id: String, on: bool) -> void:
	if not rules.has(rule_id) or rules[rule_id] == on:
		return
	rules[rule_id] = on
	bus.rule_changed.emit(rule_id, on)


func is_rule_on(rule_id: String) -> bool:
	return bool(rules.get(rule_id, false))


func set_alarm(on: bool) -> void:
	if alarm == on:
		return
	alarm = on
	bus.alarm_changed.emit(on)


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
	for sys: Object in [items, colonists, jobs, buildings, contamination, threats, storyteller]:
		if sys != null:
			sys.set("sim", null)
	if colonists:
		for c in colonists.list:
			c.job = null
	items = null
	colonists = null
	jobs = null
	buildings = null
	contamination = null
	threats = null
	storyteller = null
