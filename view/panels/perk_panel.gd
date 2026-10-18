class_name PerkPanel
extends GamePanel
## Perk tree: colonist selector, skill tabs, tiers of perk nodes with
## prerequisite lines, details + two-step "learn". Generic over data/perks.json:
## perks are grouped by `skill_level` into tiers, any count per tier.
## Reads sim state only; changes go through sim.learn_perk / sim.respec_perks.

const REASONS := {
	"level": "Skill level too low",
	"requires": "Previous perk required",
	"no_points": "No free points",
	"excluded": "Locked: a conflicting perk is chosen",
	"dead": "Colonist is dead",
	"already_learned": "Already learned",
	"unknown_perk": "Unknown perk",
}
const COL_LEARNED := Color(0.35, 0.75, 0.4)
const COL_AVAILABLE := Color(0.95, 0.8, 0.3)
const COL_LOCKED := Color(0.45, 0.45, 0.5)
const COL_EXCLUDED := Color(0.75, 0.3, 0.3)
const NODE_H := 72.0
const ROW_H := 104.0

var colonist_id := -1
var skill := ""
var selected_perk := ""
var _confirm := false
var _key := ""
var _tree: PerkTree


## Call before open(); picks which colonist to show (and the skill with free points).
func focus_colonist(cid: int, p_skill := "") -> void:
	colonist_id = cid
	skill = p_skill
	selected_perk = ""
	_confirm = false
	_key = ""


func build() -> void:
	var skills := _skill_ids()
	if colonist_id < 0 or sim.colonists.get_by_id(colonist_id) == null:
		colonist_id = -1
		for c in sim.colonists.list:
			if c.alive:
				colonist_id = c.id
				break
	_fix_skill()


func _fix_skill() -> void:
	var skills := _skill_ids()
	var c := sim.colonists.get_by_id(colonist_id)
	if skill == "" or not skills.has(skill):
		skill = skills[0] if not skills.is_empty() else ""
		if c != null:
			for s in skills:
				if sim.perks.points_available(c, s) > 0:
					skill = s
					break


func refresh() -> void:
	if sim == null:
		return
	_fix_skill()
	var c := sim.colonists.get_by_id(colonist_id)
	var key := "%d|%s|%s|%s|%d" % [colonist_id, skill, selected_perk, _confirm, sim.tick / 60]
	if c != null:
		for s in _skill_ids():
			key += "|%d.%d" % [c.skills.level(s) if c.skills else 0, sim.perks.points_available(c, s)]
		if c.perks != null:
			key += "|" + ",".join(c.perks.learned)
		key += "|" + str(sim.perks.can_respec(c))
	for o in sim.colonists.list:
		key += ("a" if o.alive else "d") + str(_total_points(o))
	if key == _key:
		return
	_key = key
	for ch in content.get_children():
		content.remove_child(ch)
		ch.queue_free()
	_build_content(c)


func _skill_ids() -> Array[String]:
	var out: Array[String] = []
	for s: String in sim.defs.skills["skills"]:
		out.append(s)
	return out


func _skill_label(s: String) -> String:
	return str(sim.defs.skills["skills"].get(s, {}).get("label", s))


func _total_points(c: Colonist) -> int:
	var n := 0
	for s in _skill_ids():
		n += sim.perks.points_available(c, s)
	return n


