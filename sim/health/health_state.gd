class_name HealthState
extends RefCounted
## Per-colonist body state: injuries, blood and derived capacities.

var injuries: Array[Injury] = []
var blood := 1.0
var downed := false
## Parts that were destroyed (arms/legs): their capacity stays at zero.
var lost: Dictionary = {}
var base_move_ticks := 3
var moving := 1.0
var manipulation := 1.0
var consciousness := 1.0
var pain := 0.0
var work_acc := 0.0
# region doctor
## Building id of the bed (or shelter) the patient rests in, -1 = none.
var bed_id := -1
## Colonist id currently carrying this patient, -1 = none.
var carrier_id := -1
# endregion


func is_sick() -> bool:
	for i in injuries:
		if i.is_illness() and i.severity > 0.0:
			return true
	return false


func bleed_rate() -> float:
	var r := 0.0
	for i in injuries:
		if i.is_bleeding():
			r += i.bleed * i.severity
	return r


func part_damage(part: String) -> float:
	var s := 0.0
	for i in injuries:
		if i.part == part and not i.is_illness():
			s += i.severity
	return s


func total_damage() -> float:
	var s := 0.0
	for i in injuries:
		if not i.is_illness():
			s += i.severity
	return s


func is_untouched() -> bool:
	return injuries.is_empty() and blood >= 1.0


# region C4
## Derived band: "fit", "wounded" or "down". Parts and injuries stay the truth.
func band(cfg: Dictionary) -> String:
	if downed:
		return "down"
	var b: Dictionary = cfg["band"]
	if blood < float(b["wounded_blood"]) or total_damage() >= float(b["wounded_damage"]):
		return "wounded"
	return "fit"


## Ticks until blood reaches zero at the current bleed rate, -1 if not bleeding.
func bleed_out_ticks() -> int:
	var r := bleed_rate()
	if r <= 0.0:
		return -1
	return ceili(blood / r)
# endregion
