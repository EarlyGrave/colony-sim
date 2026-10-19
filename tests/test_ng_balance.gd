extends TestCase
## N3: Next Sentence chain tool is deterministic and its ng numbers stay sane.
const Chain := preload("res://tools/ng_chain_report.gd")


func test_chain_deterministic_and_smoke() -> void:
	var a: Dictionary = Chain.chain(3, 2)
	var b: Dictionary = Chain.chain(3, 2)
	assert_eq(Chain.line(a), Chain.line(b))
	assert_eq(a["seed2"], b["seed2"])
	assert_eq(int(a["ng"]["sentence"]), 2)


func test_ng_numbers_sane() -> void:
	var cfg: Dictionary = MetaState.new().ng_cfg()
	assert_true(float(cfg["debt_carry_frac"]) > 0.0 and float(cfg["debt_carry_frac"]) <= 1.0)
	assert_true(int(cfg["tech_carry"]) >= 1)
