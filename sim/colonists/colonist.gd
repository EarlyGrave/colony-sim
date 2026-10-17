class_name Colonist
extends GridMover
## A prisoner. State only plus movement; decisions come from JobSystem.

var id: int
var display_name: String
var hp: float
var max_hp: float
var alive := true
## Inside a shelter (invisible and untargetable).
var hidden := false
## Sick colonists don't work until this tick (they still flee on alarm).
var sick_until := 0
## Engineers can be sent to repair turrets during raids (rule "raid_engineer").
var engineer := false

var job: Job = null
var idle_until := 0
var carry_item := ""
var carry_count := 0
## job key -> tick until which that target is considered unreachable
var unreachable: Dictionary = {}

## Diagnostics: ticks since the colonist last changed cell while it had a job.
var stuck_ticks := 0


func _init(p_id: int, p_name: String, p_cell: Vector2i, cfg: Dictionary) -> void:
	id = p_id
	display_name = p_name
	cell = p_cell
	max_hp = float(cfg["max_hp"])
	hp = max_hp
	move_ticks = int(cfg["move_ticks"])


func is_sick(now: int) -> bool:
	return sick_until > now


func is_unreachable(key: String, now: int) -> bool:
	return int(unreachable.get(key, -1)) > now
