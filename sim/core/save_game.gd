class_name SaveGame
extends RefCounted
## Save/load by command-log replay. The sim is deterministic, so
## {seed, defs hash, tick, command_log} fully describes a game.
## Plain data in/out; file IO lives in view/save_store.gd.

const VERSION := 2  # v2: infinite nodes + belts; v1 saves replay differently -> error "version" (incompatible)


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
			args.append(_enc_arg(a))  # region A1d
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
			if a is Dictionary and a.has("a"):  # region A1d: Vector2i list
				var cells: Array = []
				for p: Array in a["a"]:
					cells.append(Vector2i(int(p[0]), int(p[1])))
				args.append(cells)
			elif a is Dictionary:
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
	for b in sim.buildings.list:  # region T2
		if not b.decoy.is_empty():
			parts.append([b.id, b.decoy])
	parts.append(hash(sim.mutation.field))  # region mutation
	parts.append(sim.logistics.state_parts())  # region A1d
	parts.append(sim.research.state_parts())  # region R2a
	parts.append(sim.milestones.state_parts())  # region R2b
	if sim.beacons.has_state():  # region S2: absent until a beacon was launched
		parts.append(sim.beacons.state_parts())
	var pw: Array = sim.power.state_parts()  # region L3: only once a pole or generator exists
	if not pw.is_empty():
		parts.append(pw)
	if sim.traits_v3 != null:  # region F11W1: trait ids/counters only when the flag is on
		parts.append(sim.traits.state_parts())
	if sim.tutorial != null:  # region O1: only in tutorial mode, so other hashes stay as they were
		parts.append(sim.tutorial.state_parts())
	if not sim.regulations.chosen.is_empty():  # region W1: absent until a slot was answered
		parts.append([sim.regulations.chosen, sim.regulations.pending])
	if not sim.squads.list.is_empty():  # region C1: only while a squad exists, other hashes stay as they were
		parts.append(sim.squads.state_parts())
	if sim.equipment.has_state():  # region E2: only once a gear instance exists, goldens stay identical
		parts.append(sim.equipment.state_parts())
	var ab: Array = sim.abilities.state_parts()  # region C2: only after an ability was used
	if not ab.is_empty():
		parts.append(ab)
	if sim.shuttle.has_state():  # region S1: only once a shuttle part was delivered
		parts.append(sim.shuttle.state_parts())
	var qp: Array = sim.quests.state_parts()  # region Q0: only after a quest started
	if not qp.is_empty():
		parts.append(qp)
	if sim.blocks.has_state():  # region I1: only once a block moved or the Informant exists
		parts.append(sim.blocks.state_parts())
	var tgs: Array = sim.threats.telegraph_state()  # region C3: only while a wind-up is active
	if not tgs.is_empty():
		parts.append(tgs)
	var cb: Array = sim.contraband.state_parts()  # region I3: only after something was skimmed
	if not cb.is_empty():
		parts.append(cb)
	var cv: Array = sim.contraband.covert_state_parts()  # region N2: only once suspicion/credit exists
	if not cv.is_empty():
		parts.append(cv)
	var fe: Array = sim.fight_escape.state_parts()  # region EN3: only once an ending step happened
	if not fe.is_empty():
		parts.append(fe)
	var rm: Array = sim.remission.state_parts()  # region EN4: only once a cure was applied
	if not rm.is_empty():
		parts.append(rm)
	return var_to_str(parts).hash()


# region A1d
static func _enc_arg(a: Variant) -> Variant:
	if a is Vector2i:
		return {"v": [a.x, a.y]}
	if a is Array:
		var out: Array = []
		for c: Vector2i in a:
			out.append([c.x, c.y])
		return {"a": out}
	return a
# endregion


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


# region R4d
## Campaign saves (v3). Sim saves keep VERSION 2. Each map is replayed standalone to its own
## tick (the v2 `_replay`); ledgers, in-flight cargo/parties and the campaign log are plain data.
const CAMPAIGN_VERSION := 3
const CAMPAIGN_SCRIPT := "res://sim/campaign/campaign.gd"


