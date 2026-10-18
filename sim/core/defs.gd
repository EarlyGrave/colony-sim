class_name Defs
extends RefCounted
## Loaded game definitions (data/*.json). Read-only for systems.
## Tests may `duplicate_defs()` and tweak numbers for a scenario.

const DATA_DIR := "res://data/"

var items: Dictionary = {}
var buildings: Dictionary = {}
var recipes: Dictionary = {}
var zones: Dictionary = {}
var enemies: Dictionary = {}
var jobs: Dictionary = {}
var balance: Dictionary = {}
var events: Dictionary = {}
var rules: Dictionary = {}
# region jobs-core
var work: Dictionary = {}
var skills: Dictionary = {}
# region health
var health: Dictionary = {}
# region arrivals
var arrivals: Dictionary = {}
var names: Dictionary = {}
var traits: Dictionary = {}
# endregion
# region mood
var mood: Dictionary = {}
# region crafting
var crafting: Dictionary = {}
# region combat
var weapons: Dictionary = {}
# region progression
var xp: Dictionary = {}
# endregion
var ammo: Dictionary = {}  # region ammo
# region perks
var perks: Dictionary = {}
var quality: Dictionary = {}  # region quality
# endregion
# endregion

# region storyteller-chains
var event_chains: Dictionary = {}
# region crises
var crises: Dictionary = {}
# region debt
var debt: Dictionary = {}
# region idle-work
var idle_work: Dictionary = {}
var mutation: Dictionary = {}  # region mutation
# region T1
var threat: Dictionary = {}
# endregion
var ecology: Dictionary = {}  # region T5
# endregion
# region raids
var raids: Dictionary = {}
var tutorial: Dictionary = {}  # region O1
# endregion
# region contracts
var contracts: Dictionary = {}
var meta: Dictionary = {}  # region meta
var milestones: Dictionary = {}  # region R2b
var presets: Dictionary = {}  # region O3
# endregion
# region needs
var time: Dictionary = {}
var needs: Dictionary = {}
var plants: Dictionary = {}
# endregion

# region A1b
var resources: Dictionary = {}
var biomes: Dictionary = {}
# endregion
var research: Dictionary = {}  # region R2a
var chips: Dictionary = {}  # region T4
var fuels: Dictionary = {}  # region L3: data/fuels.json (fuel item -> burn/waste/spent fields)
var roles: Dictionary = {}  # region C1
# region L5
var fuels: Dictionary = {}  # data/fuels.json (power fuels)
# endregion

static var _default: Defs = null


## Shared instance loaded from res://data. Do not mutate it.
static func get_default() -> Defs:
	if _default == null:
		_default = Defs.new()
		_default.load_from(DATA_DIR)
	return _default


func load_from(dir: String) -> void:
	items = _load_json(dir + "items.json")
	buildings = _load_json(dir + "buildings.json")
	recipes = _load_json(dir + "recipes.json")
	zones = _load_json(dir + "zones.json")
	enemies = _load_json(dir + "enemies.json")
	jobs = _load_json(dir + "jobs.json")
	balance = _load_json(dir + "balance.json")
	events = _load_json(dir + "events.json")
	rules = _load_json(dir + "rules.json")
	# region jobs-core
	work = _load_json(dir + "work.json")
	skills = _load_json(dir + "skills.json")
	# region health
	health = _load_json(dir + "health.json")
	# region arrivals
	arrivals = _load_json(dir + "arrivals.json")
	names = _load_json(dir + "names.json")
	traits = _load_json(dir + "traits.json")
	# endregion
	# region mood
	mood = _load_json(dir + "mood.json")
	# region crafting
	crafting = _load_json(dir + "crafting.json")
	# region combat
	weapons = _load_json(dir + "weapons.json")
	# region progression
	xp = _load_json(dir + "xp.json")
	# endregion
	# region perks
	perks = _load_json(dir + "perks.json")
	quality = _load_json(dir + "quality.json")  # region quality
	ammo = _load_json(dir + "ammo.json")  # region ammo
	# endregion
	# endregion
	# region storyteller-chains
	event_chains = _load_json(dir + "event_chains.json")
	events.merge(_load_json(dir + "events_prison.json"))
	# region crises
	crises = _load_json(dir + "crises.json")
	# region debt
	debt = _load_json(dir + "debt.json")
	# region idle-work
	idle_work = _load_json(dir + "idle_work.json")
	mutation = _load_json(dir + "mutation.json")  # region mutation
	threat = _load_json(dir + "threat.json")  # region T1
	ecology = _load_json(dir + "ecology.json")  # region T5
	# endregion
	# region raids
	raids = _load_json(dir + "raids.json")
	tutorial = _load_json(dir + "tutorial.json")  # region O1
	# endregion
	# region contracts
	contracts = _load_json(dir + "contracts.json")
	meta = _load_json(dir + "meta.json")  # region meta
	milestones = _load_json(dir + "milestones.json")  # region R2b
	presets = _load_json(dir + "presets.json")  # region O3
	# endregion
	# region needs
	time = _load_json(dir + "time.json")
	needs = _load_json(dir + "needs.json")
	plants = _load_json(dir + "plants.json")
	# endregion
	# region A1b
	if FileAccess.file_exists(dir + "resources.json"):
		resources = _load_json(dir + "resources.json")
	if FileAccess.file_exists(dir + "biomes.json"):
		biomes = _load_json(dir + "biomes.json")
	# endregion
	# region R2a
	if FileAccess.file_exists(dir + "research.json"):
		research = _load_json(dir + "research.json")
		for e in Tech.validate(research, self):  # circular prereqs / bad ids are rejected at load
			push_error("research.json: " + e)
	# endregion
	# region L3
	if FileAccess.file_exists(dir + "fuels.json"):
		fuels = _load_json(dir + "fuels.json")
	# endregion
	# region T4
	if FileAccess.file_exists(dir + "chips.json"):
		chips = _load_json(dir + "chips.json")
	# endregion
	roles = _load_json(dir + "roles.json")  # region C1
	# region L5
	if FileAccess.file_exists(dir + "fuels.json"):
		fuels = _load_json(dir + "fuels.json")
	# endregion


