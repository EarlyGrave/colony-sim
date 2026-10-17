class_name ColonistPerks
extends RefCounted
## Per-colonist perk state: learned perks, cooldowns and buffs/one-shot flags.
## Plain data; rules live in PerkSystem. Other systems must not read it directly.

## Learned perk ids, in learning order.
var learned: Array[String] = []
## perk id -> tick when it can be used again.
var cooldowns: Dictionary = {}
## buff id -> {"stats": {stat: value}, "until": tick or -1 (until consumed)}.
## Flags ("masterwork", "double_harvest", ...) are buffs with empty stats.
var buffs: Dictionary = {}


func add_buff(id: String, stats: Dictionary, until: int) -> void:
	buffs[id] = {"stats": stats, "until": until}
