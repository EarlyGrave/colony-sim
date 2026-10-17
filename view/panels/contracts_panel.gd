class_name ContractsPanel
extends GamePanel
## Warden quota contracts: accept / decline / deliver. Reads sim state only.

var _sig := ""


func refresh() -> void:
	if sim == null or sim.contracts == null:
		return
	var cs := sim.contracts
	var sig := "%d|%.2f|%d|%d" % [cs.list.size(), cs.anger, sim.items.count_stored("refined_essence"), sim.items.count_stored("machine_parts")]
	for c in cs.list:
		sig += str(c["state"])
	if sig == _sig:
		return
	_sig = sig
	for ch in content.get_children():
		content.remove_child(ch)
		ch.queue_free()
	add_line("Гнев надзирателей: %.1f" % cs.anger, Color(1.0, 0.5, 0.4))
	var any := false
	for c in cs.open_contracts():
		any = true
		var need := "%d эссенции" % int(c["essence"])
		if int(c["parts"]) > 0:
			need += ", %d деталей" % int(c["parts"])
		add_line("%s: %s" % [c["name"], need], Color(1.0, 0.85, 0.4))
		var cid := int(c["id"])
		if c["state"] == "offered":
			add_line("Ответить до дня %d. Срок после принятия: %d дн." % [int(c["expire_day"]), int(c["deadline_days"])])
			var row := HBoxContainer.new()
			content.add_child(row)
			_button(row, "Принять", func() -> void: sim.accept_contract(cid))
			_button(row, "Отказать", func() -> void: sim.decline_contract(cid))
		else:
			add_line("Сдать до дня %d" % int(c["deadline_day"]))
			var b := _button(content, "Сдать", func() -> void: sim.deliver_contract(cid))
			b.disabled = not cs.can_deliver(c)
	if not any:
		add_line("Новых требований нет.", Color(0.7, 0.7, 0.7))


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(120, 64)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b
