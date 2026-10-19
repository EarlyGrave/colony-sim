extends TestCase
## Job assignment order must stay identical across work-giver caching changes.

const Scenario := preload("res://tests/scenario.gd")
# Re-baselined 2026-10-19 after PW1 skill curve (L0 = 0.3x) + PW2 traits + TW3 lockdown changed job timing intentionally.
const EXPECT := {1: "5cce1c248ae9779ba8831ee050234972735e3f53f54d79c78e77b91f99309549", 2: "2e436d3cad5d9aa7c1326021d566c3ac7802248f5371f35cc0ced57360822a26"}


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
