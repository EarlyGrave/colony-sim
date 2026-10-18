extends TestCase
## O5: the tutorial bot completes the goals on seeds 1..3 (12 game days).
## The two combat goals ("wave", "decoy" research timing) depend on natural
## raids until O1's scripted audit raid exists, so they are asserted only
## when `sim.tutorial` is present.

const Bot := preload("res://tests/qa_tutorial_bot.gd")
const PEACEFUL_GOALS: Array[String] = [
	"select", "designate", "zone", "stock", "build", "refine",
	"contaminate", "belt", "forecast",
]


func _run(seed_value: int) -> QaTutorialBot:
	var sim := Bot.make_sim(seed_value, make_bus())
	_sims.append(sim)
	var bot := Bot.new(sim)
	bot.run(12)
	return bot


func test_bot_reaches_goals_seeds_1_to_3() -> void:
	for s in [1, 2, 3]:
		var bot := _run(s)
		for g in PEACEFUL_GOALS:
			assert_true(bot.done.has(g), "seed %d goal %s" % [s, g])
		if bot.sim.get("tutorial") != null:
			assert_true(bot.complete(), "seed %d all 12 goals" % s)
			assert_eq(bot.sim.colonists.list.filter(func(c: Colonist) -> bool: return not c.alive).size(), 0)


func test_bot_deterministic() -> void:
	var a := _run(2)
	var b := _run(2)
	assert_eq(a.done, b.done)
	assert_eq(SaveGame.state_hash(a.sim), SaveGame.state_hash(b.sim))
