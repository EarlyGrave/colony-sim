class_name EquipmentSystem
extends RefCounted
## E2: gear instances, per-colonist slots, cached stat totals. No per-tick work, no rng (rolling is E3's hook).
## Commands go through Simulation (give_gear / equip / unequip / socket).

var sim: Simulation
var instances: Dictionary = {}  # id -> GearItem
var equipped: Dictionary = {}  # cid -> {slot: item_id}
var totals: Dictionary = {}  # cid -> PackedFloat64Array (StatBlock order), valid after a resum
var resum_count := 0
var _next_id := 1


func _init(p_sim: Simulation) -> void:
	sim = p_sim


func has_state() -> bool:
	return not instances.is_empty()


func slot_ids() -> Array:
	var ids: Array = sim.defs.equipment["slots"].keys()
	ids.sort()
	return ids


func give(cid: int, base: String, rarity: String, ilvl: int) -> int:
	if sim.colonists.get_by_id(cid) == null or not sim.defs.gear.has(base) or base.begins_with("_"):
		return -1
	var eq: Dictionary = sim.defs.equipment
	if not eq["rarity"].has(rarity) or not eq["slots"].has(str(sim.defs.gear[base].get("slot", ""))):
		return -1
	var g := GearItem.new()
	g.id = _next_id
	_next_id += 1
	g.base = base
	g.slot = str(sim.defs.gear[base]["slot"])
	g.rarity = rarity
	g.ilvl = ilvl
	g.max_durability = float(eq["durability"].get("default_max", 100))
	g.durability = g.max_durability
	g.owner = cid
	if int(eq["rarity"][rarity].get("affixes", 0)) > 0:  # region E3
		var r := RandomNumberGenerator.new()  # region E3
		r.seed = sim.rng.randi()  # region E3: child rng, one parent draw per rolled item
		g.affixes = AffixRoller.roll(sim.defs, base, rarity, ilvl, r)  # region E3
	g.resum_stats(sim.defs)
	instances[g.id] = g
	return g.id


func equip(cid: int, item_id: int) -> bool:
	var g: GearItem = instances.get(item_id)
	if g == null or g.owner != cid or sim.colonists.get_by_id(cid) == null:
		return false
	if not sim.defs.equipment["slots"].has(g.slot):
		return false
	var slots: Dictionary = equipped.get(cid, {})
	if slots.get(g.slot, -1) == item_id:
		return true
	slots[g.slot] = item_id
	equipped[cid] = slots
	_resum(cid)
	return true


func unequip(cid: int, slot: String) -> bool:
	var slots: Dictionary = equipped.get(cid, {})
	if not slots.has(slot):
		return false
	slots.erase(slot)
	_resum(cid)
	return true


# region F9W1
## Stock cost of an upgrade ({item: n}, from data/upgrades.json "cost").
func socket_cost(upgrade_id: String) -> Dictionary:
	return sim.defs.upgrades.get(upgrade_id, {}).get("cost", {})


func can_afford_socket(upgrade_id: String) -> bool:
	var cost := socket_cost(upgrade_id)
	for k: String in cost:
		if sim.items.count_stored(k) < int(cost[k]):
			return false
	return true


## First missing "need N item" text for a cost, or "" when affordable.
func socket_missing(upgrade_id: String) -> String:
	var cost := socket_cost(upgrade_id)
	var keys: Array = cost.keys()
	keys.sort()
	var parts: Array[String] = []
	for k: String in keys:
		var short: int = int(cost[k]) - sim.items.count_stored(k)
		if short > 0:
			parts.append("%d %s" % [short, str(sim.defs.items.get(k, {}).get("name", k)).to_lower()])
	return ", ".join(parts)
# endregion


func socket(item_id: int, upgrade_id: String) -> bool:
	var g: GearItem = instances.get(item_id)
	if g == null or not sim.defs.upgrades.has(upgrade_id):
		return false
	if g.upgrades.size() >= int(sim.defs.equipment["upgrade_slots"].get(g.rarity, 0)):
		return false
	var tags: Array = sim.defs.gear[g.base].get("tags", [])
	var need: Array = sim.defs.upgrades[upgrade_id].get("tags_any", [])
	if not need.is_empty():
		var ok := false
		for t in need:
			ok = ok or tags.has(t)
		if not ok:
			return false
	# region F9W1: pay only after every check passed
	if not can_afford_socket(upgrade_id):
		return false
	var cost := socket_cost(upgrade_id)
	var ckeys: Array = cost.keys()
	ckeys.sort()
	for k: String in ckeys:
		sim.items.consume_stored(k, int(cost[k]), sim.map_center())
	# endregion
	g.upgrades.append(upgrade_id)
	g.resum_stats(sim.defs)
	if equipped.get(g.owner, {}).get(g.slot, -1) == g.id:
		_resum(g.owner)
	return true


