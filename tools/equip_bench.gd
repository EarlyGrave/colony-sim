extends SceneTree
## E4 equipment perf bench: 250 map, 220 inmates x 6 legendary items (4 affixes + 2 upgrades), 300 enemies in contact.
## godot --headless --path . -s tools/equip_bench.gd -- [--seed=1] [--runs=3]
## Prints the "combat" profiling bucket (CombatSystem.try_attack: cooldown/ammo gates, hit roll, resolve_hit, damage), total ms/tick,
## equipment resum count over the measured run and the state_hash. Shared with tests/test_equip_perf.gd.

const Scenario := preload("res://tools/perf_scenario.gd")
const UNITS := 220
const ENEMIES := 300
const WARMUP := 100
const TICKS := 300
## [base, upgrade]; slots: weapon, torso_outer, head, hands, legs, torso_inner.
const LOADOUT: Array = [["plasma_blade", "ap_rounds"], ["kevlar_vest", "kevlar_plate"], ["helmet", ""], ["work_gloves", ""], ["greaves", ""], ["underlay", ""]]


static func _enemy(sim: Simulation, cell: Vector2i) -> void:
	var e := sim.threats._spawn("crawler", cell)
	e.damage_mult = 0.0
	e.hp = 1.0e9
	e.max_hp = 1.0e9


## Builds the scene and returns the sim (gear equipped, enemies in contact, warm-up done).
static func build(seed_value: int, bus: Node, units := UNITS, enemies := ENEMIES, warmup := WARMUP) -> Simulation:
	var defs := Defs.get_default().duplicate_defs()
	defs.balance["threat"]["enabled"] = false  # only the 300 contact enemies; no storyteller waves
	defs.event_chains["random_enabled"] = false
	defs.enemies["crawler"]["attack_cooldown_ticks"] = 1 << 28  # one 1-damage bite each (resolve_hit floors at 1), then harmless
	var sim := Simulation.new(seed_value, bus, defs, {"map_w": 250, "map_h": 250})
	sim.start_new_game()
	var center := sim.map_center()
	var taken := {}
	var n := 0
	var ring := 3
	while n < units and ring < 80:
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if n >= units:
					break
				if maxi(absi(dx), absi(dy)) != ring or (dx + dy) % 4 != 0:
					continue
				var c := center + Vector2i(dx, dy)
				var side := c + Vector2i(1, 0)
				if taken.has(c) or taken.has(side) or not sim.map.is_passable(c) or not sim.map.is_passable(side) \
						or sim.buildings.occupied(c) or sim.buildings.occupied(side) or not sim.pathfinder.reachable_terrain(c, center):
					continue
				taken[c] = true
				taken[side] = true
				var col := sim.colonists.spawn(c)
				col.combat.next_attack_tick = n % 9  # stagger cooldowns like a real fight
				col.max_hp = 1.0e6  # resolve_hit floors damage at 1, so "harmless" enemies would still wear inmates down
				col.hp = 1.0e6
				for slot in LOADOUT:
					var gid := sim.give_gear(col.id, slot[0], "legendary", 12)
					if slot[1] != "":
						sim.defs.upgrades[slot[1]]["cost"] = {}  # F9W1: bench sockets for free
						sim.socket(gid, slot[1])
					sim.equip(col.id, gid)
				if sim.threats.enemies.size() < enemies:
					_enemy(sim, side)
				n += 1
		ring += 1
	# remaining enemies: other free neighbours of inmates
	var dirs: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var k := 0
	var cols := sim.colonists.list
	while sim.threats.enemies.size() < enemies and k < cols.size() * 3:
		var cell: Vector2i = cols[k % cols.size()].cell + dirs[k / cols.size()]
		if not taken.has(cell) and sim.map.is_passable(cell) and not sim.buildings.occupied(cell):
			taken[cell] = true
			_enemy(sim, cell)
		k += 1
	sim.threats.wave_active = true
	sim.threats.wave_end_tick = 1 << 30
	for t in warmup:
		sim.step()
	return sim


## One measured run.
static func run_once(seed_value: int, bus: Node, ticks := TICKS) -> Dictionary:
	var sim := build(seed_value, bus)
	var r0 := sim.equipment.resum_count
	var c0 := sim.combat.resum_count
	var m := Scenario.measure(sim, ticks)
	var combat: Array = m.get("combat", [0.0])
	return {
		"combat_avg": Scenario.avg(combat), "combat_p95": Scenario.p95(combat),
		"total_avg": Scenario.avg(m["total"]), "total_p95": Scenario.p95(m["total"]),
		"resums": sim.equipment.resum_count - r0, "combat_resums": sim.combat.resum_count - c0,
		"hash": SaveGame.state_hash(sim), "units": sim.colonists.list.size(), "enemies": sim.threats.enemies.size(),
		"alive": sim.colonists.alive_count(), "tick": sim.tick,
	}


func _init() -> void:
	var seed_value := 1
	var runs := 3
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_value = int(a.get_slice("=", 1))
		elif a.begins_with("--runs="):
			runs = int(a.get_slice("=", 1))
	for k in runs:
		var bus: Node = load("res://autoload/event_bus.gd").new()
		var r := run_once(seed_value, bus)
		print("run %d: units=%d alive=%d enemies=%d combat avg=%.3f p95=%.3f ms | total avg=%.2f p95=%.2f ms | equip_resums=%d combat_resums=%d hash=%d" % [
			k, r["units"], r["alive"], r["enemies"], r["combat_avg"], r["combat_p95"], r["total_avg"], r["total_p95"], r["resums"], r["combat_resums"], r["hash"]])
	quit()
