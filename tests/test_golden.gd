extends TestCase
## Golden replays: 5 recorded command logs must reproduce their state hashes
## every 100 ticks. Regenerate intentionally with tools/make_golden.gd.

const Golden := preload("res://tests/golden.gd")


func test_golden_replays() -> void:
	for name in Golden.NAMES:
		var g := Golden.load_golden(name)
		if g.is_empty():
			fail("golden %s: file missing (run tools/make_golden.gd --regen)" % name)
			continue
		assert_eq(g["hashes"].size(), Golden.TOTAL / Golden.STEP, "golden %s hash count" % name)
		var res := Golden.run(g, Golden.decode_cmds(g["commands"]), Callable())
		var msg := Golden.compare(name, g, res)
		if msg != "":
			fail(msg)