## Deep copy, safe to modify (for test scenarios / difficulty presets).
func duplicate_defs() -> Defs:
	var d := Defs.new()
	d.items = items.duplicate(true)
	d.buildings = buildings.duplicate(true)
	d.recipes = recipes.duplicate(true)
	d.zones = zones.duplicate(true)
	d.enemies = enemies.duplicate(true)
	d.jobs = jobs.duplicate(true)
	d.balance = balance.duplicate(true)
	d.events = events.duplicate(true)
	d.rules = rules.duplicate(true)
	# region jobs-core
	d.work = work.duplicate(true)
	d.skills = skills.duplicate(true)
	# region health
	d.health = health.duplicate(true)
	# region arrivals
	d.arrivals = arrivals.duplicate(true)
	d.names = names.duplicate(true)
	d.traits = traits.duplicate(true)
	# endregion
	# region mood
	d.mood = mood.duplicate(true)
	# region crafting
	d.crafting = crafting.duplicate(true)
	# region combat
	d.weapons = weapons.duplicate(true)
	# region progression
	d.xp = xp.duplicate(true)
	# endregion
	# region perks
	d.perks = perks.duplicate(true)
	d.quality = quality.duplicate(true)  # region quality
	d.event_chains = event_chains.duplicate(true)  # region storyteller-chains
	d.crises = crises.duplicate(true)  # region crises
	d.ammo = ammo.duplicate(true)  # region ammo
	# endregion
	# endregion
	# region debt
	d.debt = debt.duplicate(true)
	# region idle-work
	d.idle_work = idle_work.duplicate(true)
	d.mutation = mutation.duplicate(true)  # region mutation
	d.threat = threat.duplicate(true)  # region T1
	d.ecology = ecology.duplicate(true)  # region T5
	# endregion
	# region raids
	d.raids = raids.duplicate(true)
	d.tutorial = tutorial.duplicate(true)  # region O1
	# endregion
	# region contracts
	d.contracts = contracts.duplicate(true)
	d.meta = meta.duplicate(true)  # region meta
	d.milestones = milestones.duplicate(true)  # region R2b
	d.presets = presets.duplicate(true)  # region O3
	# endregion
	# region needs
	d.time = time.duplicate(true)
	d.needs = needs.duplicate(true)
	d.plants = plants.duplicate(true)
	# endregion
	d.resources = resources.duplicate(true)  # region A1b
	d.biomes = biomes.duplicate(true)  # region A1b
	d.research = research.duplicate(true)  # region R2a
	d.chips = chips.duplicate(true)  # region T4
	d.fuels = fuels.duplicate(true)  # region L3
	d.roles = roles.duplicate(true)  # region C1
	d.fuels = fuels.duplicate(true)  # region L5
	return d


# region A1b
const _DIRS := ["N", "E", "S", "W"]


