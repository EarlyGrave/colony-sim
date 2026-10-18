extends RefCounted
## Golden replays: command logs + state hashes every STEP ticks. Shared by
## tests/test_golden.gd (verify) and tools/make_golden.gd (regenerate).
## File format (tests/golden/<name>.json):
##   {name, seed, peaceful, opts, ticks, reload_at, commands:[[tick,name,args]],
##    hashes:{"100": state_hash,...}, parts:{"100": {part: hash,...},...}}
## `hashes` = SaveGame.state_hash; `parts` split the observable state so a
## divergence can name the system that differs.

const STEP := 100
const TOTAL := 3000
const Scen := preload("res://tests/scenario.gd")
const NAMES: Array[String] = ["peaceful_mining", "raid_turrets", "automation_chain", "contamination_crisis", "save_load_midgame",
		"preset_short_stay", "preset_standard_term", "preset_hard_time"]  # region O3

## name -> {seed, peaceful, opts, reload_at}. Keep crate keys alphabetical: JSON.stringify sorts them and crate drop order matters.
const SPECS := {
	"peaceful_mining": {"seed": 1, "peaceful": true, "opts": {}, "reload_at": 0},
	"raid_turrets": {"seed": 2, "peaceful": false, "opts": {"crate": {"essence_ore": 60, "refined_essence": 60}}, "reload_at": 0},
	"automation_chain": {"seed": 3, "peaceful": true, "opts": {"crate": {"essence_ore": 200}}, "reload_at": 0},
	"contamination_crisis": {"seed": 4, "peaceful": false, "opts": {"contamination": 55.0, "crate": {"essence_ore": 120}}, "reload_at": 0},
	"save_load_midgame": {"seed": 5, "peaceful": true, "opts": {"crate": {"essence_ore": 100, "refined_essence": 20}}, "reload_at": 1500},
	# region O3: raid_turrets script under each preset (opts from StartOpts.preset_opts; crates keep alphabetical keys)
	"preset_short_stay": {"seed": 2, "peaceful": false, "opts": {"wave_mult": 0.75, "waste_mult": 0.8, "debt_mult": 0.7, "crate": {"essence_ore": 40, "raw_food": 30}, "hint_density": "full"}, "reload_at": 0},
	"preset_standard_term": {"seed": 2, "peaceful": false, "opts": {}, "reload_at": 0},
	"preset_hard_time": {"seed": 2, "peaceful": false, "opts": {"wave_mult": 1.3, "waste_mult": 1.25, "debt_mult": 1.3, "hint_density": "off"}, "reload_at": 0},
	# endregion
}


static func path_of(name: String) -> String:
	return "res://tests/golden/%s.json" % name


static func part_hashes(sim: Simulation) -> Dictionary:
	var items: Array = []
	for c in sim.items.stacks:
		items.append([c, sim.items.stacks[c]])
	var cols: Array = []
	for col in sim.colonists.list:
		cols.append([col.id, col.cell, col.hp, col.alive, col.carry_item, col.carry_count])
	var blds: Array = []
	for b in sim.buildings.list:
		blds.append([b.id, b.def_id, b.cell, b.hp, b.condition, b.broken, b.input, b.output])
	var enemies: Array = []
	for e in sim.threats.enemies:
		enemies.append([e.id, e.cell, e.hp])
	var out := {
		"core": SaveGame.state_hash(sim),
		"rng": var_to_str(sim.rng.state).hash(),
		"items": var_to_str(items).hash(),
		"colonists": var_to_str(cols).hash(),
		"buildings": var_to_str(blds).hash(),
		"belts": var_to_str(sim.logistics.state_parts()).hash(),
		"ledger": var_to_str([sim.ledger.produced, sim.ledger.consumed]).hash(),
		"enemies": var_to_str(enemies).hash(),
	}
	for sys: String in ["contamination", "threats", "storyteller", "crises", "contracts", "debt", "mutation"]:
		out[sys] = var_to_str(QaBot._dump(sim.get(sys))).hash()
	var per_col: Array = []
	for col in sim.colonists.list:
		for o: Object in [col.mood, col.health, col.needs, col.perks]:  # direct fields: state_of() creates lazily
			per_col.append(QaBot._dump(o))
	out["colonist_state"] = var_to_str(per_col).hash()
	return out


