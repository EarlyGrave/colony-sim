class_name GearPanel
extends InspectorSection
## E4: read-only gear list on the inmate card: one >= 64 px row per slot from data/equipment.json
## (slot name, item, rarity colour, stat line). No drag, no commands. Shown only for inmates that own gear.

const ROW_H := 64.0


func _init() -> void:
	title = "Gear"


func applies(sim: Simulation, target: Dictionary) -> bool:
	var c: Colonist = target.get("colonist")
	return c != null and sim.equipment != null and sim.equipment.has_state() and sim.equipment.equipped.has(c.id)


## Pure data for the rows (also used by tests): [{slot, slot_name, item, rarity, color, stats}] in sorted slot order.
static func rows(sim: Simulation, cid: int) -> Array:
	var out: Array = []
	var eq: Dictionary = sim.defs.equipment
	var slots: Dictionary = sim.equipment.equipped.get(cid, {})
	for s: String in sim.equipment.slot_ids():
		var row := {"slot": s, "slot_name": str(eq["slots"][s].get("name", s)), "item": "", "rarity": "", "color": Color(0.5, 0.5, 0.5), "stats": ""}
		if slots.has(s):
			var g: GearItem = sim.equipment.instances[slots[s]]
			row["item"] = str(sim.defs.gear[g.base].get("name", g.base))
			row["rarity"] = g.rarity
			row["color"] = Color.html(str(eq["rarity"][g.rarity].get("color", "#c0c0c8")))
			row["stats"] = stat_line(g)
		out.append(row)
	return out


static func stat_line(g: GearItem) -> String:
	var parts: Array[String] = []
	var keys: Array = g.stats.keys()
	keys.sort()
	for k: String in keys:
		var v := float(g.stats[k])
		if v == 0.0:
			continue
		parts.append(("%s %d%%" % [k, roundi(v * 100.0)]) if absf(v) < 1.0 else ("%s %s" % [k, str(snappedf(v, 0.1))]))
	return ", ".join(parts)


func build(sim: Simulation, target: Dictionary, box: VBoxContainer) -> void:
	var c: Colonist = target["colonist"]
	for r: Dictionary in rows(sim, c.id):
		var row := PanelContainer.new()
		row.custom_minimum_size = Vector2(0, ROW_H)
		var v := VBoxContainer.new()
		row.add_child(v)
		var head: String = r["slot_name"] if r["item"] == "" else "%s: %s (%s)" % [r["slot_name"], r["item"], r["rarity"]]
		add_line(v, head, r["color"])
		if r["stats"] != "":
			add_line(v, r["stats"], Color(0.75, 0.8, 0.85))
		else:
			add_line(v, "empty" if r["item"] == "" else "no bonuses", Color(0.5, 0.5, 0.55))
		box.add_child(row)
