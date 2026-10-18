extends RefCounted
## Minimal stand-in for W3's Campaign (plain fields + step order only) so the W4 tests do not
## depend on sim/campaign/campaign.gd. Same constructor and field names as the plan's API.

var campaign_seed: int
var bus_factory: Callable
var defs: Defs
var maps: Array = []
var active := 0
var tick := 0
var log: Array = []
var in_flight: Array = []
var ledgers: Dictionary = {}


func _init(p_seed: int, p_bus_factory: Callable, p_defs: Defs = null, _opts := {}) -> void:
	campaign_seed = p_seed
	bus_factory = p_bus_factory
	defs = p_defs if p_defs != null else Defs.get_default()


func start() -> void:
	var sim := Simulation.new(campaign_seed, bus_factory.call(), defs)
	sim.start_new_game()
	maps = [{"id": 0, "biome": "start", "sim": sim, "kind": "home"}]


func active_sim() -> Simulation:
	return Expedition.map_entry(self, active)["sim"]


func step() -> void:
	tick += 1
	active_sim().step()
	Expedition.tick(self)
	Sling.tick(self)


func state_hash() -> int:
	var parts: Array = [tick, active, in_flight, ledgers]
	for m: Dictionary in maps:
		parts.append([m["id"], SaveGame.state_hash(m["sim"]), m.get("sling_ready", 0), m.get("dead_charged", 0)])
	return var_to_str(parts).hash()


func dispose() -> void:
	for m: Dictionary in maps:
		(m["sim"] as Simulation).dispose()
	maps.clear()
