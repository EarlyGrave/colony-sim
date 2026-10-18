class_name LettersPanel
extends GamePanel
## Shows the last letters from LetterLog (newest first).

signal show_cell_requested(cell: Vector2i)

signal panel_requested(panel_id: String, colonist_id: int, skill: String)

var letters: LetterLog
var _shown := -1


func _init() -> void:
	super()
	title = "Letters"


func bind_log(l: LetterLog) -> void:
	letters = l


func refresh() -> void:
	if letters == null:
		return
	var sig := letters.entries.size() + letters.unread * 1000
	if sig == _shown:
		return
	_shown = sig
	for ch in content.get_children():
		content.remove_child(ch)
		ch.queue_free()
	if letters.entries.is_empty():
		add_line("No letters yet.", Color(0.7, 0.7, 0.7))
	for e: Dictionary in letters.entries:
		var col := Color.WHITE
		match e["level"]:
			"bad":
				col = Color(1.0, 0.5, 0.45)
			"warn":
				col = Color(1.0, 0.85, 0.4)
		var day := 0
		var hour := 0
		if sim:
			day = int(e["tick"]) / sim.ticks_per_day + 1
			hour = int(e["tick"]) % sim.ticks_per_day * 24 / sim.ticks_per_day
		var l := add_line("d%d %02d:00  %s" % [day, hour, e["text"]], col)
		if e.has("panel"):
			var pid: String = e["panel"]
			var cid: int = int(e.get("colonist_id", -1))
			var sk: String = str(e.get("skill", ""))
			var pb := Button.new()
			pb.text = "Open"
			pb.custom_minimum_size = Vector2(0, 64)
			pb.focus_mode = Control.FOCUS_NONE
			pb.pressed.connect(func() -> void: panel_requested.emit(pid, cid, sk))
			content.add_child(pb)
		if e.has("cell"):
			var cell: Vector2i = e["cell"]
			var b := Button.new()
			b.text = "Show"
			b.custom_minimum_size = Vector2(0, 64)
			b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(func() -> void: show_cell_requested.emit(cell))
			content.add_child(b)
