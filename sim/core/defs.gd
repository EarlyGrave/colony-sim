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
# region perks
var perks: Dictionary = {}
var quality: Dictionary = {}  # region quality
# endregion
# endregion

# region raids
var raids: Dictionary = {}
# endregion
# region needs
var time: Dictionary = {}
var needs: Dictionary = {}
var plants: Dictionary = {}
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
	# region perks
	perks = _load_json(dir + "perks.json")
	quality = _load_json(dir + "quality.json")  # region quality
	# endregion
	# endregion
	# region raids
	raids = _load_json(dir + "raids.json")
	# endregion
	# region needs
	time = _load_json(dir + "time.json")
	needs = _load_json(dir + "needs.json")
	plants = _load_json(dir + "plants.json")
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
	# region perks
	d.perks = perks.duplicate(true)
	d.quality = quality.duplicate(true)  # region quality
	# endregion
	# endregion
	# region raids
	d.raids = raids.duplicate(true)
	# endregion
	# region needs
	d.time = time.duplicate(true)
	d.needs = needs.duplicate(true)
	d.plants = plants.duplicate(true)
	# endregion
	return d


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
