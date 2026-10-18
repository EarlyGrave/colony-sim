class_name ResearchPanel
extends GamePanel
## Tech tree: one column per tier (T0..T3), horizontal scroll, node cards >= 64 px high.
## Tap a card = queue/unqueue; each tier has an audit strip with a Deliver button.
## Reads sim state only (through ResearchAdapter) and calls sim.queue_research / sim.deliver_audit.

const COL_DONE := Color(0.35, 0.75, 0.4)
const COL_AVAILABLE := Color(0.95, 0.8, 0.3)
const COL_ACTIVE := Color(0.4, 0.7, 1.0)
const COL_LOCKED := Color(0.45, 0.45, 0.5)
const CARD_MIN := Vector2(160, 96)
const COL_W := 176.0
const TIERS := 4

var adapter: ResearchAdapter
var _key := ""
var _holder: HBoxContainer


func build() -> void:
	adapter = ResearchAdapter.new(sim)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 820)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	_holder = HBoxContainer.new()
	_holder.add_theme_constant_override("separation", 8)
	scroll.add_child(_holder)


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
	col.custom_minimum_size = Vector2(COL_W, 0)
	col.add_theme_constant_override("separation", 6)
	var head := Label.new()
	head.text = "Tier %d" % tier
	head.add_theme_font_size_override("font_size", 20)
	col.add_child(head)
	col.add_child(_build_audit(tier))
	for id in adapter.tech_ids(tier):
		col.add_child(_build_card(id))
	return col


func _build_audit(tier: int) -> Control:
	var box := VBoxContainer.new()
	box.name = "Audit%d" % tier
	var parts := adapter.audit_parts(tier)
	if parts.is_empty():
		var l0 := Label.new()
		l0.text = "Audit: not required"
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
			lines.append("Done")
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


