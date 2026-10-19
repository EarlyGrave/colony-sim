class_name ColonistGenerator
extends RefCounted
## Builds random newcomers (name, age, backstory, skills, traits).
## Names/backstories: data/names.json, traits: data/traits.json, ranges:
## data/arrivals.json. All randomness comes from sim.rng.


## Creates a colonist at `cell`. It is NOT added to the colony yet
## (see ColonistSystem.add).
static func generate(sim: Simulation, cell: Vector2i) -> Colonist:
	var defs := sim.defs
	var rng := sim.rng
	var cfg: Dictionary = defs.arrivals
	var names: Array = defs.names["names"]
	var stories: Array = defs.names["backstories"]
	var c := Colonist.new(sim.colonists.alloc_id(), str(names[rng.randi_range(0, names.size() - 1)]),
			cell, defs.balance["colonist"])
	c.skills = Skills.create(defs, rng)
	# QA: newcomers must be combat-capable too (draft/order commands read c.combat).
	c.combat = CombatState.new()
	c.combat.weapon = str(defs.weapons["combat"]["start_weapon"])
	var age := rng.randi_range(int(cfg["age_min"]), int(cfg["age_max"]))
	var story := str(stories[rng.randi_range(0, stories.size() - 1)])
	# region PW2: block first (data only), then the weighted trait draw (fixed rng draw count)
	var chosen: Array[String] = sim.traits.roll(rng, sim.blocks.block_of(c))
	var speed := 1.0
	var max_level := int(defs.skills["max_level"])
	for t in chosen:
		var d: Dictionary = defs.traits["traits"][t]
		speed += float((d.get("effects", {}) as Dictionary).get("work_speed", 0.0))
		var bonus: Dictionary = d.get("skills", {})
		for s: String in bonus:
			if c.skills.levels.has(s):
				c.skills.levels[s] = clampi(c.skills.level(s) + int(bonus[s]), 0, max_level)
	# endregion
	c.skills.mark_joined()
	c.bio = {"age": age, "backstory": story, "traits": chosen, "work_speed": speed}
	_q1_tag(sim, c)  # region Q1
	sim.blocks.block_of(c)  # region I1: tags the newcomer's block (data only, no rng)
	return c


# region Q1
## Tags some newcomers "Clerk" (data only, no rng) when quests are enabled.
static func _q1_tag(sim: Simulation, c: Colonist) -> void:
	if not bool(sim.defs.balance.get("q_enabled", false)):
		return
	var cfg: Dictionary = QuestClerkNote.load_cfg()
	var n := int(cfg.get("tag_every_nth_id", 0))
	if n > 0 and c.id % n == 0:
		c.bio["tag"] = str(cfg["tag"])
# endregion


static func trait_names(sim: Simulation, c: Colonist) -> Array[String]:
	var out: Array[String] = []
	for t: String in c.bio.get("traits", []):
		out.append(str(sim.traits.def(t).get("name", t)))
	return out
