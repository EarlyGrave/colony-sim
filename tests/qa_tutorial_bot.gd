class_name QaTutorialBot
extends RefCounted
## O5: a "new player" bot that clears the 12 tutorial goals using only public
## Simulation commands; progress is read from `sim.tutorial.step` (R5X).
## Deterministic: no randomness of its own.

const Scen := preload("res://tests/scenario.gd")
const GOALS: Array[String] = [
	"intake", "dig", "storage", "haul", "tool", "dirty", "research", "belt", "forecast", "audit", "decoy", "release",
]
const STEP_TICKS := 60

var sim: Simulation
var done := {}  ## lesson id -> tick it was completed (read from sim.tutorial.step)
var finish_tick := -1
var _stage := 0
var _chain := false
var _beacon := false


## A fresh game with Warden's Orientation on (the scripted audit raid included).
static func make_sim(seed_value: int, bus: Node) -> Simulation:
	var sim := Simulation.new(seed_value, bus, null, {"tutorial": true, "research_locked": true})  # as the real game
	sim.start_new_game()
	return sim


func _init(p_sim: Simulation) -> void:
	sim = p_sim


func complete() -> bool:
	return sim.tutorial.finished()


## Runs until the tutorial is finished, game over, or `max_days` elapsed.
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


## Lessons before the current step are done.
func _poll() -> void:
	for i in mini(sim.tutorial.step, GOALS.size()):
		if not done.has(GOALS[i]):
			done[GOALS[i]] = sim.tick


func _act() -> void:
	var lesson := str(sim.tutorial.current().get("id", ""))
	if lesson == "forecast" or lesson == "release":
		sim.tutorial_ack()  # the view sends these when the forecast ticker is opened / the card is tapped
	if sim.research.active() == "" and not sim.research.is_done("decoys_1") and sim.buildings.count_of("research_bench") > 0:
		sim.set_research("decoys_1")  # tier 2 is pre-approved by the tutorial
		for i in mini(2, sim.colonists.list.size()):
			sim.set_work_priority(sim.colonists.list[i].id, "researching", 1)  # a player puts two on the bench
	var center := sim.map_center()
	if _stage >= 4 and sim.tick % (sim.ticks_per_day / 2) < STEP_TICKS:
		Scen.designate_nearest_deposits(sim, 8)  # keep the miners busy
	match _stage:
		0:
			sim.tutorial_ack()
			Scen.designate_nearest_deposits(sim, 10)
			_stage = 1
		1:
			var spot := Scen.find_zone_spot(sim, center + Vector2i(-6, 2), Vector2i(2, 2))
			for y in 2:
				for x in 2:
					sim.set_zone(spot + Vector2i(x, y), "stockpile")
			_stage = 2
		2:
			for k in 2:  # one researcher per bench
				sim.place_building("research_bench", Scen.find_spot(sim, "research_bench", center + Vector2i(5, -3 - 3 * k), 0))
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
			_stage = 4
		4:
			if sim.tick > 300:
				Scen.build_chain(sim, true)  # returns {} in blueprint mode
				_chain = true
				_stage = 5
		5:
			for k in 2:
				sim.place_building("turret", Scen.find_spot(sim, "turret", center + Vector2i(roundi(cos(TAU * k / 2.0) * 5.0), roundi(sin(TAU * k / 2.0) * 5.0)), 0))
			_stage = 6
		_:
			if not _beacon:  # the decoy lesson is latched: an early beacon counts
				_beacon = sim.place_building("ash_beacon", Scen.find_spot(sim, "ash_beacon", center + Vector2i(-8, -8), 0)) != null
			_defend()


## Raid response of an attentive player: raise the alarm while enemies are about.
func _defend() -> void:
	var fighting := not sim.threats.enemies.is_empty()
	if sim.alarm != fighting:
		sim.set_alarm(fighting)
