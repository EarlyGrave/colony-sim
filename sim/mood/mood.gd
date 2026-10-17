class_name Mood
extends RefCounted
## Per-colonist mood state: active thoughts and the current break.

## Active thoughts: {"id": String, "value": float, "until": int (-1 = permanent)}.
var thoughts: Array[Dictionary] = []
var value := 50.0
## Current mental break kind ("" = none) and when it ends.
var break_kind := ""
var break_until := 0


func find(id: String) -> int:
	for i in thoughts.size():
		if thoughts[i]["id"] == id:
			return i
	return -1