## Thin read/command layer. Reads `sim.research` when R2a provides it, else falls back to the
## shape in docs/research_batch_plan.md loaded from data/research.json (state kept locally, so the
## panel is usable and testable before the sim core lands). If that file is absent too, a small
## built-in sample tree is shown.
class ResearchAdapter extends RefCounted:
	const SAMPLE_TECHS := {
		"hand_tools": {"name": "Hand tools", "tier": 0, "prereqs": [], "cost": {"bench_ticks": 600, "essence": 0}},
		"storage_rack": {"name": "Storage racks", "tier": 0, "prereqs": [], "cost": {"bench_ticks": 600, "essence": 0}},
		"field_smelting": {"name": "Field smelting", "tier": 0, "prereqs": ["hand_tools"], "cost": {"bench_ticks": 900, "essence": 0}},
		"turret_basic": {"name": "Turret basics", "tier": 0, "prereqs": [], "cost": {"bench_ticks": 900, "essence": 0}},
		"miner": {"name": "Auto miner", "tier": 1, "prereqs": ["hand_tools"], "cost": {"bench_ticks": 1800, "essence": 0}},
		"belts": {"name": "Belts", "tier": 1, "prereqs": ["hand_tools"], "cost": {"bench_ticks": 1800, "essence": 0}},
		"smelter": {"name": "Smelter", "tier": 1, "prereqs": ["field_smelting"], "cost": {"bench_ticks": 2400, "essence": 0}},
		"sorting": {"name": "Sorting", "tier": 1, "prereqs": ["belts"], "cost": {"bench_ticks": 2400, "essence": 0}},
		"assembler": {"name": "Assembler", "tier": 2, "prereqs": ["smelter"], "cost": {"bench_ticks": 7200, "essence": 20}},
		"adv_recipes": {"name": "Advanced recipes", "tier": 2, "prereqs": ["assembler"], "cost": {"bench_ticks": 9600, "essence": 30}, "waste_mult": 1.25},
		"filters": {"name": "Waste filters", "tier": 2, "prereqs": ["smelter"], "cost": {"bench_ticks": 7200, "essence": 25}},
		"fast_belts": {"name": "Fast belts", "tier": 3, "prereqs": ["assembler"], "cost": {"bench_ticks": 14400, "essence": 60}},
		"mass_refining": {"name": "Mass refining", "tier": 3, "prereqs": ["adv_recipes"], "cost": {"bench_ticks": 19200, "essence": 80}, "waste_mult": 1.6},
		"overdrive": {"name": "Overdrive", "tier": 3, "prereqs": ["fast_belts"], "cost": {"bench_ticks": 19200, "essence": 90}, "waste_mult": 1.4},
	}
	const SAMPLE_MILESTONES := {
		"2": {"parts": {"iron_plate": 40, "gear": 10}},
		"3": {"parts": {"iron_plate": 120, "gear": 40}},
	}

	var sim: Simulation
	var _techs: Dictionary = {}
	var _milestones: Dictionary = {}
	var _local_queue: Array = []
	var _local_done: Array = []
	var _local_delivered: Dictionary = {}

	func _init(p_sim: Simulation) -> void:
		sim = p_sim
		_techs = _unwrap(_from_sim("techs"), "res://data/research.json", "techs")
		if _techs.is_empty():
			_techs = SAMPLE_TECHS
		_milestones = _unwrap(_from_sim("milestones"), "res://data/milestones.json", "tiers")
		if _milestones.is_empty():
			_milestones = SAMPLE_MILESTONES

	func _from_sim(prop: String) -> Variant:
		var r: Variant = sim.get("research")
		if r != null and r is Object and prop in r:
			return r.get(prop)
		return null

	func _unwrap(v: Variant, path: String, wrap: String) -> Dictionary:
		if v is Dictionary and not (v as Dictionary).is_empty():
			return v
		if not FileAccess.file_exists(path):
			return {}
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			var dd: Dictionary = parsed
			if dd.has(wrap) and dd[wrap] is Dictionary:
				dd = dd[wrap]
			var out := {}
			for k: String in dd:
				if not k.begins_with("_"):
					out[k] = dd[k]
			return out
		return {}

	func has_sim_research() -> bool:
		return sim.get("research") != null

	func done_list() -> Array:
		if has_sim_research():
			var v: Variant = _from_sim("done")
			if v is Array:
				return v
		return _local_done

	func queue_list() -> Array:
		if has_sim_research():
			var v: Variant = _from_sim("queue")
			if v is Array:
				return v
		return _local_queue

	func tech(id: String) -> Dictionary:
		return _techs.get(id, {})

	func tech_ids(tier: int) -> Array[String]:
		var out: Array[String] = []
		for id: String in _techs:
			if int(_techs[id].get("tier", 0)) == tier:
				out.append(id)
		out.sort()
		return out

	func tier_count() -> int:
		return _techs.size()

	func audit_parts(tier: int) -> Dictionary:
		var m: Dictionary = _milestones.get(str(tier), {})
		return m.get("parts", {})

	func audit_delivered(tier: int) -> Dictionary:
		var d: Variant = _from_sim("delivered") if has_sim_research() else _local_delivered
		if d is Dictionary:
			return (d as Dictionary).get(str(tier), (d as Dictionary).get(tier, {}))
		return {}

	func audit_done(tier: int) -> bool:
		var parts := audit_parts(tier)
		if parts.is_empty():
			return true
		if has_sim_research():
			var r: Object = sim.get("research")
			if r.has_method("tier_unlocked"):
				return bool(r.call("tier_unlocked", tier))
		var got := audit_delivered(tier)
		for item: String in parts:
			if int(got.get(item, 0)) < int(parts[item]):
				return false
		return true

	func item_name(item: String) -> String:
		return str(sim.defs.items.get(item, {}).get("name", item))

	func prereq_missing(id: String) -> Array[String]:
		var out: Array[String] = []
		for p: String in tech(id).get("prereqs", []):
			if not done_list().has(p) and int(tech(p).get("tier", 0)) > 1:
				out.append(str(tech(p).get("name", p)))
		return out

	## "done" | "active" | "queued" | "available" | "locked". Tiers 0/1 count as researched
	## when no sim.research exists (they are unlocked at start per the plan).
	func state_of(id: String) -> String:
		if done_list().has(id) or (not has_sim_research() and int(tech(id).get("tier", 0)) <= 1):
			return "done"
		if lock_reason(id) != "":
			return "locked"
		var q := queue_list()
		if not q.is_empty() and q[0] == id:
			return "active"
		if q.has(id):
			return "queued"
		return "available"

	func lock_reason(id: String) -> String:
		var miss := prereq_missing(id)
		if not miss.is_empty():
			return "needs " + ", ".join(miss)
		var tier := int(tech(id).get("tier", 0))
		if tier > 0 and not audit_done(tier):
			return "audit T%d" % tier
		return ""

	func queue_pos(id: String) -> int:
		return queue_list().find(id) + 1

	func progress_frac(id: String) -> float:
		var total := float(tech(id).get("cost", {}).get("bench_ticks", 0))
		if total <= 0.0 or not has_sim_research():
			return 0.0
		var p: Variant = _from_sim("progress")
		var v := 0.0
		if p is Dictionary:
			v = float((p as Dictionary).get(id, 0.0))
		return clampf(v / total, 0.0, 1.0)

	func cost_text(id: String) -> String:
		var c: Dictionary = tech(id).get("cost", {})
		var tpd := sim.ticks_per_day
		var hours := int(round(float(int(c.get("bench_ticks", 0))) / float(tpd) * 24.0))
		var s := "%dd %dh" % [hours / 24, hours % 24]
		if int(c.get("essence", 0)) > 0:
			s += ", %d essence" % int(c["essence"])
		return s

	func set_queued(id: String, on: bool) -> bool:
		if sim.has_method("queue_research"):
			return bool(sim.call("queue_research", id, on))
		if on and not _local_queue.has(id):
			_local_queue.append(id)
		elif not on:
			_local_queue.erase(id)
		return true

	func deliver(tier: int) -> bool:
		if sim.has_method("deliver_audit"):
			return bool(sim.call("deliver_audit", tier))
		return false

	## Cheap change detector for refresh().
	func signature() -> String:
		var s := ",".join(done_list()) + "|" + ",".join(queue_list())
		if has_sim_research():
			var p: Variant = _from_sim("progress")
			if p is Dictionary:
				for k: String in (p as Dictionary).keys():
					s += "%s%d" % [k, int(float(p[k]) / 20.0)]
			s += "|" + JSON.stringify(_from_sim("delivered"))
		return s