## Durability change (future hit path); resums only when the contribution band changes.
func set_durability(item_id: int, value: float) -> void:
	var g: GearItem = instances.get(item_id)
	if g == null:
		return
	var cfg: Dictionary = sim.defs.equipment["durability"]
	var before := g.dur_mult(cfg)
	g.durability = clampf(value, 0.0, g.max_durability)
	if not is_equal_approx(before, g.dur_mult(cfg)) and equipped.get(g.owner, {}).get(g.slot, -1) == g.id:
		_resum(g.owner)


func total(cid: int, key: String) -> float:
	var t: PackedFloat64Array = totals.get(cid, PackedFloat64Array())
	return t[StatBlock.IDX[key]] if not t.is_empty() else 0.0


func _resum(cid: int) -> void:
	var p := StatBlock.make()
	var cfg: Dictionary = sim.defs.equipment["durability"]
	var slots: Dictionary = equipped.get(cid, {})
	var keys: Array = slots.keys()  # sorted: float sums stay deterministic
	keys.sort()
	for s in keys:
		var g: GearItem = instances[slots[s]]
		StatBlock.sum_into(p, g.stats, g.dur_mult(cfg))
	totals[cid] = p
	resum_count += 1
	# region E4: hand the summed vector to the combat caches (one resum per equip change)
	var col := sim.colonists.get_by_id(cid)
	if col != null and sim.combat != null:
		sim.combat.resum(col)
	# endregion


func state_parts() -> Array:
	var parts: Array = []
	var ids: Array = instances.keys()
	ids.sort()
	for i in ids:
		var g: GearItem = instances[i]
		parts.append([g.id, g.base, g.rarity, g.ilvl, g.affixes, g.upgrades, g.durability, g.owner])
	var cids: Array = equipped.keys()
	cids.sort()
	for c in cids:
		var s: Dictionary = equipped[c]
		var ks: Array = s.keys()
		ks.sort()
		for k in ks:
			parts.append([c, k, s[k]])
	return parts


# region E5
## Weighted rarity pick from {rarity: weight}; exactly one sim.rng draw, keys iterated sorted.
func roll_rarity(weights: Dictionary) -> String:
	var keys: Array = weights.keys()
	keys.sort()
	var total := 0.0
	for k: String in keys:
		total += float(weights[k])
	if total <= 0.0:
		return "common"
	var x := sim.rng.randf() * total
	for k: String in keys:
		x -= float(weights[k])
		if x < 0.0:
			return k
	return str(keys[keys.size() - 1])


## Crafted gear for the operator (rarity rolled). Returns the item id or -1.
func craft(cid: int, base: String) -> int:
	var src: Dictionary = sim.defs.equipment.get("sources", {})
	var rarity := roll_rarity(src.get("craft_rarity_weights", {"common": 1}))
	return give(cid, base, rarity, int(src.get("craft_ilvl", 0)))


## Drop from a killed enemy of `faction`; `cid` receives it. Draws rng only for configured factions.
func roll_drop(faction: String, cid: int) -> int:
	var cfg: Dictionary = sim.defs.equipment.get("sources", {}).get("drops", {})
	if not bool(cfg.get("enabled", false)) or not cfg.has(faction) or cid < 0:
		return -1
	var f: Dictionary = cfg[faction]
	if sim.rng.randf() >= float(f.get("chance", 0.0)):
		return -1
	var bases: Array = f.get("bases", [])
	if bases.is_empty():
		return -1
	var base: String = bases[sim.rng.randi() % bases.size()]
	var id := give(cid, base, roll_rarity(f.get("rarity_weights", {"common": 1})), int(f.get("ilvl", 0)))
	return id


## Items owned by cid but not in a slot, sorted by id.
func stored_of(cid: int) -> Array:
	var worn: Dictionary = equipped.get(cid, {})
	var out: Array = []
	for id: int in instances:
		var g: GearItem = instances[id]
		if g.owner == cid and worn.get(g.slot, -1) != id:
			out.append(id)
	out.sort()
	return out
# endregion
