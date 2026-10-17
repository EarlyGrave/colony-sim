class_name WorldClock
extends RefCounted
## Time of day derived from the tick counter (no state of its own).
## Numbers live in data/time.json.

var sim: Simulation
var cfg: Dictionary


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	cfg = sim.defs.time


## Hour of day, 0.0 <= h < 24.0, at tick `t` (default: now).
func hour(t := -1) -> float:
	if t < 0:
		t = sim.tick
	var frac := float(t % sim.ticks_per_day) / float(sim.ticks_per_day)
	return fposmod(float(cfg["start_hour"]) + 24.0 * frac, 24.0)


func hour_int(t := -1) -> int:
	return int(hour(t))


## 0 (night) .. 1 (full day), smooth through dawn and dusk.
func daylight(t := -1) -> float:
	var h := hour(t)
	var up := smoothstep(float(cfg["dawn_start"]), float(cfg["dawn_end"]), h)
	var down := 1.0 - smoothstep(float(cfg["dusk_start"]), float(cfg["dusk_end"]), h)
	return clampf(up * down, 0.0, 1.0)


func is_night(t := -1) -> bool:
	return daylight(t) < float(cfg["night_daylight"])
