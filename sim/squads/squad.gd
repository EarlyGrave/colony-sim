class_name Squad
extends RefCounted
## One squad of up to `roles.max_size` inmates. Plain data; SquadSystem owns the logic.

var id := 0
var name := ""
var members: Array[int] = []
var role_of: Dictionary = {}  # colonist id -> role id
var weapon_before: Dictionary = {}  # colonist id -> weapon id before the role weapon
var hold := Vector2i(-1, -1)  # anchor cell, (-1,-1) = none
var focus := -1  # enemy id or -1
var slot_cell: Dictionary = {}  # colonist id -> assigned cell (for re-hold after a focus ends)


func state_part() -> Array:
	var roles: Array = []
	for m in members:
		roles.append([m, role_of.get(m, "")])
	return [id, roles, hold, focus]
