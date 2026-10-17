class_name CombatState
extends RefCounted
## Per-colonist combat component: weapon, draft flag, orders, attack cooldown.

var weapon := "prison_shiv"
# region ammo
## Rounds in the rifle pouch (-1 = not yet initialised) and fractional use carry-over.
var pouch := -1
var ammo_debt := 0.0
var ammo_empty_flagged := false
# endregion
var drafted := false
## Tick from which the next attack is allowed.
var next_attack_tick := 0
## Ordered attack target (enemy id) or -1.
var target_id := -1
## Ordered move destination or (-1, -1).
var order_cell := Vector2i(-1, -1)


func clear_orders() -> void:
	target_id = -1
	order_cell = Vector2i(-1, -1)