func _btn(parent: Control, text: String, min_size: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _select_colonist(cid: int) -> void:
	focus_colonist(cid, "")
	refresh()


func _select_skill(sid: String) -> void:
	skill = sid
	selected_perk = ""
	_confirm = false
	_key = ""
	refresh()


func _select_perk(pid: String) -> void:
	selected_perk = pid
	_confirm = false
	_key = ""
	refresh()


func _build_content(c: Colonist) -> void:
	var crow := HFlowContainer.new()
	crow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(crow)
	for o in sim.colonists.list:
		if not o.alive:
			continue
		var pts := _total_points(o)
		var b := _btn(crow, "%s%s" % [o.display_name, "\n*%d pt" % pts if pts > 0 else ""], Vector2(84, 64),
			_select_colonist.bind(o.id))
		b.add_theme_font_size_override("font_size", 16)
		if o.id == colonist_id:
			b.modulate = Color(0.8, 0.6, 1.0)
		elif pts > 0:
			b.modulate = COL_AVAILABLE
	if c == null:
		add_line("No colonists.")
		return
	var srow := HFlowContainer.new()
	srow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(srow)
	for s in _skill_ids():
		var pts := sim.perks.points_available(c, s)
		var b := _btn(srow, "%s\nlv.%d%s" % [_skill_label(s), c.skills.level(s), "  *%d" % pts if pts > 0 else ""],
			Vector2(84, 64), _select_skill.bind(s))
		b.add_theme_font_size_override("font_size", 12)
		if s == skill:
			b.modulate = Color(0.8, 0.6, 1.0)
		elif pts > 0:
			b.modulate = COL_AVAILABLE
	var free := sim.perks.points_available(c, skill)
	add_line("Points: %d  (skill %d)" % [free, c.skills.level(skill)], COL_AVAILABLE if free > 0 else Color.WHITE)
	_tree = PerkTree.new()
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_tree)
	_populate_tree(c)
	_build_details(c)
	_build_respec(c)


## "learned" | "available" | "excluded" | "locked".
func state_of_perk(c: Colonist, pid: String) -> String:
	if sim.perks.has(c, pid):
		return "learned"
	var r := sim.perks.can_learn(c, pid)
	if r == "":
		return "available"
	if r == "excluded":
		return "excluded"
	return "locked"


func _populate_tree(c: Colonist) -> void:
	var tiers := {}  # skill_level -> Array
	for pid in sim.perks.perks_of_skill(skill):
		var lv := int(sim.perks.perk_def(pid).get("skill_level", 1))
		if not tiers.has(lv):
			tiers[lv] = []
		tiers[lv].append(pid)
	var levels: Array = tiers.keys()
	levels.sort()
	var rows: Array = []
	var edges: Array = []
	for lv: int in levels:
		var ids: Array = tiers[lv]
		rows.append({"level": lv, "ids": ids})
		for pid: String in ids:
			var d := sim.perks.perk_def(pid)
			for r: String in d.get("requires", []):
				edges.append([r, pid])
			for r: String in d.get("requires_any", []):
				edges.append([r, pid])
	_tree.rows = rows
	_tree.edges = edges
	_tree.row_h = ROW_H
	_tree.node_h = NODE_H
	for row: Dictionary in rows:
		for pid: String in row["ids"]:
			var d := sim.perks.perk_def(pid)
			var st := state_of_perk(c, pid)
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.clip_text = true
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.add_theme_font_size_override("font_size", 14)
			b.text = "%s\nlv.%d%s" % [str(d.get("name", pid)), int(row["level"]),
				" [act]" if str(d.get("type", "")) == "active" else ""]
			var col := COL_LOCKED
			match st:
				"learned":
					col = COL_LEARNED
				"available":
					col = COL_AVAILABLE
				"excluded":
					col = COL_EXCLUDED
			var sb := StyleBoxFlat.new()
			sb.bg_color = col.darkened(0.6)
			sb.border_color = Color.WHITE if pid == selected_perk else col
			sb.set_border_width_all(4 if pid == selected_perk else 2)
			sb.set_corner_radius_all(6)
			sb.set_content_margin_all(4)
			for n in ["normal", "hover", "pressed", "focus", "disabled"]:
				b.add_theme_stylebox_override(n, sb)
			for n in ["font_color", "font_hover_color", "font_pressed_color"]:
				b.add_theme_color_override(n, col.lightened(0.45))
			b.pressed.connect(_select_perk.bind(pid))
			_tree.add_node(pid, b)
	_tree.relayout()


