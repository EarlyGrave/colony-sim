class_name GearItem
extends RefCounted
## One gear instance (owned by EquipmentSystem.instances). `stats` = flat {StatBlock key: value} summed
## from base + affixes + upgrades at creation/socket; durability scales the contribution at use time.

var id := 0
var base := ""
var slot := ""
var rarity := "common"
var ilvl := 0
var affixes: Array = []  # [[affix_id, value], ...] (filled by E3)
var upgrades: Array[String] = []
var durability := 100.0
var max_durability := 100.0
var owner := -1  # colonist id, -1 = unowned
var stats: Dictionary = {}


func resum_stats(defs: Defs) -> void:
	stats = {}
	var b: Dictionary = defs.gear.get(base, {})
	for k: String in b:
		if k == "armor" or k == "flat":
			for kind: String in b[k]:
				_add("%s_%s" % [k, kind], float(b[k][kind]))
		elif StatBlock.IDX.has(k) and (b[k] is float or b[k] is int):
			_add(k, float(b[k]))
	# region E3: affix values
	for a in affixes:
		_add(str(a[0]), float(a[1]))
	# endregion
	for u in upgrades:
		var ud: Dictionary = defs.upgrades.get(u, {})
		for k: String in ud.get("stats", {}):
			_add(k, float(ud["stats"][k]))


func _add(k: String, v: float) -> void:
	stats[k] = float(stats.get(k, 0.0)) + v


## Stat contribution multiplier: 1 above half durability, falling linearly to `zero_stat_mult` at 0.
func dur_mult(cfg: Dictionary) -> float:
	var half := max_durability * 0.5
	if durability >= half or half <= 0.0:
		return 1.0
	return lerpf(float(cfg.get("zero_stat_mult", 0.5)), 1.0, durability / half)
