class_name StatBlock
extends RefCounted
## STUB (E2) matching combat_items.md section 7 API; E1's version replaces this file at merge.
## One fixed index per stat key; `sum_into` adds a {key: value} dictionary into a packed array.

const KEYS: Array[String] = [
	"damage", "dmg_pct", "crit_chance", "crit_mult", "accuracy", "attack_speed", "pen_pct_phys", "pen_pct_energy",
	"flat_pen_phys", "flat_pen_energy", "armor_phys", "armor_energy", "flat_phys", "flat_energy", "max_hp",
	"move_speed", "dodge", "ammo_eff", "durability_max",
]
static var IDX: Dictionary = _build_idx()


static func _build_idx() -> Dictionary:
	var d := {}
	for i in KEYS.size():
		d[KEYS[i]] = i
	return d


static func make() -> PackedFloat64Array:
	var p := PackedFloat64Array()
	p.resize(KEYS.size())
	return p


static func sum_into(packed: PackedFloat64Array, stats: Dictionary, mult: float = 1.0) -> void:
	for k: String in stats:
		var i: int = IDX.get(k, -1)
		if i >= 0:
			packed[i] += float(stats[k]) * mult
