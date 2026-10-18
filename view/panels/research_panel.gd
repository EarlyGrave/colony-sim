class_name ResearchPanel
extends GamePanel
## Tech tree: one section per tier (T0..T3) stacked vertically, cards wrap to the panel width, >= 64 px high.
## Tap a card = queue/unqueue; each tier has an audit strip with a Deliver button.
## Reads sim state only (through ResearchAdapter) and calls sim.queue_research / sim.deliver_audit.

const COL_DONE := Color(0.35, 0.75, 0.4)
const COL_AVAILABLE := Color(0.95, 0.8, 0.3)
const COL_ACTIVE := Color(0.4, 0.7, 1.0)
const COL_LOCKED := Color(0.45, 0.45, 0.5)
const CARD_MIN := Vector2(146, 72)
const COL_W := 176.0
const TIERS := 4

var adapter: ResearchAdapter
var _key := ""
var _holder: VBoxContainer


func build() -> void:
	adapter = ResearchAdapter.new(sim)
	_holder = VBoxContainer.new()
	_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_holder.add_theme_constant_override("separation", 10)
	content.add_child(_holder)


func refresh() -> void:
	if sim == null or adapter == null:
		return
	var key := adapter.signature()
	if key == _key:
		return
	_key = key
	for ch in _holder.get_children():
		_holder.remove_child(ch)
		ch.queue_free()
	for t in TIERS:
		_holder.add_child(_build_column(t))


func _build_column(tier: int) -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	var head := Label.new()
	head.text = "Tier %d" % tier
	head.add_theme_font_size_override("font_size", 20)
	col.add_child(head)
	col.add_child(_build_audit(tier))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	for id in adapter.tech_ids(tier):
		flow.add_child(_build_card(id))
	col.add_child(flow)
	return col


func _build_audit(tier: int) -> Control:
	var box := VBoxContainer.new()
	box.name = "Audit%d" % tier
	var parts := adapter.audit_parts(tier)
	if parts.is_empty():
		var l0 := Label.new()
		l0.text = "Audit: not required" if adapter.audit_done(tier) else "Audit T%d: pending" % tier
		l0.add_theme_font_size_override("font_size", 14)
		l0.modulate = Color(0.7, 0.7, 0.7)
		box.add_child(l0)
		return box
	var done := adapter.audit_done(tier)
	var delivered := adapter.audit_delivered(tier)
	var lines: Array[String] = []
	for item: String in parts:
		lines.append("%s %d/%d" % [adapter.item_name(item), mini(int(delivered.get(item, 0)), int(parts[item])), int(parts[item])])
	var l := Label.new()
	l.text = ("Audit done" if done else "Audit parts") + "\n" + "\n".join(lines)
	l.add_theme_font_size_override("font_size", 14)
	l.modulate = COL_DONE if done else Color.WHITE
	box.add_child(l)
	if not done:
		var b := Button.new()
		b.name = "Deliver%d" % tier
		b.text = "Deliver"
		b.custom_minimum_size = Vector2(COL_W, 64)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(on_deliver_pressed.bind(tier))
		box.add_child(b)
	return box


func _build_card(id: String) -> Button:
	var st := adapter.state_of(id)
	var d := adapter.tech(id)
	var col := COL_LOCKED
	match st:
		"done":
			col = COL_DONE
		"available", "queued":
			col = COL_AVAILABLE
		"active":
			col = COL_ACTIVE
	var b := Button.new()
	b.name = "Tech_" + id
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = CARD_MIN
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.clip_text = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 14)
	var lines: Array[String] = []
	lines.append(("[x] " if st == "done" else "") + str(d.get("name", id)))
	if st != "done":
		lines.append(adapter.cost_text(id))
	if float(d.get("waste_mult", 1.0)) > 1.0:
		lines.append("adds %d%% waste" % roundi((float(d["waste_mult"]) - 1.0) * 100.0))
	match st:
		"locked":
			lines.append("Locked: " + adapter.lock_reason(id))
		"active":
			lines.append("Researching %d%%" % roundi(adapter.progress_frac(id) * 100.0))
		"queued":
			lines.append("Queued #%d" % adapter.queue_pos(id))
		"done":
			pass
	b.text = "\n".join(lines)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col.darkened(0.65)
	sb.border_color = col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(6)
	if st == "active":  # progress shown as a growing bottom strip
		sb.border_width_bottom = int(2 + 10 * adapter.progress_frac(id))
	for n in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(n, sb)
	for n in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(n, col.lightened(0.5))
	b.pressed.connect(on_tech_pressed.bind(id))
	return b