## Consistency check of automation data. Returns human-readable errors (empty = ok).
func validate() -> Array[String]:
	var errs: Array[String] = []
	for rid: String in recipes:
		var r: Dictionary = recipes[rid]
		for key in ["inputs", "outputs"]:
			for item: String in r.get(key, {}):
				if not items.has(item):
					errs.append("recipe %s: unknown item %s" % [rid, item])
		var stations: Array = r.get("station", [])
		for st: String in stations:
			if not buildings.has(st):
				errs.append("recipe %s: unknown station %s" % [rid, st])
		if ("smelter" in stations or "refinery" in stations) and int(r.get("outputs", {}).get("waste", 0)) <= 0:
			errs.append("recipe %s: refining recipe without waste" % rid)
	for bid: String in buildings:
		var b: Dictionary = buildings[bid]
		var ports: Array = b.get("ports", [])
		var n_in := 0
		var n_out := 0
		for p: Dictionary in ports:
			if not str(p.get("dir", "")) in _DIRS:
				errs.append("building %s: bad port dir" % bid)
			if p.get("kind", "") == "in":
				n_in += 1
			elif p.get("kind", "") == "out":
				n_out += 1
			else:
				errs.append("building %s: bad port kind" % bid)
		var mk: String = str(b.get("machine", ""))
		if mk == "processor" and (n_in < 1 or n_out < 1):
			errs.append("machine %s needs >=1 in and >=1 out port" % bid)
		if mk == "extractor" and n_out < 1:
			errs.append("machine %s needs >=1 out port" % bid)
		if b.get("port_building", false) and ports.is_empty():
			errs.append("building %s: no ports" % bid)
		if mk == "processor" and not buildings.has(str(b.get("station", ""))):
			errs.append("machine %s: station is not a building" % bid)
	for res_id: String in resources:
		if not items.has(str(resources[res_id].get("item", ""))):
			errs.append("resource %s: unknown item" % res_id)
	for biome_id: String in biomes:
		var bw: Variant = biomes[biome_id].get("resources", {})
		if typeof(bw) == TYPE_DICTIONARY:
			for res_id: String in bw:
				if not resources.has(res_id):
					errs.append("biome %s: unknown resource %s" % [biome_id, res_id])
	errs.append_array(Tech.validate(research, self))  # region R2a
	# region L5: power / logistics-2 data
	const NODE_KINDS := ["splitter_basic", "splitter_smart", "splitter_priority", "merger"]
	for tid: String in research:
		for nk: String in research[tid].get("unlocks", {}).get("belt_nodes", []):
			if not nk in NODE_KINDS:
				errs.append("tech %s: unknown belt node %s" % [tid, nk])
	for bid: String in buildings:
		var pb: Dictionary = buildings[bid]
		if float(pb.get("power_use", 0.0)) < 0.0:
			errs.append("building %s: negative power_use" % bid)
		if pb.has("power_pole") or pb.has("power_range"):
			if float(pb.get("power_range", 0.0)) < 3.0:
				errs.append("pole %s: power_range < 3" % bid)
		if pb.has("power_gen"):
			if float(pb["power_gen"]) <= 0.0:
				errs.append("generator %s: power_gen <= 0" % bid)
			var fu: Variant = pb.get("fuel", null)
			if fu != null:
				if typeof(fu) != TYPE_DICTIONARY or not items.has(str(fu.get("item", ""))) or int(fu.get("burn_ticks", 0)) <= 0:
					errs.append("generator %s: bad fuel" % bid)
				elif not fuels.is_empty() and not fuels.get("fuels", {}).has(str(fu["item"])):
					errs.append("generator %s: fuel %s missing in fuels.json" % [bid, fu["item"]])
	for fid: String in fuels.get("fuels", {}):
		var fd: Dictionary = fuels["fuels"][fid]
		if not items.has(fid):
			errs.append("fuel %s: unknown item" % fid)
		if not buildings.has(str(fd.get("generator", ""))):
			errs.append("fuel %s: unknown generator" % fid)
		if not research.has(str(fd.get("tech", ""))):
			errs.append("fuel %s: unknown tech" % fid)
		if fd.has("spent_item") and not items.has(str(fd["spent_item"])):
			errs.append("fuel %s: unknown spent_item" % fid)
	# endregion
	return errs
# endregion


func bal(section: String, key: String) -> Variant:
	return balance[section][key]


func job_priority(job_type: String) -> int:
	return int(jobs.get(job_type, 0))


func zone_accepts(zone_id: String, item_id: String) -> bool:
	if not zones.has(zone_id):
		return false
	return item_id in zones[zone_id]["accepts"]


func item_stack(item_id: String) -> int:
	return int(items[item_id]["stack"])


static func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		push_error("Defs: cannot read " + path)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Defs: invalid JSON in " + path)
		return {}
	var d: Dictionary = parsed
	d.erase("_comment")
	return d
