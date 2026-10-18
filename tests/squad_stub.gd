class_name SquadStub
extends RefCounted
## Test double for the C1/C2 squad API (the real one lands in another branch). Same surface the
## C5 UI uses: `squads.list`, `form_squad`, `disband_squad`, `squad_hold`, `squad_focus`,
## `use_ability`, `abilities.ready_in`, plus `colonists`. Every command is recorded in `calls`.


class Sq extends RefCounted:
	var id := 0
	var name := ""
	var members: Array = []
	var role_of: Dictionary = {}
	var hold := Vector2i(-1, -1)
	var focus := -1


class Holder extends RefCounted:
	var list: Array = []
	var cooldowns: Dictionary = {}

	func ready_in(sid: int, ability: String) -> int:
		return int(cooldowns.get("%d:%s" % [sid, ability], 0))


var squads := Holder.new()
var abilities: Holder = squads
var colonists: Object
var calls: Array = []
var _next := 1


func _init(p_colonists: Object = null) -> void:
	colonists = p_colonists


func count(cmd: String) -> int:
	var n := 0
	for c: Array in calls:
		if c[0] == cmd:
			n += 1
	return n


func form_squad(ids: Array, roles: Array = []) -> int:
	calls.append(["form_squad", ids, roles])
	var s := Sq.new()
	s.id = _next
	s.name = "Squad %d" % _next
	_next += 1
	s.members = ids.duplicate()
	for i in mini(ids.size(), roles.size()):
		s.role_of[ids[i]] = roles[i]
	squads.list.append(s)
	return s.id


func disband_squad(sid: int) -> bool:
	calls.append(["disband_squad", sid])
	for s: Sq in squads.list:
		if s.id == sid:
			squads.list.erase(s)
			return true
	return false


func squad_hold(sid: int, cell: Vector2i) -> bool:
	calls.append(["squad_hold", sid, cell])
	for s: Sq in squads.list:
		if s.id == sid:
			s.hold = cell
	return true


func squad_focus(sid: int, enemy_id: int) -> bool:
	calls.append(["squad_focus", sid, enemy_id])
	return true


func use_ability(sid: int, ability: String) -> bool:
	calls.append(["use_ability", sid, ability])
	return true
