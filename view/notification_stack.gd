class_name NotificationStack
extends VBoxContainer
## U2: one compact top-right stack for toasts, hints and wave reports. Max MAX_VISIBLE items,
## newest on top, the rest collapse into a "+N" chip. Each item is one >= 64 px button: tap dismisses.
## API: push(text, kind, ttl), tick(real_delta), clear(). Kinds: info (6 s), wave (10 s), warn (20 s).

const MAX_VISIBLE := 2
const MAX_QUEUE := 12
const WIDTH := 300.0
const ITEM_H := 64.0
const TTL := {"info": 6.0, "wave": 10.0, "warn": 20.0}
const COLORS := {
	"info": Color(0.16, 0.2, 0.26, 0.92),
	"wave": Color(0.34, 0.2, 0.12, 0.94),
	"warn": Color(0.4, 0.14, 0.12, 0.95),
}
const ICONS := {"info": "i", "wave": "!", "warn": "!!"}

var suppressed := false:  ## true while a side sheet covers the top-right
	set(v):
		suppressed = v
		visible = not _items.is_empty() and not v
var _items: Array[Dictionary] = []  ## oldest first: {text, kind, left}


func _init() -> void:
	name = "NotificationStack"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.x = WIDTH
	add_theme_constant_override("separation", 4)


static func wave_report_text(r: Dictionary) -> String:
	var lost: Array = r.get("lost", [])
	var t := "Wave %d over: %d kills, %d lost, %d inmates down." % [r.get("wave", 0), r.get("kills", 0), lost.size(), r.get("colonist_deaths", 0)]
	if str(r.get("main_attack", "")) != "":
		t += " Main attack: %s." % r["main_attack"]
	return t


func push(text: String, kind: String = "info", ttl: float = -1.0) -> void:
	if text == "":
		return
	if not TTL.has(kind):
		kind = "info"
	if ttl <= 0.0:
		ttl = float(TTL[kind])
	for it in _items:
		if it["text"] == text:  # dedupe: refresh instead of stacking
			it["left"] = ttl
			it["kind"] = kind
			_rebuild()
			return
	_items.append({"text": text, "kind": kind, "left": ttl})
	while _items.size() > MAX_QUEUE:
		_items.pop_front()
	_rebuild()


func clear() -> void:
	_items.clear()
	_rebuild()


## Global rect the stack will occupy once laid out (the live rect lags a rebuild by a frame).
func expected_rect() -> Rect2:
	var h := visible_count() * (ITEM_H + 4.0) + (44.0 if _items.size() > MAX_VISIBLE else 0.0)
	return Rect2(global_position, Vector2(WIDTH, h))


func count() -> int:
	return _items.size()


func visible_count() -> int:
	return mini(_items.size(), MAX_VISIBLE)


func dismiss(text: String) -> void:
	for i in _items.size():
		if _items[i]["text"] == text:
			_items.remove_at(i)
			break
	_rebuild()


## Real-time delta (not sim time): items expire even while the game is paused.
func tick(delta: float) -> void:
	var changed := false
	for i in range(_items.size() - 1, -1, -1):
		_items[i]["left"] = float(_items[i]["left"]) - delta
		if float(_items[i]["left"]) <= 0.0:
			_items.remove_at(i)
			changed = true
	if changed:
		_rebuild()


func _rebuild() -> void:
	for ch in get_children():
		remove_child(ch)
		ch.queue_free()
	visible = not _items.is_empty() and not suppressed
	var n := _items.size()
	for k in mini(n, MAX_VISIBLE):
		var it: Dictionary = _items[n - 1 - k]
		var b := Button.new()
		b.text = "[%s] %s   x" % [ICONS[it["kind"]], it["text"]]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(WIDTH, ITEM_H)
		b.add_theme_font_size_override("font_size", 15)
		var sb := StyleBoxFlat.new()
		sb.bg_color = COLORS[it["kind"]]
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(8)
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, sb)
		var txt: String = it["text"]
		b.pressed.connect(func() -> void: dismiss(txt))
		add_child(b)
	if n > MAX_VISIBLE:
		var chip := Button.new()
		chip.text = "+%d more (tap to clear)" % (n - MAX_VISIBLE)
		chip.focus_mode = Control.FOCUS_NONE
		chip.custom_minimum_size = Vector2(WIDTH, 40)
		chip.add_theme_font_size_override("font_size", 14)
		chip.pressed.connect(clear)
		add_child(chip)
