class_name Injury
extends RefCounted
## One wound or illness on a body part.

var kind: String
var part: String
## Damage points (illness: 0..1 intensity).
var severity: float
## Blood lost per tick per severity point while untended.
var bleed: float
var pain: float
var tended := false
var tend_quality := 0.0
## Illness only: severity lost per tick (so the duration is data driven).
var heal_per_tick := 0.0
var label := ""
## Illness id ("fever", "infection") for illnesses.
var illness_id := ""


func _init(p_kind: String, p_part: String, p_severity: float) -> void:
	kind = p_kind
	part = p_part
	severity = p_severity


func is_illness() -> bool:
	return kind == "illness"


func is_bleeding() -> bool:
	return not tended and bleed > 0.0 and severity > 0.0