static func decode_cmds(raw: Array) -> Array:
	var cmds: Array = []
	for e: Array in raw:
		var args: Array = []
		for a: Variant in e[2]:
			if a is Dictionary and a.has("a"):
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
	return cmds


static func _defs_for(spec: Dictionary) -> Defs:
	return TestCase.peaceful_defs() if spec["peaceful"] else null


## Runs one scenario for TOTAL ticks. Replay mode: `cmds` (decoded) are applied;
## generate mode: `script` (Callable(sim, tick)) issues the commands.
static func run(spec: Dictionary, cmds: Array, script: Callable) -> Dictionary:
	var bus: Node = TestCase.EventBusScript.new()
	var defs := _defs_for(spec)
	var sim := Simulation.new(int(spec["seed"]), bus, defs, SaveGame._opts_from({"opts": spec["opts"]}))
	sim.start_new_game()
	var hashes := {}
	var parts := {}
	var i := 0
	var reload_at := int(spec["reload_at"])
	var reload_bad := false
	while true:
		if reload_at > 0 and sim.tick == reload_at:
			var res := SaveGame.load_json(SaveGame.to_json(sim), bus, defs)
			if not res["ok"]:
				push_error("golden: reload failed: " + str(res["error"]))
				break
			var fresh: Simulation = res["sim"]
			if SaveGame.state_hash(fresh) != SaveGame.state_hash(sim):
				reload_bad = true
			sim.dispose()
			sim = fresh
			reload_at = -1
		if script.is_valid():
			script.call(sim, sim.tick)
		else:
			while i < cmds.size() and cmds[i][0] <= sim.tick:
				sim.callv(cmds[i][1], cmds[i][2])
				i += 1
		if sim.tick >= TOTAL or sim.game_over_reason != "":
			break
		sim.step()
		if sim.tick % STEP == 0:
			hashes[str(sim.tick)] = SaveGame.state_hash(sim)
			parts[str(sim.tick)] = part_hashes(sim)
	var log: Array = SaveGame.to_dict(sim)["commands"]
	var over := sim.game_over_reason
	sim.dispose()
	bus.free()
	return {"hashes": hashes, "parts": parts, "commands": log, "game_over": over, "reload_bad": reload_bad}


