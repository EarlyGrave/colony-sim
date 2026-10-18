class_name NewGameDialog
extends PanelContainer
## New-game dialog: three big "sentence" cards (difficulty presets) and a Start button.
## Touch-first: every button >= 72 px. Selection is saved in MetaState.preset.

signal start_requested(opts: Dictionary)

const BTN := Vector2(0, 88)

var meta: MetaState
var select_count := 0  # times a card changed the stored preset (tests)
var cards: Dictionary = {}  # preset id -> Button
var start_button: Button
var _on_save: Callable


func _init(p_meta: MetaState, on_save: Callable = Callable()) -> void:
	meta = p_meta
	_on_save = on_save
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	var title := Label.new()
	title.text = "Choose your sentence"
	box.add_child(title)
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
	start_button = Button.new()
	start_button.custom_minimum_size = BTN
	start_button.focus_mode = Control.FOCUS_NONE
	start_button.text = "Start"
	start_button.pressed.connect(func() -> void: start_requested.emit(meta.make_opts()))
	box.add_child(start_button)
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
	for id: String in cards:
		cards[id].modulate = Color(1, 0.9, 0.5) if id == meta.preset else Color.WHITE
