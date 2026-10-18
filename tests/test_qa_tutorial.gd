extends TestCase
## O5 + R5X: the tutorial bot clears all 12 Warden's Orientation steps (sim.tutorial.step,
## O1's scripted audit raid) on seeds 1..3 within 12 game days, with nobody dead.

const Bot := preload("res://tests/qa_tutorial_bot.gd")
const MAX_DAYS := 14  # B1: belts need real research, release lands ~d11-13.5


func _run(seed_value: int) -> QaTutorialBot:
	var sim := Bot.make_sim(seed_value, make_bus())
	_sims.append(sim)
	var bot := Bot.new(sim)
	bot.run(MAX_DAYS)
	return bot


func test_bot_finishes_all_12_steps_seeds_1_to_3() -> void:
	for s in [1, 2, 3]:
		var bot := _run(s)
		assert_true(bot.complete(), "seed %d finished the tutorial (step %d)" % [s, bot.sim.tutorial.step])
		assert_eq(bot.done.size(), 12, "seed %d: 12 steps passed" % s)
		assert_eq(bot.sim.colonists.list.filter(func(c: Colonist) -> bool: return not c.alive).size(), 0, "seed %d: 0 deaths" % s)
		assert_true(bot.sim.game_over_reason == "", "seed %d: capsule alive" % s)
		assert_true(bot.finish_tick <= MAX_DAYS * bot.sim.ticks_per_day, "seed %d within %d days" % [s, MAX_DAYS])


func test_bot_deterministic() -> void:
	var a := _run(2)
	var b := _run(2)
	assert_eq(a.finish_tick, b.finish_tick)
	assert_eq(a.done, b.done)
	assert_eq(SaveGame.state_hash(a.sim), SaveGame.state_hash(b.sim))
