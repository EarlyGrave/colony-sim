extends TestCase
## Y3: opt-in economy tuning is off by default and applies only via Defs.apply_y3().


func test_y3_off_by_default_and_applies_on_copy() -> void:
	var base := Defs.get_default()
	var d := base.duplicate_defs()
	assert_eq(int(d.balance["mining"]["yield"]), 5)
	d.apply_y3()
	assert_true(int(d.balance["mining"]["yield"]) > 5)
	assert_eq(int(base.balance["mining"]["yield"]), 5)
