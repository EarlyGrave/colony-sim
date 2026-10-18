extends TestCase
## Job assignment order must stay identical across work-giver caching changes.

const Scenario := preload("res://tests/scenario.gd")
const EXPECT := {1: "b8f3fe349b88b7655963d0b93b27ea9deb47c86444d528de62bff3628f135617", 2: "389437291d6c50410043a2318b0af3bd2c92160ef840cb2b0b7acdc1802e0bcc"}


func _record(seed_value: int, ticks: int) -> String:
	var sim := make_sim(seed_value)
	Scenario.standard_colony(sim, 3)
	var last: Dictionary = {}
	var log := PackedStringArray()
	for t in ticks:
		sim.step()
		for c in sim.colonists.list:
			var j: Job = c.job
			if j == null:
				last.erase(c.id)
				continue
			if last.get(c.id) != j:
				last[c.id] = j
				log.append("%d:%d:%s:%s:%s" % [sim.tick, c.id, j.type, j.fail_key, ",".join(j.reservations)])
	var h := ("\n".join(log)).sha256_text()
	print("job_sequence seed=%d events=%d hash=%s" % [seed_value, log.size(), h])
	return h


func test_assignment_sequence_is_stable() -> void:
	for s in EXPECT:
		var h := _record(s, 3000)
		assert_eq(h, EXPECT[s], "job sequence seed %d" % s)


func test_incremental_counters_match_brute_force() -> void:
	var sim := make_sim(3)
	Scenario.standard_colony(sim, 3)
	var center := sim.map_center()
	for i in 1200:
		sim.step()
		if i == 300:
			sim.set_zone(center + Vector2i(1, 5), "storage")
		if i == 600:
			sim.storage.set_filter(center + Vector2i(1, 5), "raw_food", false)
		if i % 100 == 0:
			for item: String in ["raw_food", "essence_ore", "refined_essence", "waste"]:
				var g := 0
				var st := 0
				for c in sim.items.stacks:
					if sim.items.stacks[c]["item"] == item:
						g += int(sim.items.stacks[c]["count"])
						if sim.items.is_stored(c):
							st += int(sim.items.stacks[c]["count"])
				assert_eq(sim.items.count_on_ground(item), g, "ground %s @%d" % [item, i])
				assert_eq(sim.items.count_stored(item), st, "stored %s @%d" % [item, i])
