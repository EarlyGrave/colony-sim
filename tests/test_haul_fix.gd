extends TestCase
## I4: haul_blocked_fix decision (measured 10 seeds/60 d: ON alive>=8 4/10 vs OFF 9/10 -> stays OFF).


func test_haul_blocked_fix_stays_off() -> void:
	assert_false(bool(Defs.get_default().balance.get("haul_blocked_fix", false)))
