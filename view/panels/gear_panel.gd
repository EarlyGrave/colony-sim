class_name GearPanel
extends InspectorSection
## E4: read-only gear list on the inmate card: one >= 64 px row per slot from data/equipment.json
## (slot name, item, rarity colour, stat line). No drag, no commands. Shown only for inmates that own gear.

const ROW_H := 64.0


func _init() -> void:
	title = "Gear"


func applies(sim: Simulation, target: Dictionary) -> bool:
	var c: Colonist = target.get("colonist")
	return c != null and sim.equipment != null and sim.equipment.has_state() and (sim.equipment.equipped.has(c.id) or not sim.equipment.stored_of(c.id).is_empty())  # region E5


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


static func stat_line(g: GearItem) -> String:  # region F8: human stat names
	var parts: Array[String] = []
	var keys: Array = g.stats.keys()
	keys.sort()
	for k: String in keys:
		var v := float(g.stats[k])
		if v != 0.0:
			parts.append(StatNames.fmt(k, v))
	return ", ".join(parts)


func build(sim: Simulation, target: Dictionary, box: VBoxContainer) -> void:
	var c: Colonist = target["colonist"]
	_open_gear_button(c, target, box)  # region F8
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
		if r["item"] != "":  # region E5
			v.add_child(_button("Unequip", func() -> void: sim.unequip(c.id, str(r["slot"]))))
		box.add_child(row)
	_build_stored(sim, c, box)  # region E5


# region E5: interactive part. Buttons call the recorded Simulation commands (equip / unequip / socket).
static func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, ROW_H)
	b.pressed.connect(cb)
	return b


## Stored (unworn) gear rows: [{id, name, rarity, color, stats, slot_name, sockets_free}].
static func stored_rows(sim: Simulation, cid: int) -> Array:
	var out: Array = []
	for id: int in sim.equipment.stored_of(cid):
		var g: GearItem = sim.equipment.instances[id]
		var free: int = int(sim.defs.equipment["upgrade_slots"].get(g.rarity, 0)) - g.upgrades.size()
		out.append({"id": id, "name": str(sim.defs.gear[g.base].get("name", g.base)), "rarity": g.rarity,
			"color": Color.html(str(sim.defs.equipment["rarity"][g.rarity].get("color", "#c0c0c8"))),
			"stats": stat_line(g), "slot_name": str(sim.defs.equipment["slots"][g.slot].get("name", g.slot)), "sockets_free": free})
	return out


## F9W1: "2 plate" style cost text of an upgrade.
static func cost_text(sim: Simulation, upgrade_id: String) -> String:
	var cost: Dictionary = sim.equipment.socket_cost(upgrade_id)
	var keys: Array = cost.keys()
	keys.sort()
	var parts: Array[String] = []
	for k: String in keys:
		parts.append("%d %s" % [int(cost[k]), str(sim.defs.items.get(k, {}).get("name", k)).to_lower()])
	return ", ".join(parts) if not parts.is_empty() else "free"


## Socket choices for an item: upgrade ids whose tags fit (sorted).
static func socket_options(sim: Simulation, item_id: int) -> Array:
	var g: GearItem = sim.equipment.instances[item_id]
	var tags: Array = sim.defs.gear[g.base].get("tags", [])
	var out: Array = []
	var ids: Array = sim.defs.upgrades.keys()
	ids.sort()
	for u: String in ids:
		if u.begins_with("_"):
			continue
		var need: Array = sim.defs.upgrades[u].get("tags_any", [])
		var ok := need.is_empty()
		for t in need:
			ok = ok or tags.has(t)
		if ok:
			out.append(u)
	return out


func _build_stored(sim: Simulation, c: Colonist, box: VBoxContainer) -> void:
	var rows := stored_rows(sim, c.id)
	if rows.is_empty():
		return
	var head := add_line(box, "Stored gear", Color(0.75, 0.8, 0.85))
	head.custom_minimum_size = Vector2(0, ROW_H * 0.5)
	for r: Dictionary in rows:
		var row := PanelContainer.new()
		var v := VBoxContainer.new()
		row.add_child(v)
		add_line(v, "%s: %s (%s)" % [r["slot_name"], r["name"], r["rarity"]], r["color"])
		if r["stats"] != "":
			add_line(v, r["stats"], Color(0.75, 0.8, 0.85))
		var id: int = r["id"]
		v.add_child(_button("Equip", func() -> void: sim.equip(c.id, id)))
		if int(r["sockets_free"]) > 0:
			for u: String in socket_options(sim, id):
				v.add_child(_button("Socket: %s (%s)" % [str(sim.defs.upgrades[u].get("name", u)), cost_text(sim, u)], func() -> void: sim.socket(id, u))) # F9W1
		box.add_child(row)
# endregion


# region F8: shortcut to the full gear screen (only when the inspector can open panels)
static func _open_gear_button(c: Colonist, target: Dictionary, box: VBoxContainer) -> void:
	var req: Callable = target.get("request_panel", Callable())
	if not req.is_valid():
		return
	var cid := c.id
	box.add_child(_button("Open gear", func() -> void: req.call("gear_screen", cid)))
# endregion
