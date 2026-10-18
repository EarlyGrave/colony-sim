class_name NewGameDialog
extends PanelContainer
## New-game dialog: three big "sentence" cards (difficulty presets) and a Start button.
## Touch-first: every button >= 72 px. Selection is saved in MetaState.preset.

signal start_requested(opts: Dictionary)

const BTN := Vector2(0, 88)
const PAD := 20  # region F5: inner margin (px)

var meta: MetaState
var select_count := 0  # times a card changed the stored preset (tests)
var cards: Dictionary = {}  # preset id -> Button
var start_button: Button
var tutorial_button: Button  # region R5X
var _on_save: Callable


func _init(p_meta: MetaState, on_save: Callable = Callable()) -> void:
	meta = p_meta
	_on_save = on_save
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := StyleBoxFlat.new()  # region R5X: opaque backdrop so the HUD does not show through
	bg.bg_color = Color(0.07, 0.07, 0.09, 0.97)
	add_theme_stylebox_override("panel", bg)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var pad := MarginContainer.new()  # region F5: inner margin, the title no longer hugs the screen edge
	for side in ["left", "top", "right", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, PAD)
	pad.name = "Pad"
	add_child(pad)
	pad.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	var title := Label.new()
	title.text = "Choose your sentence"
	box.add_child(title)
	var top := HBoxContainer.new()  # region R5X: Start + tutorial toggle stay visible without scrolling
	top.add_theme_constant_override("separation", 10)
	box.add_child(top)
	tutorial_button = Button.new()
	tutorial_button.custom_minimum_size = BTN
	tutorial_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tutorial_button.focus_mode = Control.FOCUS_NONE
	tutorial_button.toggle_mode = true
	tutorial_button.button_pressed = meta.tutorial
	tutorial_button.toggled.connect(func(on: bool) -> void:
		meta.tutorial = on
		_refresh())
	top.add_child(tutorial_button)
	start_button = Button.new()
	start_button.custom_minimum_size = BTN
	start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_button.focus_mode = Control.FOCUS_NONE
	start_button.text = "Start"
	start_button.pressed.connect(func() -> void:
		meta.launched = true
		if _on_save.is_valid():
			_on_save.call(meta)
		var o := meta.make_opts()
		if meta.tutorial:
			o["tutorial"] = true
		start_requested.emit(o))
	top.add_child(start_button)
	var presets: Dictionary = meta.defs.presets["presets"]
	for id: String in meta.defs.presets["order"]:
		var b := Button.new()
		b.custom_minimum_size = BTN
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = card_text(presets[id])
		b.pressed.connect(_select.bind(id))
		box.add_child(b)
		cards[id] = b
	_refresh()


static func card_text(p: Dictionary) -> String:
	return "%s\n%s\nRaids x%.2f   Waste x%.2f   Debt x%.2f" % [
		str(p["name"]), str(p["sentence"]), float(p["wave_strength_mult"]),
		float(p["waste_mult"]), float(p["starting_debt_mult"])]


func _select(id: String) -> void:
	if meta.preset != id:
		meta.preset = id
		select_count += 1
		if _on_save.is_valid():
			_on_save.call(meta)
	_refresh()


func _refresh() -> void:
	tutorial_button.text = "Warden's Orientation (tutorial): %s" % ("ON" if meta.tutorial else "OFF")  # region R5X
	for id: String in cards:
		cards[id].modulate = Color(1, 0.9, 0.5) if id == meta.preset else Color.WHITE