## `c` is a Campaign (fields: maps, tick, active, campaign_seed, log, in_flight, ledgers, defs).
static func campaign_to_dict(c: Object) -> Dictionary:
	var maps: Array = []
	for m: Dictionary in c.maps:
		var sim: Simulation = m["sim"]
		var d := to_dict(sim)
		maps.append({"id": int(m["id"]), "biome": str(m.get("biome", "")), "kind": str(m.get("kind", "outpost")),
			"seed": sim.seed_value, "opts": d["opts"], "sim_commands": d["commands"], "sim_tick": sim.tick,
			"crew_n": int(m.get("crew_n", 0)), "dead_charged": int(m.get("dead_charged", 0)),
			"sling_ready": int(m.get("sling_ready", 0))})
	var ledgers: Dictionary = {}
	for k: Variant in c.ledgers:
		ledgers[str(k)] = c.ledgers[k]
	return {"version": CAMPAIGN_VERSION, "campaign_seed": c.campaign_seed, "defs_hash": defs_hash(c.defs),
		"tick": c.tick, "active": c.active, "log": c.log, "maps": maps, "ledgers": ledgers,
		"in_flight": c.in_flight, "k2": c.home_sim().milestones.k2_export()}  # region K2


static func campaign_to_json(c: Object) -> String:
	return JSON.stringify(campaign_to_dict(c))


## Returns {"ok", "error" ("corrupt"/"version"/"defs_changed"), "campaign"}. v2 (single-map) saves
## give error "version". `campaign_script` defaults to W3's Campaign; it only needs the plain fields.
static func campaign_from_dict(data: Dictionary, bus_factory: Callable, p_defs: Defs = null, campaign_script: Script = null) -> Dictionary:
	var defs := p_defs if p_defs != null else Defs.get_default()
	if not data.has("version"):
		return {"ok": false, "error": "corrupt", "campaign": null}
	if int(data["version"]) != CAMPAIGN_VERSION:
		return {"ok": false, "error": "version", "campaign": null}
	for k in ["campaign_seed", "defs_hash", "tick", "active", "maps", "ledgers", "in_flight", "log"]:
		if not data.has(k):
			return {"ok": false, "error": "corrupt", "campaign": null}
	if int(data["defs_hash"]) != defs_hash(defs):
		return {"ok": false, "error": "defs_changed", "campaign": null}
	var script := campaign_script
	if script == null and ResourceLoader.exists(CAMPAIGN_SCRIPT):
		script = load(CAMPAIGN_SCRIPT)
	if script == null:
		return {"ok": false, "error": "corrupt", "campaign": null}
	var c: Object = script.new(int(data["campaign_seed"]), bus_factory, defs)
	var maps: Array = []
	for md: Dictionary in data["maps"]:
		var sim_data := {"version": VERSION, "seed": int(md["seed"]), "defs_hash": data["defs_hash"],
			"tick": int(md["sim_tick"]), "commands": md["sim_commands"], "opts": _intify(md.get("opts", {}))}
		var sim := _replay(sim_data, bus_factory.call(), defs, Callable())
		maps.append({"id": int(md["id"]), "biome": str(md["biome"]), "kind": str(md["kind"]), "sim": sim,
			"seed": int(md["seed"]), "opts": sim_data["opts"], "crew_n": int(md.get("crew_n", 0)),
			"dead_charged": int(md.get("dead_charged", 0)), "sling_ready": int(md.get("sling_ready", 0))})
	var ledgers: Dictionary = {}
	for k: String in data["ledgers"]:
		ledgers[int(k) if k.is_valid_int() else k] = _intify(data["ledgers"][k])
	c.maps = maps
	c.tick = int(data["tick"])
	c.active = int(data["active"])
	c.campaign_seed = int(data["campaign_seed"])
	c.log = _intify(data["log"])
	c.in_flight = _intify(data["in_flight"])
	c.ledgers = ledgers
	if data.has("k2") and not maps.is_empty():  # region K2: outpost-day counters are not replayable from commands
		(maps[0]["sim"] as Simulation).milestones.k2_import(_intify(data["k2"]))
	return {"ok": true, "error": "", "campaign": c}


static func campaign_from_json(text: String, bus_factory: Callable, p_defs: Defs = null, campaign_script: Script = null) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(text) != OK or not (parser.data is Dictionary):
		return {"ok": false, "error": "corrupt", "campaign": null}
	return campaign_from_dict(parser.data, bus_factory, p_defs, campaign_script)


## JSON turns every number into a float; whole floats go back to int (recursive).
static func _intify(v: Variant) -> Variant:
	if v is float and v == floorf(v):
		return int(v)
	if v is Array:
		var a: Array = []
		for x: Variant in v:
			a.append(_intify(x))
		return a
	if v is Dictionary:
		var d: Dictionary = {}
		for k: Variant in v:
			d[k] = _intify(v[k])
		return d
	return v
# endregion
