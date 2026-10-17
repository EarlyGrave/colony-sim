class_name ActiveEffects
extends RefCounted
## Handlers for active perks, keyed by the `active.id` field of data/perks.json.
## Each returns true if the effect fired (cooldown is only spent on success).

## `until` value of flags that stay set until a system consumes them.
const NO_EXPIRY := -1


static func apply(sys: PerkSystem, c: Colonist, active: Dictionary) -> bool:
	var params: Dictionary = active.get("params", {})
	var now := sys.sim.tick
	var st := sys.state_of(c)
	match str(active["id"]):
		"sprint":
			st.add_buff("sprint", {"move_speed": float(params["move_speed"])}, now + int(params["duration"]))
		"work_rush":
			st.add_buff("work_rush", {"work_speed": float(params["work_speed"])}, now + int(params["duration"]))
		"aimed_shot":
			st.add_buff("aimed_shot", {"hit_chance": float(params["hit_chance"])}, now + int(params["duration"]))
		"double_harvest":
			st.add_buff("double_harvest", {}, NO_EXPIRY)
		"masterwork":
			st.add_buff("masterwork", {}, NO_EXPIRY)
		"cold_start":
			st.add_buff("no_waste_next_batch", {}, NO_EXPIRY)
		"instant_tend":
			return _instant_tend(sys, c, params)
		"battle_cry":
			var r2 := int(params["radius"]) * int(params["radius"])
			for o in sys.sim.colonists.list:
				if o.alive and o.cell.distance_squared_to(c.cell) <= r2:
					sys.state_of(o).add_buff("battle_cry", {"hit_chance": float(params["hit_chance"])}, now + int(params["duration"]))
		_:
			return false
	return true


## Tends the nearest colonist (self included) that has an untended injury.
static func _instant_tend(sys: PerkSystem, c: Colonist, params: Dictionary) -> bool:
	var r2 := int(params["radius"]) * int(params["radius"])
	var best: Colonist = null
	var best_d := 1 << 30
	for o in sys.sim.colonists.list:
		if not o.alive or o.health == null:
			continue
		var d := o.cell.distance_squared_to(c.cell)
		if d > r2 or d >= best_d:
			continue
		for i in o.health.injuries:
			if not i.tended:
				best = o
				best_d = d
				break
	if best == null:
		return false
	return sys.sim.health.tend(best, c, float(params["quality_mult"])) > 0
