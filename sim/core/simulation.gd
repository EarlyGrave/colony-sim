class_name Simulation
extends RefCounted
## Root of the simulation. Owns the RNG, the tick counter and all systems.
## No rendering, no scene tree: runs headless in tests.

const TICKS_PER_SECOND := 10

var seed_value: int
var rng := RandomNumberGenerator.new()
var bus: Object
var defs: Defs
var tick := 0
var ticks_per_day: int

var ledger := Ledger.new()
var _connections: Array = []  # [signal, callable] pairs made on the bus
var map: MapGrid
var pathfinder: Pathfinder


func _init(p_seed: int, p_bus: Object, p_defs: Defs = null) -> void:
	seed_value = p_seed
	rng.seed = p_seed
	bus = p_bus
	defs = p_defs if p_defs != null else Defs.get_default()
	ticks_per_day = int(defs.balance["ticks_per_day"])


## Generates the map and places the starting colony.
func start_new_game() -> void:
	var cfg: Dictionary = defs.balance["map"]
	map = MapGrid.new(int(cfg["width"]), int(cfg["height"]), bus)
	MapGenerator.generate(map, rng, cfg)
	_init_systems()


## Empty all-ground map, for test scenarios.
func start_empty(w: int, h: int) -> void:
	map = MapGrid.new(w, h, bus)
	_init_systems()


func _init_systems() -> void:
	pathfinder = Pathfinder.new(map)
	listen(bus.tile_changed, pathfinder.refresh_cell)


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


## Advances the simulation by one fixed tick.
func step() -> void:
	tick += 1
	if tick % ticks_per_day == 0:
		bus.day_started.emit(day())
	bus.tick_advanced.emit(tick)


func run_ticks(n: int) -> void:
	for i in n:
		step()


func day() -> int:
	return tick / ticks_per_day


func map_center() -> Vector2i:
	return Vector2i(map.width / 2, map.height / 2)
