extends InspectorSection
## Essence debt of the selected prisoner: pay, daily quota, payoff choice.


func _init() -> void:
	title = "Debt"


func applies(sim: Simulation, target: Dictionary) -> bool:
	var c: Colonist = target.get("colonist")
	return c != null and sim.debt != null and sim.debt.state_of(c) != null


func build(sim: Simulation, target: Dictionary, box: VBoxContainer) -> void:
	var c: Colonist = target["colonist"]
	var st := sim.debt.state_of(c)
	add_line(box, "Debt: %d / %d essence" % [st.remaining(), st.total])
	add_bar(box, float(st.paid) / maxf(1.0, float(st.total)), Color(0.5, 0.4, 0.9))
	if st.remaining() > 0:
		var late := sim.debt.is_overdue(c)
		add_line(box, "Due: day %d%s" % [st.due_day, " (overdue)" if late else ""],
				Color(0.9, 0.4, 0.3) if late else Color.WHITE)
		add_line(box, "Despair: %d / 100" % roundi(st.despair))
		add_line(box, "Auto-pay: %d per day" % st.quota)
		var row := HBoxContainer.new()
		box.add_child(row)
		_btn(row, "Pay 10", func() -> void: sim.pay_debt(c.id, 10))
		_btn(row, "All", func() -> void: sim.pay_debt(c.id, st.remaining()))
		var row2 := HBoxContainer.new()
		box.add_child(row2)
		_btn(row2, "Quota −", func() -> void: sim.set_quota(c.id, maxi(0, st.quota - 1)))
		_btn(row2, "Quota +", func() -> void: sim.set_quota(c.id, st.quota + 1))
	elif st.pending_choice:
		add_line(box, "Debt paid! Choose a fate.", Color(0.4, 0.9, 0.4))
		var row3 := HBoxContainer.new()
		box.add_child(row3)
		_btn(row3, "Stay", func() -> void: sim.choose_payoff(c.id, true))
		_btn(row3, "Leave the planet", func() -> void: sim.choose_payoff(c.id, false))
	elif st.outcome == "stayed":
		add_line(box, "Free colonist.", Color(0.4, 0.9, 0.4))


func _btn(row: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(64, 64)
	b.pressed.connect(cb)
	row.add_child(b)