## Tap on a card: queue it, or unqueue when already queued/active. Locked/done: no-op.
func on_tech_pressed(id: String) -> bool:
	var st := adapter.state_of(id)
	if st == "locked" or st == "done":
		return false
	var ok := adapter.set_queued(id, st == "available")
	_key = ""
	refresh()
	return ok


func on_deliver_pressed(tier: int) -> bool:
	var ok := adapter.deliver(tier)
	_key = ""
	refresh()
	return ok


## Thin read/command layer over `sim.research` (R2a). Audit part lists come from
## data/milestones.json when R2b provides it; `deliver_audit` is called only if the sim has it.
class ResearchAdapter extends RefCounted:
	var sim: Simulation
	var _milestones: Dictionary = {}

	func _init(p_sim: Simulation) -> void:
		sim = p_sim
		var path := "res://data/milestones.json"
		if FileAccess.file_exists(path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				var dd: Dictionary = parsed
				if dd.has("tiers") and dd["tiers"] is Dictionary:
					dd = dd["tiers"]
				for k: String in dd:
					if not k.begins_with("_"):
						_milestones[k] = dd[k]

	func done_list() -> Array:
		return sim.research.done

	func queue_list() -> Array:
		return sim.research.queue

	func tech(id: String) -> Dictionary:
		return sim.research.tech(id)

	func tech_ids(tier: int) -> Array[String]:
		var out: Array[String] = []
		for id: String in sim.defs.research:
			if int(sim.defs.research[id].get("tier", 0)) == tier:
				out.append(id)
		out.sort()
		return out

	func tier_count() -> int:
		return sim.defs.research.size()

	func audit_parts(tier: int) -> Dictionary:
		var m: Dictionary = _milestones.get(str(tier), {})
		return m.get("parts", {})

	func audit_delivered(tier: int) -> Dictionary:
		var d: Variant = sim.get("milestones")
		if d != null and "delivered" in d:
			var dd: Dictionary = d.delivered
			return dd.get(str(tier), dd.get(tier, {}))
		return {}

	func audit_done(tier: int) -> bool:
		return sim.research.tier_unlocked(tier)

	func item_name(item: String) -> String:
		return str(sim.defs.items.get(item, {}).get("name", item))

	## "done" | "active" | "queued" | "available" | "locked".
	func state_of(id: String) -> String:
		var r := sim.research
		if r.is_done(id):
			return "done"
		if r.lock_reason(id) != "":
			return "locked"
		if r.active() == id:
			return "active"
		if r.queue.has(id):
			return "queued"
		return "available"

	func lock_reason(id: String) -> String:
		var why := sim.research.lock_reason(id)
		if why.begins_with("needs "):
			var p := why.substr(6)
			return "needs " + str(sim.research.tech(p).get("name", p))
		return why

	func queue_pos(id: String) -> int:
		return sim.research.queue.find(id) + 1

	func progress_frac(id: String) -> float:
		return sim.research.fraction(id)

	func cost_text(id: String) -> String:
		var c: Dictionary = tech(id).get("cost", {})
		var hours := int(round(float(sim.research.bench_ticks(id)) / float(sim.ticks_per_day) * 24.0))
		var s := "%dd %dh" % [hours / 24, hours % 24]
		if int(c.get("essence", 0)) > 0:
			s += ", %d essence" % int(c["essence"])
			if not sim.research.can_afford(id) and state_of(id) != "done":
				s += " (short)"
		return s

	func set_queued(id: String, on: bool) -> bool:
		return sim.queue_research(id, on)

	func deliver(tier: int) -> bool:
		if sim.has_method("deliver_audit"):
			return bool(sim.call("deliver_audit", tier))
		return false

	## Cheap change detector for refresh().
	func signature() -> String:
		var r := sim.research
		var s := ",".join(r.done) + "|" + ",".join(r.queue) + "|" + str(r.audit_tiers)
		for k: String in r.progress.keys():
			s += "%s%d" % [k, int(float(r.progress[k]) / 20.0)]
		s += "|" + JSON.stringify(audit_delivered(2)) + JSON.stringify(audit_delivered(3))
		s += "|" + str(sim.items.count_stored(str(sim.defs.balance["research"]["essence_item"])) / 5)
		return s
