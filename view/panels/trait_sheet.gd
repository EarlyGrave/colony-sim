class_name TraitSheet
extends RefCounted
## F11W4: trait badge row + info sheet for the colonist section (traits v3). A badge is a 60x64 button with a
## 32x32 icon; tapping it shows the sheet (name, category, description, effect lines, since-day) under the row.
## Falls back to the v2 text list (`add_v2_list`) while the traits v3 facade is absent. Reads sim state only.

const BADGE_W := 60.0
const BADGE_H := 64.0
const ICON := 32
const CAT_COLORS := {
	"personality": Color(0.8, 0.85, 1.0), "body": Color(0.7, 0.95, 0.7), "background": Color(0.95, 0.85, 0.6),
	"scar": Color(1.0, 0.55, 0.5), "mutation": Color(0.75, 0.55, 1.0), "social": Color(0.5, 0.85, 0.95),
}
## Trait shown under the badge row: {"cid": int, "id": String}; empty = none.
static var selected: Dictionary = {}


## The v3 facade (sim.traits_v3) when it is live, else null.
static func v3(sim: Simulation) -> TraitSystemV3:
	if not bool(sim.defs.balance.get("traits_v3_enabled", false)):
		return null
	var t: Variant = sim.get("traits_v3")
	return t as TraitSystemV3


## Day the trait was acquired (-1 = from birth / unknown).
static func since_day(c: Colonist, id: String) -> int:
	var day := -1
	for e: Variant in c.bio.get("trait_log", []):
		if typeof(e) == TYPE_DICTIONARY and str(e.get("id", "")) == id:
			day = int(e.get("day", 0)) if str(e.get("op", "add")) == "add" else -1
	return day


static func effect_text(stat: String, v: float) -> String:
	var nm := stat.replace("_", " ").capitalize()
	if absf(v) < 5.0:
		return "%s %+d%%" % [nm, roundi(v * 100.0)]
	return "%s %+d" % [nm, roundi(v)]


## Badge row + (optional) info sheet. Returns the badge buttons by trait id.
static func build_v3(ts: TraitSystemV3, c: Colonist, box: VBoxContainer) -> Dictionary:
	var out: Dictionary = {}
	var ids := ts.list(c)
	if ids.is_empty():
		return out
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 2)
	row.add_theme_constant_override("v_separation", 2)
	box.add_child(row)
	var cid := c.id
	for id in ids:
		var d := ts.def(id)
		var b := Button.new()
		b.custom_minimum_size = Vector2(BADGE_W, BADGE_H)
		b.focus_mode = Control.FOCUS_NONE
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", ICON)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var path := ts.icon_path(id)
		if ResourceLoader.exists(path):
			b.icon = load(path)
		else:
			b.text = str(d.get("name", id)).substr(0, 2)
		b.tooltip_text = str(d.get("name", id))
		b.modulate = CAT_COLORS.get(ts.category(id), Color.WHITE)
		b.pressed.connect(func() -> void:
			if selected.get("cid", -1) == cid and selected.get("id", "") == id:
				selected = {}
			else:
				selected = {"cid": cid, "id": id})
		row.add_child(b)
		out[id] = b
	if selected.get("cid", -1) == cid and ids.has(str(selected.get("id", ""))):
		build_sheet(ts, c, str(selected["id"]), box)
	return out


static func build_sheet(ts: TraitSystemV3, c: Colonist, id: String, box: VBoxContainer) -> void:
	var d := ts.def(id)
	var col: Color = CAT_COLORS.get(ts.category(id), Color.WHITE)
	InspectorSection.add_line(box, "%s (%s, %s)" % [str(d.get("name", id)), ts.category(id), str(d.get("rarity", "common"))], col)
	InspectorSection.add_line(box, str(d.get("desc", "")))
	for k: String in d.get("effects", {}):
		InspectorSection.add_line(box, effect_text(k, float(d["effects"][k])), Color(0.8, 0.85, 1.0))
	var day := since_day(c, id)
	InspectorSection.add_line(box, "Since day %d" % day if day >= 0 else "Since birth", Color(0.7, 0.72, 0.78))


## v2 fallback: one text line per trait, exactly as the colonist section always did.
static func add_v2_list(sim: Simulation, c: Colonist, box: VBoxContainer) -> void:
	var tl: Array = c.bio.get("traits", [])
	for t: String in tl:
		var td := sim.traits.def(t)
		if not td.is_empty():
			InspectorSection.add_line(box, "%s - %s" % [td.get("name", t), td.get("desc", "")], Color(0.8, 0.85, 1.0))
