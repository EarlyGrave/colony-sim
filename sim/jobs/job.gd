class_name Job
extends RefCounted
## Base job. A job is created by JobSystem for one colonist, holds
## reservations while running and is discarded when it ends.

enum Status { RUNNING, DONE, FAILED }

var type: String
var reservations: Array[String] = []
## Marked unreachable for this colonist (for a while) if the job fails.
var fail_key := ""


func tick(_c: Colonist, _sim: Simulation) -> int:
	return Status.DONE


## Called once when the job ends for any reason (done, failed, aborted).
func on_end(_c: Colonist, _sim: Simulation) -> void:
	pass


## Short human-readable description for the inspector.
func describe() -> String:
	return type