static func load_golden(name: String) -> Dictionary:
	var f := FileAccess.open(path_of(name), FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


## Returns "" when equal, else "golden <name>: first divergence at tick N (...)".
static func compare(name: String, expected: Dictionary, got: Dictionary) -> String:
	for t in range(STEP, TOTAL + 1, STEP):
		var k := str(t)
		if not got["hashes"].has(k):
			return "golden %s: run ended early before tick %d (game_over=%s)" % [name, t, got["game_over"]]
		var ep: Dictionary = expected["parts"][k]
		var gp: Dictionary = got["parts"][k]
		var diff: Array[String] = []
		for p: String in ep:
			if int(ep[p]) != int(gp.get(p, -1)):
				diff.append(p)
		if int(expected["hashes"][k]) != int(got["hashes"][k]) or not diff.is_empty():
			return "golden %s: first divergence at tick %d (expected %d got %d; differing parts: %s)" % [
				name, t, int(expected["hashes"][k]), int(got["hashes"][k]), ", ".join(diff) if not diff.is_empty() else "state_hash only"]
	if got["reload_bad"]:
		return "golden %s: save/load at tick %d changed state_hash" % [name, int(expected["reload_at"])]
	return ""


static func write_golden(name: String, spec: Dictionary, res: Dictionary) -> void:
	var lines: PackedStringArray = []
	lines.append("{")
	lines.append('"name": "%s",' % name)
	lines.append('"seed": %d,' % int(spec["seed"]))
	lines.append('"peaceful": %s,' % str(spec["peaceful"]).to_lower())
	lines.append('"opts": %s,' % JSON.stringify(spec["opts"]))
	lines.append('"ticks": %d,' % TOTAL)
	lines.append('"reload_at": %d,' % int(spec["reload_at"]))
	lines.append('"hashes": %s,' % JSON.stringify(res["hashes"], "", true))
	lines.append('"parts": {')
	var keys: Array = res["parts"].keys()
	for j in keys.size():
		lines.append("%s: %s%s" % [JSON.stringify(keys[j]), JSON.stringify(res["parts"][keys[j]], "", true), "," if j < keys.size() - 1 else ""])
	lines.append("},")
	lines.append('"commands": [')
	var cmds: Array = res["commands"]
	for j in cmds.size():
		lines.append("%s%s" % [JSON.stringify(cmds[j]), "," if j < cmds.size() - 1 else ""])
	lines.append("]")
	lines.append("}")
	var f := FileAccess.open(path_of(name), FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")


# --- Scenario scripts (generation only): commands go through Simulation methods ---

static func script_for(name: String) -> Callable:
	var base := "raid_turrets" if name.begins_with("preset_") else name  # region O3
	return func(sim: Simulation, tick: int) -> void: _script(base, sim, tick)


static func _script(name: String, sim: Simulation, tick: int) -> void:
	var center := sim.map_center()
	match name:
		"peaceful_mining":
			if tick == 0:
				Scen.designate_nearest_deposits(sim, 8)
				for k in 4:
					sim.set_zone(center + Vector2i(-6 + k % 2, 2 + k / 2), "stockpile")
			elif tick == 900:
				Scen.designate_nearest_deposits(sim, 14)
				sim.place_building("bed", Scen.find_spot(sim, "bed", center + Vector2i(-3, 6), 0))
			elif tick == 1800:
				sim.set_work_priority(sim.colonists.list[0].id, "mining", 1)
		"raid_turrets":
			if tick == 0:
				Scen.designate_nearest_deposits(sim, 10)
				sim.place_building("refinery", Scen.find_spot(sim, "refinery", center, 3))
				for k in 3:
					var ang := TAU * k / 3.0
					var want := center + Vector2i(roundi(cos(ang) * 4.0), roundi(sin(ang) * 4.0))
					sim.place_building("turret", Scen.find_spot(sim, "turret", want, 0))
			elif tick == 600:
				sim.set_rule("raid_engineer", true)
			elif sim.threats.wave_active and not sim.alarm:
				sim.set_alarm(true)
			elif not sim.threats.wave_active and sim.alarm:
				sim.set_alarm(false)
		"automation_chain":
			if tick == 0:
				Scen.designate_nearest_deposits(sim, 4)
				Scen.build_chain(sim, true)
			elif tick == 1200:
				sim.place_building("workbench", Scen.find_spot(sim, "workbench", center + Vector2i(-4, 4), 0))
		"contamination_crisis":
			if tick == 0:
				Scen.designate_nearest_deposits(sim, 10)
				sim.place_building("refinery", Scen.find_spot(sim, "refinery", center, 3))
				var dump := Scen.find_zone_spot(sim, center + Vector2i(-6, 0), Vector2i(3, 3))
				for y in 3:
					for x in 3:
						sim.set_zone(dump + Vector2i(x, y), "waste_dump")
			elif tick == 1500:
				sim.set_rule("refine_cap", true)
				sim.place_building("turret", Scen.find_spot(sim, "turret", center + Vector2i(4, 0), 0))
			for p in sim.crises.pending.duplicate():
				var id := str(p["id"]) if p is Dictionary else str(p)
				for o: String in sim.defs.crises["crises"].get(id, {}).get("options", {}):
					if sim.resolve_crisis(id, o):
						break
		"save_load_midgame":
			if tick == 0:
				Scen.designate_nearest_deposits(sim, 8)
				sim.set_zone(center + Vector2i(-6, 2), "stockpile")
				sim.place_building("turret", Scen.find_spot(sim, "turret", center + Vector2i(4, 0), 0))
			elif tick == 700:
				sim.set_rule("ore_reserve", true)
			elif tick == 1600:  # after the reload
				sim.place_building("bed", Scen.find_spot(sim, "bed", center + Vector2i(-3, 6), 0))
				sim.set_alarm(true)
			elif tick == 1700:
				sim.set_alarm(false)
