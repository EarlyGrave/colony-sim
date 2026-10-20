extends TestCase
## F7 W2: petition pace tool smoke (1 seed x 5 days).

const Pace := preload("res://tools/petition_pace.gd")


func test_smoke_table() -> void:
	var t: String = Pace.run(1, 5)
	assert_true(t.contains("SEED 1"), "seed header")
	assert_true(t.contains("P1 "), "P1 row")
	assert_true(t.contains("plate") and t.contains("refined_essence"), "5-day income rows")
	assert_true(t.contains("SUM seed 1"), "summary")
	assert_eq(t, Pace.run(1, 5), "deterministic")
