class_name ItemCard
extends PanelContainer
## F8: read-only item card (title, slot, base stats, affixes, sockets, durability). Width is flexible: min MIN_W, expands to the column, wraps text.
## Pure data in lines(); profile() gives the fighter summary. No commands, no signals.

const MIN_W := 240.0
const MAX_W := 360.0
const HINT := "Select an item"
const BASE_KEYS: Array[String] = ["damage", "armor_phys", "armor_energy", "flat_phys", "flat_energy", "accuracy", "crit_chance", "crit_mult"]

var _box: VBoxContainer


static func make(sim: Simulation, item_id: int) -> ItemCard:
	var c := ItemCard.new()
	c.set_item(sim, item_id)
	return c


func _init() -> void:
	custom_minimum_size = Vector2(MIN_W, 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 4)
	add_child(_box)


func set_item(sim: Simulation, item_id: int) -> void:
	for ch in _box.get_children():
		_box.remove_child(ch)
		ch.queue_free()
	var L := lines(sim, item_id)
	if L.is_empty():
		_label(HINT, Color(0.5, 0.5, 0.55))
		return
	var col: Color = L["color"]
	_label("%s   ilvl %d" % [L["name"], int(L["ilvl"])], col)
	_label("%s - %s" % [L["slot_name"], str(L["rarity"]).capitalize()], Color(0.6, 0.65, 0.7))
	for s: String in L["base"]:
		_label(s, Color(0.85, 0.88, 0.9))
	for s: String in L["affixes"]:
		_label(s, Color(0.55, 0.75, 1.0))
	for s: String in L["sockets"]:
		_label(s, Color(0.8, 0.8, 0.6))
	var low: bool = L["durability_low"]
	_label(L["durability"], Color(1.0, 0.4, 0.4) if low else Color(0.7, 0.72, 0.75))
	if L.get("repair", "") != "":  # region F9W3
		_label(str(L["repair"]), Color(0.95, 0.8, 0.3))


func _label(text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(MIN_W - 20.0, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_color_override("font_color", color)
	_box.add_child(l)


## {name, rarity, color, ilvl, slot_name, base:[String], affixes:[String], sockets:[String], durability:String, durability_low:bool, repair:String ("" at full durability)}; {} for an unknown id.
static func lines(sim: Simulation, item_id: int) -> Dictionary:
	var g: GearItem = null
	if sim != null and sim.equipment != null:
		g = sim.equipment.instances.get(item_id)
	if g == null:
		return {}
	var eq: Dictionary = sim.defs.equipment
	var bdef: Dictionary = sim.defs.gear.get(g.base, {})
	var base: Array[String] = []
	var bstats := GearItem.new()
	bstats.base = g.base
	bstats.resum_stats(sim.defs)  # base only: no affixes/upgrades
	for k in BASE_KEYS:
		var v := float(bstats.stats.get(k, 0.0))
		if v != 0.0:
			base.append(StatNames.fmt(k, v))
	var affixes: Array[String] = []
	for a in g.affixes:
		affixes.append(StatNames.fmt(str(a[0]), float(a[1])))
	var total_slots := int(eq["upgrade_slots"].get(g.rarity, 0))
	var sockets: Array[String] = []
	var names: Array[String] = []
	for u in g.upgrades:
		var ud: Dictionary = sim.defs.upgrades.get(u, {})
		var parts: Array[String] = []
		for k: String in ud.get("stats", {}):
			parts.append(StatNames.fmt(k, float(ud["stats"][k])))
		names.append("%s (%s)" % [str(ud.get("name", u)), ", ".join(parts)])
	for i in maxi(0, total_slots - g.upgrades.size()):
		names.append("[empty]")
	if total_slots > 0:
		sockets.append("Sockets: " + ", ".join(names))
	var dtxt := "Durability %d/%d" % [roundi(g.durability), roundi(g.max_durability)]
	var low := g.max_durability > 0.0 and g.durability / g.max_durability < 0.25
	if g.durability <= 0.0:
		var m := float(eq["durability"].get("zero_stat_mult", 0.5))
		dtxt += " - Broken: stats %s" % ("halved" if is_equal_approx(m, 0.5) else "x" + str(m))
	var rcost := sim.equipment.repair_cost(item_id)  # region F9W3
	return {
		"repair": "Repair: %d plate" % rcost if rcost > 0 else "",
		"name": str(bdef.get("name", g.base)), "rarity": g.rarity, "ilvl": g.ilvl,
		"color": Color.html(str(eq["rarity"][g.rarity].get("color", "#c0c0c8"))),
		"slot_name": str(eq["slots"].get(g.slot, {}).get("name", g.slot)),
		"base": base, "affixes": affixes, "sockets": sockets, "durability": dtxt, "durability_low": low,
	}


## Fighter summary for inmate `cid`: Armour phys/energy, Damage, Max HP, Move speed (gear totals + colonist).
static func profile(sim: Simulation, cid: int) -> Array[String]:
	var out: Array[String] = []
	var c: Colonist = sim.colonists.get_by_id(cid)
	if c == null or sim.equipment == null:
		return out
	var cfg: Dictionary = sim.defs.equipment["durability"]
	var dmg_pct := 0.0
	var hp_bonus := 0.0
	var move := 0.0
	var slots: Dictionary = sim.equipment.equipped.get(cid, {})
	var keys: Array = slots.keys()
	keys.sort()
	for s in keys:
		var g: GearItem = sim.equipment.instances[slots[s]]
		var m := g.dur_mult(cfg)
		dmg_pct += float(g.stats.get("dmg_pct", 0.0)) * m
		hp_bonus += float(g.stats.get("max_hp", 0.0)) * m
		move += float(g.stats.get("move_speed", 0.0)) * m
	var dmg := sim.equipment.total(cid, "damage") * (1.0 + dmg_pct)
	out.append("Armour: %d phys / %d energy" % [roundi(sim.equipment.total(cid, "armor_phys")), roundi(sim.equipment.total(cid, "armor_energy"))])
	out.append("Damage: %s" % str(snappedf(dmg, 0.1)))
	out.append("Max HP: %d" % roundi(c.max_hp + hp_bonus))
	out.append("Move speed: %d%%" % roundi((1.0 + move) * 100.0))
	return out