func _build_details(c: Colonist) -> void:
	if selected_perk == "" or sim.perks.perk_def(selected_perk).is_empty():
		add_line("Tap a perk to see its description.", Color(0.7, 0.7, 0.7))
		return
	var d := sim.perks.perk_def(selected_perk)
	var st := state_of_perk(c, selected_perk)
	add_line(str(d.get("name", selected_perk))).add_theme_font_size_override("font_size", 22)
	add_line(str(d.get("desc", "")))
	var dim := Color(0.75, 0.75, 0.8)
	add_line("Skill level needed: %d" % int(d.get("skill_level", 1)), dim)
	for r: String in d.get("requires", []):
		add_line("Requires: " + str(sim.perks.perk_def(r).get("name", r)), dim)
	var any: Array = d.get("requires_any", [])
	if not any.is_empty():
		var names: Array = any.map(func(r: String) -> String: return str(sim.perks.perk_def(r).get("name", r)))
		add_line("Requires one of: " + ", ".join(names), dim)
	for r: String in d.get("excludes", []):
		add_line("Excludes: " + str(sim.perks.perk_def(r).get("name", r)), Color(0.9, 0.55, 0.5))
	if str(d.get("type", "")) == "active":
		add_line("Active, cooldown %d s" % (int(d.get("cooldown_ticks", 0)) / Simulation.TICKS_PER_SECOND),
			Color(0.7, 0.85, 1.0))
	match st:
		"learned":
			add_line("Learned", COL_LEARNED)
		"available":
			var b := _btn(content, "Confirm learning?" if _confirm else "Learn", Vector2(0, 64), on_learn_pressed)
			b.modulate = COL_AVAILABLE
		_:
			var r := sim.perks.can_learn(c, selected_perk)
			add_line(str(REASONS.get(r, r)), COL_EXCLUDED if st == "excluded" else Color(0.85, 0.7, 0.5))


## Handler of the "learn" button: first tap arms the confirm, second tap learns.
func on_learn_pressed() -> bool:
	if not _confirm:
		_confirm = true
		_key = ""
		refresh()
		return false
	_confirm = false
	_key = ""
	var ok := sim.learn_perk(colonist_id, selected_perk)
	refresh()
	return ok


func on_respec_pressed() -> bool:
	var ok := sim.respec_perks(colonist_id)
	selected_perk = ""
	_key = ""
	refresh()
	return ok


func _build_respec(c: Colonist) -> void:
	var cost := sim.perks.respec_cost()
	var nm := str(sim.defs.items.get(str(cost["item"]), {}).get("name", cost["item"]))
	var b := _btn(content, "Reset (%d %s)" % [int(cost["count"]), nm], Vector2(0, 64), on_respec_pressed)
	b.disabled = not sim.perks.can_respec(c)


## Manual-layout container: tiers top to bottom, nodes spread evenly in a row,
## lines from each prerequisite (bottom centre) to the dependent perk (top centre).
class PerkTree extends Control:
	var rows: Array = []
	var edges: Array = []
	var row_h := 104.0
	var node_h := 72.0
	var _nodes := {}  # perk id -> Button

	func add_node(pid: String, b: Button) -> void:
		_nodes[pid] = b
		add_child(b)

	func _ready() -> void:
		resized.connect(relayout)

	func relayout() -> void:
		custom_minimum_size.y = maxf(rows.size() * row_h, row_h)
		var w := maxf(size.x, 64.0)
		for i in rows.size():
			var ids: Array = rows[i]["ids"]
			var n := ids.size()
			var gap := 8.0
			var nw := maxf(64.0, (w - gap * (n - 1)) / maxf(n, 1))
			var total := nw * n + gap * (n - 1)
			var x0 := (w - total) * 0.5
			for j in n:
				var b: Button = _nodes[ids[j]]
				b.position = Vector2(x0 + j * (nw + gap), i * row_h + (row_h - node_h) * 0.5)
				b.size = Vector2(nw, node_h)
		queue_redraw()

	func _draw() -> void:
		for e: Array in edges:
			if not _nodes.has(e[0]) or not _nodes.has(e[1]):
				continue
			var a: Button = _nodes[e[0]]
			var b: Button = _nodes[e[1]]
			draw_line(a.position + Vector2(a.size.x * 0.5, a.size.y),
				b.position + Vector2(b.size.x * 0.5, 0), Color(0.6, 0.6, 0.7, 0.8), 3.0)
