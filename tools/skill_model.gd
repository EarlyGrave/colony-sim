extends SceneTree
## F3d skill table. godot --headless --path . -s tools/skill_model.gd [-- --days=40 --work=0.5 --bot=0]
## 1. Days for a full-time worker (work fraction of the day, default 0.5) to reach L3/L6/L10 per passion (analytic, from skills.json).
## 2. One row per branch effect with the system that reads it.
## 3. Factory bot, 3 seeds, branch_pick 0 vs 1: branches picked + ledger (unless --bot=0).
const FactoryBot := preload("res://tools/factory_bot.gd")

const CONSUMERS := {"hit_chance": "combat_system hit", "crit_chance": "combat_system crit", "burst_shots": "combat_system burst",
	"melee_damage": "combat_system melee dmg", "unarmed_damage": "combat_system unarmed dmg", "plant_speed": "sow/harvest job",
	"harvest_yield": "farming.harvest", "craft_quality": "quality.roll", "craft_input": "building_system craft",
	"ore_yield": "mine_job", "mining_speed": "mine_job"}


func _init() -> void:
	var days := 40
	var work := 0.5
	var run_bot := true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--days="):
			days = int(a.get_slice("=", 1))
		elif a.begins_with("--work="):
			work = float(a.get_slice("=", 1))
		elif a.begins_with("--bot="):
			run_bot = int(a.get_slice("=", 1)) == 1
	var defs := Defs.get_default()
	var sk: Dictionary = defs.skills
	var tpd := float(defs.balance["ticks_per_day"])
	print("== days to level (full-time, work fraction %.2f of %d ticks/day) ==" % [work, int(tpd)])
	for p: String in sk["passion_xp"]:
		var row := "passion %-5s" % p
		for target in [3, 5, 6, 10]:
			row += "  L%d=%5.1f d" % [target, days_to(sk, target, float(sk["passion_xp"][p]), tpd * work)]
		print(row)
	print("branch_level=%d (design doc said 6; milestone expert=%s)" % [int(sk["branch_level"]), str(sk["milestones"].get("6", "-"))])
	print("== branch effects ==")
	var bs: Dictionary = sk["branches"]
	for skill: String in bs:
		for b: String in bs[skill]:
			var fx: Dictionary = bs[skill][b]["effects"]
			for k: String in fx:
				print("%-9s %-10s %-15s %+.2f -> %s" % [skill, b, k, float(fx[k]), CONSUMERS.get(k, "MISSING")])
	if run_bot:
		print("== bot, %d days, seeds 1..3 ==" % days)
		for pick in [0, 1]:
			for sv in [1, 2, 3]:
				var d := Defs.get_default()
				d.balance["pg_bot"]["branch_pick"] = pick
				var r: Dictionary = FactoryBot.play(sv, days, {})
				var led: Dictionary = r["ledger"]
				print("branch_pick=%d seed %d picked=%2d alive=%d mined=%s refined(prod)=%s plate=%s" % [pick, sv, int(r.get("branches", 0)), int(r["alive"]),
					led.get("mining:essence_ore", 0), str(led.get("refined_essence", "0")).get_slice("/", 0), str(led.get("plate", "0")).get_slice("/", 0)])
	quit()


static func days_to(sk: Dictionary, target: int, passion_mult: float, work_ticks_per_day: float) -> float:
	var xp := 0.0
	for l in target:
		xp += float(sk["xp_table"][l])
	return xp / (float(sk["xp_per_work_tick"]) * passion_mult * work_ticks_per_day)
