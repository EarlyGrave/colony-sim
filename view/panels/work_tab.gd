class_name WorkTab
extends Control
## Work-priority matrix: colonists (rows) x work types (columns).
## Tap a cell to cycle its priority: 3 -> 2 -> 1 -> off -> 4 -> 3 ...
## Standalone: call `bind(sim)` once; it listens to the sim bus and rebuilds itself.
## Reads sim state only; changes go through Simulation.set_work_priority().

const CELL_SIZE := Vector2(64, 64)
## Next priority after tapping (0 = off).
const CYCLE := {3: 2, 2: 1, 1: 0, 0: 4, 4: 3}

var sim: Simulation
var _grid: GridContainer
var _scroll: ScrollContainer
## colonist id -> {work type -> Button}
var buttons: Dictionary = {}


func _init() -> void:
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_scroll)
	_grid = GridContainer.new()
	_scroll.add_child(_grid)


func bind(p_sim: Simulation) -> void:
	sim = p_sim
	var bus: Object = sim.bus
	if not bus.work_priority_changed.is_connected(_on_changed):
		bus.work_priority_changed.connect(_on_changed)
	refresh()


func _exit_tree() -> void:
	if sim != null and sim.bus != null and sim.bus.work_priority_changed.is_connected(_on_changed):
		sim.bus.work_priority_changed.disconnect(_on_changed)


func _on_changed(_id: int, _type: String, _p: int) -> void:
	refresh()


## Rebuilds the matrix from sim state.
func refresh() -> void:
	for ch in _grid.get_children():
		_grid.remove_child(ch)
		ch.queue_free()
	buttons.clear()
	if sim == null:
		return
	var types: Array = sim.defs.work["types"].keys()
	_grid.columns = types.size() + 1
	_grid.add_child(_label(""))
	for t: String in types:
		_grid.add_child(_label(str(sim.defs.work["types"][t]["label"])))
	for c in sim.colonists.list:
		if not c.alive:
			continue
		_grid.add_child(_label(c.display_name))
		var row: Dictionary = {}
		for t: String in types:
			var b := Button.new()
			b.custom_minimum_size = CELL_SIZE
			b.text = priority_text(c.skills.priority(t))
			b.pressed.connect(_on_cell_pressed.bind(c.id, t))
			_grid.add_child(b)
			row[t] = b
		buttons[c.id] = row


static func priority_text(p: int) -> String:
	return "-" if p <= 0 else str(p)


func _on_cell_pressed(colonist_id: int, work_type: String) -> void:
	var c := sim.colonists.get_by_id(colonist_id)
	if c == null:
		return
	sim.set_work_priority(colonist_id, work_type, int(CYCLE[c.skills.priority(work_type)]))


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(CELL_SIZE.x, 32)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l
