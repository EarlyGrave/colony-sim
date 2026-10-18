class_name SplitterPanel
extends PanelContainer
## Bottom sheet for a belt node (region L2). Smart splitter: Left/Front/Right buttons, each
## opening an item picker. Other kinds: read-only info. All buttons >= 64 px. Sim reads only;
## changes go through Simulation.set_splitter_filter.

signal closed

const BTN := Vector2(112, 64)
const ARROWS: Array[String] = ["^", ">", "v", "<"]  ## N E S W
const INFO: Dictionary = {
	1: "Splitter: shares items between its outputs in turn.",
	3: "Priority splitter: sends to the front first, then left, then right.",
	4: "Merger: joins back, left and right inputs into one output.",
}

var sim: Simulation
var cell := Vector2i(-1, -1)
var _box: VBoxContainer
var _slot := -1
var force_kind := -1  ## screenshots only: show this kind's sheet before L1 nodes exist


func _init() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	grow_horizontal = Control.GROW_DIRECTION_END
	offset_left = 88.0
	visible = false
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	add_child(_box)


## Opens the sheet for the node at `c`. `bottom` is the y inset to keep clear of the toolbars.
func open(p_sim: Simulation, c: Vector2i, bottom: float) -> void:
	sim = p_sim
	cell = c
	_slot = -1
	offset_bottom = -bottom
	visible = true
	_show_slots()


func close() -> void:
	visible = false
	closed.emit()


static func slot_label(flow_dir: int, slot: int) -> String:
	var d: int = (flow_dir + int([3, 0, 1][slot])) % 4
	return "%s %s" % [["Left", "Front", "Right"][slot], ARROWS[d]]


func _clear() -> void:
	for ch in _box.get_children():
		_box.remove_child(ch)
		ch.free()


func _btn(text: String, cb: Callable, parent: Control = null) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = BTN
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	(parent if parent != null else _box).add_child(b)
	return b


func _title(text: String) -> void:
	var l := Label.new()
	l.text = text
	_box.add_child(l)


func _show_slots() -> void:
	_clear()
	var kind := force_kind if force_kind >= 0 else sim.get_belt_node_kind(cell)
	var d := maxi(0, sim.logistics.dir_at(cell))
	if kind == 2:
		_title("Smart splitter: pick what goes out of each side")
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_box.add_child(row)
		for slot in 3:
			var b := _btn("%s\n%s" % [slot_label(d, slot), sim.get_splitter_filter(cell, slot)], _open_picker.bind(slot), row)
			b.custom_minimum_size = Vector2(140, 64)
			b.name = "slot%d" % slot
	else:
		_title(str(INFO.get(kind, "Belt node.")))
	_btn("Close", close)


func _open_picker(slot: int) -> void:
	_slot = slot
	_clear()
	_title("%s output" % slot_label(maxi(0, sim.logistics.dir_at(cell)), slot))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(480, 64 * 2 + 6)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.custom_minimum_size.x = 464
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	var ids: Array = ["any", "overflow"]
	var items: Array = sim.defs.items.keys()
	items.sort()
	ids.append_array(items)
	var cur := sim.get_splitter_filter(cell, slot)
	for id: String in ids:
		var nm: String = "Any" if id == "any" else ("Overflow" if id == "overflow" else str(sim.defs.items[id].get("name", id)))
		var b := _btn(nm if id != cur else "[%s]" % nm, _pick.bind(id), grid)
		b.custom_minimum_size = Vector2(88, 64)
		b.clip_text = true
		b.name = "pick_" + id
	_btn("Back", _show_slots)


func _pick(id: String) -> void:
	sim.set_splitter_filter(cell, _slot, id)
	_show_slots()
