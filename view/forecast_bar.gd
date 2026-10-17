class_name ForecastBar
extends Control
## Contamination bar with crisis-threshold ticks. Colour shifts green -> amber -> red
## as the next crisis threshold approaches. Reads sim state only.

var sim: Simulation


func _init() -> void:
	custom_minimum_size = Vector2(0, 16)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func bind(p_sim: Simulation) -> void:
	sim = p_sim
	queue_redraw()


## Sorted crisis thresholds (fractions 0..1) from data/crises.json.
static func thresholds(p_sim: Simulation) -> Array[float]:
	var out: Array[float] = []
	for id: String in p_sim.defs.crises["crises"]:
		out.append(float(p_sim.defs.crises["crises"][id]["threshold"]))
	out.sort()
	return out


## Distance from `frac` to the next threshold above it (1.0 when none is left).
static func margin_to_next(frac: float, ths: Array[float]) -> float:
	for t in ths:
		if t > frac:
			return t - frac
	return 0.0 if not ths.is_empty() and frac >= ths[-1] else 1.0


static func tint(frac: float, ths: Array[float]) -> Color:
	var m := margin_to_next(frac, ths)
	if m <= 0.0:
		return Color(1.0, 0.25, 0.2)
	if m > 0.2:
		return Color(0.45, 0.85, 0.4)
	if m > 0.08:
		return Color(0.45, 0.85, 0.4).lerp(Color(1.0, 0.8, 0.25), 1.0 - (m - 0.08) / 0.12)
	return Color(1.0, 0.8, 0.25).lerp(Color(1.0, 0.25, 0.2), 1.0 - m / 0.08)


func _process(_d: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	var w := size.x
	var h := size.y
	var f := clampf(sim.contamination.fraction(), 0.0, 1.0)
	var ths := thresholds(sim)
	draw_rect(Rect2(0, 0, w, h), Color(0.1, 0.1, 0.13))
	draw_rect(Rect2(0, 0, w * f, h), tint(f, ths))
	for t in ths:
		var x := w * t
		draw_rect(Rect2(x - 1.5, 0, 3, h), Color(1, 1, 1, 0.35 if t <= f else 0.9))
