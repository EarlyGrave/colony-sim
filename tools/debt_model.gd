extends SceneTree
## D1: debt pacing model. godot --headless --path . -s tools/debt_model.gd -- [--colonists=8 --rate=7 --start=8 --ramp=8]
## Income ramps linearly from 0 at --start to --rate refined/day over --ramp days; all of it goes to debt.
## Prints expected total debt (mean of min/max), payoff day of a decent factory and day despair breaks start for an idle colony.
func _init() -> void:
	var n := 8
	var rate := 7.0
	var start := 8
	var ramp := 8
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--colonists="): n = int(a.get_slice("=", 1))
		elif a.begins_with("--rate="): rate = float(a.get_slice("=", 1))
		elif a.begins_with("--start="): start = int(a.get_slice("=", 1))
		elif a.begins_with("--ramp="): ramp = int(a.get_slice("=", 1))
	var d: Dictionary = Defs.get_default().debt
	var total := n * (float(d["debt_min"]) + float(d["debt_max"])) * 0.5
	var cum := 0.0
	var pay_day := -1
	for day in range(1, 121):
		cum += rate * clampf(float(day - start) / float(ramp), 0.0, 1.0) if day > start else 0.0
		if pay_day < 0 and cum >= total:
			pay_day = day
	# DB: installments + interest. Payoff day with interest on the remaining balance each period.
	var tot2 := total
	var paid2 := 0.0
	var pay2 := -1
	var per := int(d["period_days"])
	for day in range(1, 121):
		paid2 += rate * clampf(float(day - start) / float(ramp), 0.0, 1.0) if day > start else 0.0
		if day % per == 0:
			tot2 += (tot2 - paid2) * float(d["interest_pct"]) / 100.0
		if pay2 < 0 and paid2 >= tot2:
			pay2 = day
		if day == 60:
			print("d60: paid %.0f of %.0f (%.0f%%)" % [paid2, tot2, 100.0 * paid2 / tot2])
	print("with interest: payoff_day=%d (-1 = never within 120 d); installment=%d/%dd per inmate" % [pay2, int(d["installment"]), per])
	var due := int(d["due_days"])
	var brk := due + int(ceil((float(d["break_despair_min"]) + float(d["despair_decay_per_day"]) * 0.0) / float(d["despair_per_day"])))
	print("colonists=%d expected_debt=%.0f due_day=%d factory_payoff_day=%d idle_break_from_day=%d" % [n, total, due, pay_day, brk])
	quit()
