class_name SaveGame
extends RefCounted
## Save/load by command-log replay. The sim is deterministic, so
## {seed, defs hash, tick, command_log} fully describes a game.
## Plain data in/out; file IO lives in view/save_store.gd.

const VERSION := 1


static func defs_hash(defs: Defs) -> int:
	# Every Dictionary property of Defs, so new data files are covered automatically.
	var parts: Array = []
	for p in defs.get_property_list():
		if p["type"] == TYPE_DICTIONARY and (p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE):
			parts.append([p["name"], defs.get(p["name"])])
	return JSON.stringify(parts, "", true).hash()


static func to_dict(sim: Simulation) -> Dictionary:
	var out_log: Array = []
	for e: Array in sim.command_log:
		var args: Array = []
		for a: Variant in e[2]:
			args.append({"v": [a.x, a.y]} if a is Vector2i else a)
		out_log.append([e[0], e[1], args])
	return {"version": VERSION, "seed": sim.seed_value, "defs_hash": defs_hash(sim.defs),
		"tick": sim.tick, "commands": out_log, "opts": sim.opts}  # region meta


static func to_json(sim: Simulation) -> String:
	return JSON.stringify(to_dict(sim))


## Returns {"ok": bool, "error": String ("corrupt"/"version"/"defs_changed"), "sim": Simulation}.
## `on_progress(done_ticks, total)` is called every 500 ticks (may be empty).
static func load_dict(data: Dictionary, bus: Object, p_defs: Defs = null, on_progress := Callable()) -> Dictionary:
	var defs := p_defs if p_defs != null else Defs.get_default()
	var err := _check(data, defs)
	if err != "":
		return {"ok": false, "error": err, "sim": null}
	return {"ok": true, "error": "", "sim": _replay(data, bus, defs, on_progress)}


static func load_json(text: String, bus: Object, p_defs: Defs = null, on_progress := Callable()) -> Dictionary:
	var parser := JSON.new()  # parse() reports errors silently, unlike parse_string()
	if parser.parse(text) != OK:
		return {"ok": false, "error": "corrupt", "sim": null}
	var parsed: Variant = parser.data
	if not (parsed is Dictionary):
		return {"ok": false, "error": "corrupt", "sim": null}
	return load_dict(parsed, bus, p_defs, on_progress)


static func _check(data: Dictionary, defs: Defs) -> String:
	for k in ["version", "seed", "defs_hash", "tick", "commands"]:
		if not data.has(k):
			return "corrupt"
	if int(data["version"]) != VERSION:
		return "version"
	if int(data["defs_hash"]) != defs_hash(defs):
		return "defs_changed"
	return ""


static func _replay(data: Dictionary, bus: Object, defs: Defs, on_progress: Callable) -> Simulation:
	var sim := Simulation.new(int(data["seed"]), bus, defs, _opts_from(data))  # region meta
	sim.start_new_game()
	sim.replaying = true
	var cmds: Array = []
	for e: Array in data["commands"]:
		var args: Array = []
		for a: Variant in e[2]:
			if a is Dictionary:
				args.append(Vector2i(int(a["v"][0]), int(a["v"][1])))
			elif a is float:
				args.append(int(a))
			else:
				args.append(a)
		cmds.append([int(e[0]), str(e[1]), args])
	var target := int(data["tick"])
	var i := 0
	while true:
		# Commands recorded at tick T were issued before step() number T+1.
		while i < cmds.size() and cmds[i][0] <= sim.tick:
			sim.callv(cmds[i][1], cmds[i][2])
			i += 1
		if sim.tick >= target or sim.game_over_reason != "":
			break
		sim.step()
		if on_progress.is_valid() and sim.tick % 500 == 0:
			on_progress.call(sim.tick, target)
	sim.replaying = false
	sim.command_log = cmds.duplicate()
	return sim


## Hash of the observable state (items, colonists, buildings, tick).
static func state_hash(sim: Simulation) -> int:
	var parts: Array = [sim.tick, sim.game_over_reason, sim.alarm]
	for c in sim.items.stacks:
		parts.append([c, sim.items.stacks[c]])
	for col in sim.colonists.list:
		parts.append([col.id, col.cell, col.hp, col.alive, col.carry_item, col.carry_count, col.carry_quality, col.perks.learned if col.perks != null else []])
	for b in sim.buildings.list:
		parts.append([b.id, b.def_id, b.cell, b.hp, b.condition, b.broken, b.input, b.output, b.output_q])
		parts.append([b.id, b.def_id, b.cell, b.hp, b.condition, b.broken, b.input, b.output, b.ammo, b.ammo_policy])  # region ammo
	parts.append(hash(sim.mutation.field))  # region mutation
	return var_to_str(parts).hash()


# region meta
## Opts survive JSON (ints come back as floats); normalise numeric keys.
static func _opts_from(data: Dictionary) -> Dictionary:
	var o: Dictionary = (data.get("opts", {}) as Dictionary).duplicate(true)
	for k in ["scout", "site"]:
		if o.has(k):
			o[k] = int(o[k])
	if o.has("crate"):
		for item: String in o["crate"]:
			o["crate"][item] = int(o["crate"][item])
	return o
# endregion
