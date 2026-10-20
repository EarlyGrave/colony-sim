class_name MimicFace
extends RefCounted
## F4f: after Q15 "Roll Call" (flag clue_our_dead) a mimic shows the name of the inmate it wears.
## View-side and read-only: asks Enemy.name_of_dead, never touches sim state. Before the flag it returns "" (no leak).

const FLAG := "clue_our_dead"
const K_WEARS := "mimic.wears"
const K_GONE := "mimic.gone"


static func revealed(sim: Simulation) -> bool:
	return sim != null and sim.quests != null and sim.quests.flag(FLAG)


## Name worn by mimic `e` ("" = unknown / not a mimic / reveal not unlocked yet).
static func worn_name(sim: Simulation, e: Enemy) -> String:
	if e == null or not revealed(sim):
		return ""
	return e.name_of_dead(sim.colonists.list)


## Same for a mimic already gone from the list (enemy ids are unique; the pick depends only on id + the dead).
static func worn_name_by_id(sim: Simulation, id: int, kind: String) -> String:
	if kind != "mimic" or not revealed(sim):
		return ""
	return Enemy.new(id, kind, {}, Vector2i.ZERO).name_of_dead(sim.colonists.list)


static func inspect_line(sim: Simulation, e: Enemy, picker: FlavorPicker) -> String:
	var who := worn_name(sim, e)
	return "" if who == "" else picker.pick(K_WEARS, {"who": who})


static func gone_line(sim: Simulation, id: int, kind: String, picker: FlavorPicker) -> String:
	var who := worn_name_by_id(sim, id, kind)
	return "" if who == "" else picker.pick(K_GONE, {"who": who})
