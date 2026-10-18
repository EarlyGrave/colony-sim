class_name QaTutorialBot
extends RefCounted
## O5: a "new player" bot that clears the 12 tutorial goals using only public
## Simulation commands. When `sim.tutorial` exists (O1) it is only read to
## report progress; otherwise the goals are tracked from bus signals here.
## Deterministic: no randomness of its own.

const Scen := preload("res://tests/scenario.gd")
const GOALS: Array[String] = [
	"select", "designate", "zone", "stock", "build", "refine",
	"contaminate", "research", "belt", "forecast", "wave", "decoy",
]
const STEP_TICKS := 60

var sim: Simulation
var done := {}  ## goal -> tick reached
var finish_tick := -1
var _designations := 0
var _zones := 0
var _stage := 0
var _chain := false


## A fresh game for the bot. Tier 2 is pre-granted (opts, as other bots do):
## the real audit needs 40 plates + 10 parts, far beyond a 12-day tutorial.
static func make_sim(seed_value: int, bus: Node) -> Simulation:
	var sim := Simulation.new(seed_value, bus, null, {"research_audit_tiers": [2]})
	sim.start_new_game()
	return sim


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	var b := sim.bus
	b.designation_changed.connect(func(_c: Vector2i) -> void: _designations += 1)
	b.zone_changed.connect(func(_c: Vector2i) -> void: _zones += 1)
	b.building_placed.connect(func(_id: int) -> void: _mark("build"))
	b.first_refine_done.connect(func() -> void: _mark("refine"))
	b.contamination_changed.connect(func(_l: float) -> void: _mark("contaminate"))
	b.research_completed.connect(func(_t: String) -> void: _mark("research"))
	b.forecast_revealed.connect(func() -> void: _mark("forecast"))
	b.wave_repelled.connect(func(_i: int) -> void:
		if sim.alarm or sim.buildings.count_of("turret") > 0:
			_mark("wave"))


func _mark(goal: String) -> void:
	if not done.has(goal):
		done[goal] = sim.tick


func complete() -> bool:
	return done.size() == GOALS.size()


## Runs until all goals are done, game over, or `max_days` elapsed.
func run(max_days: int) -> void:
	var limit := max_days * sim.ticks_per_day
	while sim.tick < limit and sim.game_over_reason == "" and not complete():
		_act()
		sim.run_ticks(STEP_TICKS)
		_poll()
	if complete() and finish_tick < 0:
		finish_tick = sim.tick


func days_for(goal: String) -> float:
	return float(done.get(goal, -1)) / float(sim.ticks_per_day)


func _poll() -> void:
	if sim.has_method("tutorial_ack") and sim.tutorial != null:
		return
	if _designations >= 3:
		_mark("designate")
	if _zones >= 4:
		_mark("zone")
	var stock := 0
	for c: Vector2i in sim.items.stacks:
		if sim.map.get_zone(c) == "stockpile":
			stock += int(sim.items.stacks[c]["count"])
	if stock >= 10:
		_mark("stock")
	if sim.logistics != null and _chain and sim.logistics.belts.belt_count >= 3:
		_mark("belt")


func _act() -> void:
	var center := sim.map_center()
	match _stage:
		0:
			if sim.has_method("tutorial_ack"):
				sim.call("tutorial_ack")
			_mark("select")
			Scen.designate_nearest_deposits(sim, 4)
			_stage = 1
		1:
			var spot := Scen.find_zone_spot(sim, center + Vector2i(-6, 2), Vector2i(2, 2))
			for y in 2:
				for x in 2:
					sim.set_zone(spot + Vector2i(x, y), "stockpile")
			_stage = 2
		2:
			sim.place_building("research_bench", Scen.find_spot(sim, "research_bench", center + Vector2i(5, -3), 0))
			sim.place_building("refinery", Scen.find_spot(sim, "refinery", center, 3))
			var dump := Scen.find_zone_spot(sim, center + Vector2i(-6, -4), Vector2i(3, 3))
			for y in 3:
				for x in 3:
					sim.set_zone(dump + Vector2i(x, y), "waste_dump")
			_stage = 3
		3:
			var crops := Scen.find_zone_spot(sim, center + Vector2i(4, 6), Vector2i(4, 3))
			for y in 3:
				for x in 4:
					sim.set_zone(crops + Vector2i(x, y), "growing")
			for i in 4:
				sim.place_building("bed", Scen.find_spot(sim, "bed", center + Vector2i(-3 + i, 9), 0))
			sim.place_building("workbench", Scen.find_spot(sim, "workbench", center + Vector2i(5, 3), 0))
			_stage = 4
		4:
			if sim.day() >= 1 or sim.tick > 600:
				sim.set_research("decoys_1")
				Scen.build_chain(sim, true)  # returns {} in blueprint mode
				_chain = true
				_stage = 5
		5:
			for k in 6:
				sim.place_building("turret", Scen.find_spot(sim, "turret", center + Vector2i(roundi(cos(TAU * k / 6.0) * 5.0), roundi(sin(TAU * k / 6.0) * 5.0)), 0))
			_stage = 6
		_:
			if not done.has("decoy") and sim.research.is_done("decoys_1"):
				if sim.place_building("ash_beacon", Scen.find_spot(sim, "ash_beacon", center + Vector2i(-8, -8), 0)) != null:
					_mark("decoy")
			_defend()


## Raid response of an attentive player: raise the alarm while enemies are about.
func _defend() -> void:
	var fighting := not sim.threats.enemies.is_empty()
	if sim.alarm != fighting:
		sim.set_alarm(fighting)
