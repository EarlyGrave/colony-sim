class_name WorkGiver
extends RefCounted
## Base class of work givers. A giver belongs to one work type (data/work.json)
## and finds the best job of its kind for an idle colonist, or null.
## Register new givers with one line in giver_registry.gd.

## Unique giver id, referenced from data/work.json "givers".
var id := ""
## Work type this giver serves (informational; data/work.json is authoritative).
var work_type := ""
var sim: Simulation


func _init(p_sim: Simulation) -> void:
	sim = p_sim


## Nearest valid job for `c`, with reservations / fail_key set, or null.
func find(_c: Colonist) -> Job:
	return null
