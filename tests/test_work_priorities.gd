extends TestCase
## Work priorities: per-colonist, per-work-type, applied by the job system.

const WorkTabScript := preload("res://view/panels/work_tab.gd")


func _mine_scene() -> Simulation:
	var sim := make_sim(5, false, 20, 20, peaceful_defs())
	sim.map.set_tile(Vector2i(10, 10), MapGrid.Tile.DEPOSIT, 100)
	sim.designate_mine(Vector2i(10, 10), true)
	return sim


func test_mining_off_never_mines() -> void:
	var sim := _mine_scene()
	var c := sim.colonists.spawn(Vector2i(2, 2))
	assert_true(sim.set_work_priority(c.id, "mining", 0))
	sim.run_ticks(1500)
	assert_eq(sim.ledger.get_count("mining:essence_ore"), 0, "mined while off")
	sim.set_work_priority(c.id, "mining", 3)
	sim.run_ticks(1500)
	assert_gt(sim.ledger.get_count("mining:essence_ore"), 0, "did not mine when enabled")


func test_priority_one_beats_three() -> void:
	var sim := _mine_scene()
	var c := sim.colonists.spawn(Vector2i(2, 2))
	sim.ledger.record_produced("essence_ore", 5, "test")
	sim.items.add_at(Vector2i(3, 3), "essence_ore", 5)
	for y in 2:
		sim.set_zone(Vector2i(15, 2 + y), "stockpile")
	# Hauling would normally come before mining (work.json order) at equal priority.
	sim.set_work_priority(c.id, "hauling", 3)
	sim.set_work_priority(c.id, "mining", 1)
	sim.jobs.tick_colonist(c)
	assert_true(c.job != null and c.job.type == "mine", "mining at 1 should beat hauling at 3")
	sim.jobs.end_job(c, Job.Status.FAILED, false)
	sim.set_work_priority(c.id, "mining", 3)
	sim.set_work_priority(c.id, "hauling", 1)
	sim.jobs.tick_colonist(c)
	assert_true(c.job != null and c.job.type == "haul", "hauling at 1 should beat mining at 3")


func test_equal_priority_uses_giver_order() -> void:
	var sim := _mine_scene()
	var c := sim.colonists.spawn(Vector2i(2, 2))
	sim.ledger.record_produced("essence_ore", 5, "test")
	sim.items.add_at(Vector2i(3, 3), "essence_ore", 5)
	sim.set_zone(Vector2i(15, 2), "stockpile")
	sim.jobs.tick_colonist(c)
	assert_true(c.job != null and c.job.type == "haul", "hauling is listed before mining")


func test_invalid_priority_rejected() -> void:
	var sim := _mine_scene()
	var c := sim.colonists.spawn(Vector2i(2, 2))
	assert_false(sim.set_work_priority(c.id, "mining", 9))
	assert_false(sim.set_work_priority(c.id, "nonsense", 1))
	assert_false(sim.set_work_priority(999, "mining", 1))
	assert_eq(c.skills.priority("mining"), 3)


func test_request_override() -> void:
	var sim := _mine_scene()
	var c := sim.colonists.spawn(Vector2i(2, 2))
	sim.jobs.tick_colonist(c)
	assert_true(c.job != null)
	var j := MineJob.new(Vector2i(10, 10))
	sim.jobs.request_override(c, j)
	assert_true(c.job == j)


func test_work_tab_cycles_priority() -> void:
	var sim := _mine_scene()
	var c := sim.colonists.spawn(Vector2i(2, 2))
	var tab: Control = WorkTabScript.new()
	tab.bind(sim)
	assert_eq((tab.buttons[c.id]["mining"] as Button).text, "3")
	for expected in [2, 1, 0, 4, 3]:
		(tab.buttons[c.id]["mining"] as Button).pressed.emit()
		assert_eq(c.skills.priority("mining"), expected)
	assert_eq((tab.buttons[c.id]["mining"] as Button).text, "3")
	tab.free()
