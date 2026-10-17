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
# endregion
# region perks
var perks: PerkSystem
var quality: QualitySystem  # region quality
var ammo: AmmoSystem  # region ammo
# endregion
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
	crises = CrisisSystem.new(self)  # region crises
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
	needs.tick()  # region needs
	farming.tick()  # region needs
	colonists.tick()
	perks.tick()  # region perks
	health.tick()  # region health
	debt.tick()  # region debt
	mood.tick()  # region mood
	threats.tick()
	contamination.tick()
	mutation.tick()  # region mutation
	crises.tick()  # region crises
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
