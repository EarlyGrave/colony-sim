class_name Skills
extends RefCounted
## Per-colonist skills (level, xp, passion) and work priorities.
## Pure data + small helpers; randomness comes from the sim RNG at creation.

enum Passion { NONE, MINOR, MAJOR }
const PASSION_NAMES: Array[String] = ["none", "minor", "major"]

var levels: Dictionary = {}    # skill id -> int
var xp: Dictionary = {}        # skill id -> float (progress inside the level)
var passions: Dictionary = {}  # skill id -> Passion
## work type id -> 0 (off) or 1..max_priority (lower is done first).
var priorities: Dictionary = {}


## Deterministic initial skills; draws a fixed number of values from `rng`.
static func create(defs: Defs, rng: RandomNumberGenerator) -> Skills:
	var s := Skills.new()
	var init: Dictionary = defs.skills["init"]
	for id: String in defs.skills["skills"]:
		s.levels[id] = rng.randi_range(int(init["level_min"]), int(init["level_max"]))
		s.xp[id] = 0.0
		var r := rng.randf()
		if r < float(init["major_chance"]):
			s.passions[id] = Passion.MAJOR
		elif r < float(init["major_chance"]) + float(init["minor_chance"]):
			s.passions[id] = Passion.MINOR
		else:
			s.passions[id] = Passion.NONE
	for t: String in defs.work["types"]:
		s.priorities[t] = int(defs.work["default_priority"])
	return s


func level(skill: String) -> int:
	return int(levels.get(skill, 0))


func priority(work_type: String) -> int:
	return int(priorities.get(work_type, 0))


## Work-speed multiplier for a skill ("" = unskilled work = 1.0).
func speed_mult(defs: Defs, skill: String) -> float:
	if skill == "" or not levels.has(skill):
		return 1.0
	return 1.0 + float(defs.skills["speed_per_level"]) * level(skill)


func xp_needed(defs: Defs, skill: String) -> float:
	return float(defs.skills["xp_base"]) + float(defs.skills["xp_step"]) * level(skill)


## Adds `amount` xp (before passion). Returns true if the level changed.
func add_xp(defs: Defs, skill: String, amount: float) -> bool:
	if not levels.has(skill):
		return false
	var max_level := int(defs.skills["max_level"])
	if level(skill) >= max_level:
		return false
	var mult := float(defs.skills["passion_xp"][PASSION_NAMES[int(passions.get(skill, Passion.NONE))]])
	xp[skill] = float(xp[skill]) + amount * mult
	var leveled := false
	while level(skill) < max_level and float(xp[skill]) >= xp_needed(defs, skill):
		xp[skill] = float(xp[skill]) - xp_needed(defs, skill)
		levels[skill] = level(skill) + 1
		leveled = true
	if level(skill) >= max_level:
		xp[skill] = 0.0
	return leveled
