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
	var age := rng.randi_range(int(cfg["age_min"]), int(cfg["age_max"]))
	var story := str(stories[rng.randi_range(0, stories.size() - 1)])
	var pool: Array[String] = []
	for id: String in defs.traits["traits"]:
		pool.append(id)
	var chosen: Array[String] = []
	for i in int(cfg["max_traits"]):
		if rng.randf() < float(cfg["trait_chance"]) and not pool.is_empty():
			chosen.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	var speed := 1.0
	var max_level := int(defs.skills["max_level"])
	for t in chosen:
		var d: Dictionary = defs.traits["traits"][t]
		speed += float(d.get("work_speed", 0.0))
		var bonus: Dictionary = d.get("skills", {})
		for s: String in bonus:
			if c.skills.levels.has(s):
				c.skills.levels[s] = clampi(c.skills.level(s) + int(bonus[s]), 0, max_level)
	c.skills.mark_joined()
	c.bio = {"age": age, "backstory": story, "traits": chosen, "work_speed": speed}
	return c


static func trait_names(sim: Simulation, c: Colonist) -> Array[String]:
	var out: Array[String] = []
	for t: String in c.bio.get("traits", []):
		out.append(str(sim.defs.traits["traits"][t]["name"]))
	return out
