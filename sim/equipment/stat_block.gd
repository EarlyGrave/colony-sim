class_name StatBlock
extends RefCounted
## Fixed-index stat vector shared by attackers and defenders (PackedFloat64Array of N).
## New stat = one line in KEYS. Never look stats up by string in the hit path; use the index constants.

const KEYS: Array[String] = [
	"accuracy", "crit_chance", "crit_mult",
	"pen_pct_phys", "pen_pct_energy", "flat_pen_phys", "flat_pen_energy",
	"armor_phys", "armor_energy", "flat_phys", "flat_energy",
	"damage",  # region E4: weapon base damage (summed for the gear panel; hit path still takes dmg_base)
]
const ACC := 0
const CRIT := 1
const CRIT_MULT := 2
const PEN_PHYS := 3
const PEN_ENERGY := 4
const FPEN_PHYS := 5
const FPEN_ENERGY := 6
const ARM_PHYS := 7
const ARM_ENERGY := 8
const FLAT_PHYS := 9
const FLAT_ENERGY := 10
const DAMAGE := 11
const N := 12
const DEFAULT_CRIT_MULT := 1.5


# region E4
static var IDX: Dictionary = _build_idx()


static func _build_idx() -> Dictionary:
	var d := {}
	for i in KEYS.size():
		d[KEYS[i]] = i
	return d
# endregion


static func make() -> PackedFloat64Array:
	var a := PackedFloat64Array()
	a.resize(N)
	a[CRIT_MULT] = DEFAULT_CRIT_MULT
	return a


static func idx(key: String) -> int:
	return KEYS.find(key)


## Adds a {key: value} dictionary into `packed`; unknown keys are ignored.
static func sum_into(packed: PackedFloat64Array, dict: Dictionary, mult := 1.0) -> void:  # region E4: mult
	for k in dict:
		var i := KEYS.find(str(k))
		if i >= 0:
			packed[i] += float(dict[k]) * mult
