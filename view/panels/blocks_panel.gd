class_name BlocksPanel
extends GamePanel
## Cell blocks side sheet: one row per block (members, Standing bar, trend, leaning), plus informant and
## stash rows. Tap a row = highlight members (signal `members_highlighted`, the HUD selects the next one).
## Reads sim.blocks / sim.contraband / sim.quests only.

signal members_highlighted(ids: Array)

const ROW_H := 64.0
const NOTIFY_STEP := 10.0
const PATH_NAMES := {"submit": "Submit", "fight": "Fight", "escape": "Escape"}

var _sig := ""
var _trend: Dictionary = {}  # block id -> last signed change
var _last: Dictionary = {}  # block id -> standing before the last change
var _tap: Dictionary = {}  # block id -> cycle index
var _bound: BlockSystem = null


func build() -> void:
	_bind()


func _bind() -> void:
	if sim == null or sim.blocks == null or sim.blocks == _bound:
		return
	_bound = sim.blocks
	for b: String in sim.blocks.standing:
		_last[b] = sim.blocks.standing[b]
	if not sim.bus.block_standing_changed.is_connected(_on_changed):
		sim.bus.block_standing_changed.connect(_on_changed)


func _exit_tree() -> void:
	if sim != null and sim.bus != null and sim.bus.block_standing_changed.is_connected(_on_changed):
		sim.bus.block_standing_changed.disconnect(_on_changed)


func _on_changed(b: String, v: float) -> void:
	_trend[b] = v - float(_last.get(b, v))
	_last[b] = v
	_sig = ""
	if is_inside_tree() and content != null:
		refresh()


static func arrow(delta: float) -> String:
	if delta > 0.05:
		return "^"
	if delta < -0.05:
		return "v"
	return "-"


## Short notification text when Standing moved >= NOTIFY_STEP between two readings, else "".
static func notice_text(block_name: String, old: float, now: float) -> String:
	if absf(now - old) < NOTIFY_STEP:
		return ""
	return "%s Standing %s to %d" % [block_name, "up" if now > old else "down", roundi(now)]


## "Submit" / "Fight" / "Escape" once Q14 has opened, else "".
static func leaning_for(sim_ref: Simulation, b: String) -> String:
	if sim_ref == null or sim_ref.quests == null or sim_ref.blocks == null:
		return ""
	if sim_ref.quests.state("q14") == "idle":
		return ""
	var lean: Dictionary = sim_ref.blocks.cfg.get("leaning", {}).get(b, {})
	for p: String in ["submit", "fight", "escape"]:
		if int(lean.get(p, 0)) > 0:
			return PATH_NAMES[p]
	return "Undecided"


## After Q15 "Roll Call" (clue_our_dead): the creatures were inmates once.
static func creatures_line(sim_ref: Simulation) -> String:
	if sim_ref == null or sim_ref.quests == null or not sim_ref.quests.flag("clue_our_dead"):
		return ""
	return "Creatures: former inmates"


func members_of(b: String) -> Array:
	var out: Array = []
	if sim == null or sim.blocks == null:
		return out
	for c: Colonist in sim.colonists.list:
		if c.alive and sim.blocks.block_of(c) == b:
			out.append(c.id)
	return out


func row_text(b: String) -> String:
	var bs := sim.blocks
	var nm := str(bs.cfg["blocks"][b].get("name", b))
	var s := "%s (%d)   %d %s" % [nm, members_of(b).size(), roundi(bs.standing_of(b)), arrow(float(_trend.get(b, 0.0)))]
	var lean := leaning_for(sim, b)
	if lean != "":
		s += "   leans " + lean
	return s


func refresh() -> void:
	if sim == null or sim.blocks == null:
		return
	_bind()
	var parts: Array = []
	var ids: Array = sim.blocks.cfg.get("blocks", {}).keys()
	ids.sort()
	for b: String in ids:
		parts.append([b, roundi(sim.blocks.standing_of(b)), members_of(b).size(), _trend.get(b, 0.0), leaning_for(sim, b)])
	var cb := sim.contraband
	parts.append([creatures_line(sim)])
	parts.append([sim.blocks.informant_id(), cb.stash_total() if cb != null else -1, cb.suspicion if cb != null else -1.0])
	var sig := str(parts)
	if sig == _sig:
		return
	_sig = sig
	for ch in content.get_children():
		content.remove_child(ch)
		ch.queue_free()
	if not sim.blocks.is_enabled():
		_info_row("No cell blocks on this map.")
		return
	for b: String in ids:
		_add_row(b)
	_add_info_rows()


func _add_row(b: String) -> void:
	var box := VBoxContainer.new()
	box.name = "Row_" + b
	content.add_child(box)
	var btn := Button.new()
	btn.text = row_text(b)
	btn.custom_minimum_size = Vector2(64, ROW_H)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.clip_text = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 16)
	btn.pressed.connect(func() -> void: highlight(b))
	box.add_child(btn)
	var bar := ProgressBar.new()
	var st := sim.blocks.standing_of(b)
	bar.max_value = 100.0
	bar.value = st
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	bar.modulate = Color(0.9, 0.4, 0.3) if st < 30.0 else (Color(0.4, 0.9, 0.5) if st > 70.0 else Color(0.9, 0.8, 0.4))
	box.add_child(bar)


func _add_info_rows() -> void:
	var inf := sim.colonists.get_by_id(sim.blocks.informant_id())
	var t := "Informant: " + (inf.display_name if inf != null and inf.alive else "none yet")
	if inf != null and inf.alive and sim.quests != null:
		var mod: Variant = sim.quests._modules.get("q13_informant")
		var reports := int(mod.reports) if mod != null else 0
		t = "Reports: %d, fee x%.1f (%s)" % [reports, sim.quests.mod("petition_fee_mult"), inf.display_name]
	_info_row(t)
	if creatures_line(sim) != "":  # region RV
		_info_row(creatures_line(sim))
	var cb := sim.contraband
	if cb != null and cb.is_enabled():
		_info_row("Stash: %d, suspicion %d" % [cb.stash_total(), roundi(cb.suspicion)])


func _info_row(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
	l.custom_minimum_size.y = ROW_H
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(l)


## Tap on a block row: cycles through its living members.
func highlight(b: String) -> void:
	var ids := members_of(b)
	if ids.is_empty():
		return
	var i := int(_tap.get(b, 0)) % ids.size()
	_tap[b] = i + 1
	members_highlighted.emit([ids[i]])
