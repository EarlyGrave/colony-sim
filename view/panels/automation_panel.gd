class_name AutomationPanel
extends PanelContainer
## Touch toolbar for belts and machines (region A2d). Buttons are >= 64 px.
## Also holds the pure path helpers used by GameController's belt tool.

signal tool_picked(tool_id: String)  ## "belt", "belt_remove", "belt_rotate", "" (none) or a machine id
signal undo_pressed

const MACHINES: Array = [
	["miner", "Miner"], ["smelter", "Smelter"], ["assembler", "Assembler"],
	["storage_in", "Store In"], ["storage_out", "Store Out"],
]
const BTN := Vector2(112, 64)
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

var _group := ButtonGroup.new()
var _buttons := {}
var _machine_row: HBoxContainer


func _init() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	_machine_row = HBoxContainer.new()
	_machine_row.add_theme_constant_override("separation", 6)
	_machine_row.visible = false
	box.add_child(_machine_row)
	for m: Array in MACHINES:
		_add(_machine_row, str(m[0]), str(m[1]))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	_add(row, "belt", "Belt")
	_add(row, "belt_remove", "Remove")
	_add(row, "belt_rotate", "Rotate")
	var mb := Button.new()
	mb.text = "Machines"
	mb.toggle_mode = true
	mb.custom_minimum_size = BTN
	mb.focus_mode = Control.FOCUS_NONE
	mb.toggled.connect(func(on: bool) -> void: _machine_row.visible = on)
	row.add_child(mb)
	var ub := Button.new()
	ub.text = "Undo"
	ub.custom_minimum_size = BTN
	ub.focus_mode = Control.FOCUS_NONE
	ub.pressed.connect(func() -> void: undo_pressed.emit())
	row.add_child(ub)


func _add(parent: Control, id: String, text: String) -> void:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = _group
	b.custom_minimum_size = BTN
	b.focus_mode = Control.FOCUS_NONE
	b.toggled.connect(func(on: bool) -> void:
		if on:
			tool_picked.emit(id))
	parent.add_child(b)
	_buttons[id] = b


## Deselects every button (another tool was chosen elsewhere).
func clear_selection() -> void:
	var cur := _group.get_pressed_button()
	if cur != null:
		cur.set_pressed_no_signal(false)


## Extends a Manhattan-snapped path towards `target` one 4-neighbour step at a
## time (x first, then y). Stepping back onto the previous cell pops it.
static func extend_path(path: Array[Vector2i], target: Vector2i) -> void:
	if path.is_empty():
		path.append(target)
		return
	var guard := 4096
	while path[-1] != target and guard > 0:
		guard -= 1
		var cur := path[-1]
		var step := Vector2i(signi(target.x - cur.x), 0) if cur.x != target.x else Vector2i(0, signi(target.y - cur.y))
		var nxt := cur + step
		var idx := path.find(nxt)
		if idx >= 0:
			path.resize(idx + 1)  # retrace or loop back: truncate to that cell
		else:
			path.append(nxt)


## Direction index (0=N,1=E,2=S,3=W) of the last step; `fallback` for one cell.
static func path_last_dir(path: Array[Vector2i], fallback: int) -> int:
	if path.size() < 2:
		return fallback
	var d := DIRS.find(path[-1] - path[-2])
	return d if d >= 0 else fallback
