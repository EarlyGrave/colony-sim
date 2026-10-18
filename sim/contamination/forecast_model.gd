class_name ForecastModel
extends RefCounted
## Pure formula for the "end of the planet" forecast.
##
##   days  = (max - level) / max(rate, min_rate)
##   error = days * (base_error + error_growth * level / max)
##
## The estimate shrinks as contamination and its rate grow, and becomes less
## certain the closer the planet is to the end.


## `machine_rate` (units/day) is what the running machines will add even if the
## smoothed measurement has not caught up yet (a smelter just came online).
static func estimate(level: float, rate_per_day: float, cfg: Dictionary, machine_rate := 0.0) -> Dictionary:
	var max_level := float(cfg["max"])
	var remaining := maxf(0.0, max_level - level)
	var rate := maxf(maxf(rate_per_day, machine_rate), float(cfg["min_rate_per_day"]))
	var days := remaining / rate
	var rel_err := float(cfg["base_error"]) + float(cfg["error_growth"]) * clampf(level / max_level, 0.0, 1.0)
	return {"days": days, "error": days * rel_err}
