class_name StatBlock
extends RefCounted
## Fixed-index stat vector shared by attackers and defenders (PackedFloat64Array of N).
## New stat = one line in KEYS. Never look stats up by string in the hit path; use the index constants.

const KEYS: Array[String] = [
	"accuracy", "crit_chance", "crit_mult",
	"pen_pct_phys", "pen_pct_energy", "flat_pen_phys", "flat_pen_energy",
	"armor_phys", "armor_energy", "flat_phys", "flat_energy",
]
const IDX := {
	"accuracy": 0, "crit_chance": 1, "crit_mult": 2,
	"pen_pct_phys": 3, "pen_pct_energy": 4, "flat_pen_phys": 5, "flat_pen_energy": 6,
	"armor_phys": 7, "armor_energy": 8, "flat_phys": 9, "flat_energy": 10,
}
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
const N := 11
const DEFAULT_CRIT_MULT := 1.5
const IDX := {  # region PW3 compat: key -> index (used by equipment)
	"accuracy": 0, "crit_chance": 1, "crit_mult": 2, "pen_pct_phys": 3, "pen_pct_energy": 4,
	"flat_pen_phys": 5, "flat_pen_energy": 6, "armor_phys": 7, "armor_energy": 8, "flat_phys": 9, "flat_energy": 10,
}


static func make() -> PackedFloat64Array:
	var a := PackedFloat64Array()
	a.resize(N)
	a[CRIT_MULT] = DEFAULT_CRIT_MULT
	return a


static func idx(key: String) -> int:
	return KEYS.find(key)


## Adds a {key: value} dictionary into `packed`; unknown keys are ignored.
static func sum_into(packed: PackedFloat64Array, dict: Dictionary, mult: float = 1.0) -> void:
	for k in dict:
		var i := KEYS.find(str(k))
		if i >= 0:
			packed[i] += float(dict[k]) * mult
