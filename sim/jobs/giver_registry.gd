class_name GiverRegistry
extends RefCounted
## All work givers. Append-only: add one line per giver in create_all().


static func create_all(sim: Simulation) -> Dictionary:
	var list: Array[WorkGiver] = []
	# --- one line per giver, append below ---
	list.append(MineGiver.new(sim))
	list.append(HaulGiver.new(sim))
	list.append(OperateGiver.new(sim))
	list.append(RepairGiver.new(sim))
	# --- end of registrations ---
	var out: Dictionary = {}
	for g in list:
		out[g.id] = g
	return out
