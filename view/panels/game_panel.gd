class_name GamePanel
extends PanelContainer
## Base class for side panels opened from the HUD panel bar.
## (Not named `Panel`: that is a built-in Godot class.)
##
## Subclass, override `build()` (called once on open) and optionally
## `refresh()` (called ~4 times per second while open). Read sim state only;
## player intent must go through `Simulation` command methods.

signal close_requested()

var sim: Simulation
var title := ""
var content: VBoxContainer
var _title_label: Label


func _init() -> void:
	var outer := VBoxContainer.new()
	add_child(outer)
	var head := HBoxContainer.new()
	outer.add_child(head)
	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 22)
	head.add_child(_title_label)
	var close := Button.new()
	close.text = "X"
	close.custom_minimum_size = Vector2(64, 64)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: close_requested.emit())
	head.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)


func open(p_sim: Simulation) -> void:
	sim = p_sim
	_title_label.text = title
	build()
	refresh()


## Override: create the static widgets inside `content`.
func build() -> void:
	pass


## Override: update widgets from `sim`.
func refresh() -> void:
	pass


func set_title(t: String) -> void:
	title = t
	if _title_label:
		_title_label.text = t


func add_line(text: String, color := Color.WHITE) -> Label:
	return InspectorSection.add_line(content, text, color)
