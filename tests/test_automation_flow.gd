extends TestCase
## End-to-end automation: miner -> belt -> smelter -> belt -> storage_in.
## Belts go in through Simulation commands; machines use buildings.place(.., false)
## because blueprints would need hauled materials (and storage_in is not
## player-buildable yet).

const Scenario := preload("res://tests/scenario.gd")
const DAYS := 2


func _build_chain(sim: Simulation) -> Dictionary:
	return Scenario.build_chain(sim, false, true)


func _run(chains: int) -> Dictionary:
	var sim := make_sim(3, true, 64, 64, peaceful_defs())
	var built: Array = []
	for i in chains:
		var r := _build_chain(sim)
		assert_false(r.is_empty(), "chain %d fits" % i)
		built.append(r)
	sim.run_ticks(sim.ticks_per_day * DAYS)
	# Colonists haul finished goods out of storage_in, so count batches x recipe output.
	var per_batch := int(sim.defs.recipes["refine_essence"]["outputs"]["refined_essence"])
	var refined: int = sim.buildings.refined_batches * per_batch
	return {"refined_per_day": float(refined) / DAYS, "contam_per_day": sim.contamination.level / DAYS, "sim": sim, "built": built}


func test_miner_to_storage_produces_refined() -> void:
	var r := _run(1)
	var sim: Simulation = r["sim"]
	print("A2e flow: refined/day %.1f contamination/day %.2f" % [r["refined_per_day"], r["contam_per_day"]])
	assert_true(r["refined_per_day"] >= 10.0, "refined/day %.1f" % r["refined_per_day"])
	assert_true(sim.items.count_stored("waste") + int((r["built"][0]["store"] as Building).output.get("waste", 0)) > 0, "waste reaches storage too")
	assert_true(r["contam_per_day"] > 0.0)


func test_three_smelters_contaminate_much_more_than_one() -> void:
	var one := _run(1)
	var three := _run(3)
	print("A2e flow: contam/day 1=%.2f 3=%.2f" % [one["contam_per_day"], three["contam_per_day"]])
	assert_true(one["contam_per_day"] > 0.0)
	assert_true(three["contam_per_day"] >= 2.0 * one["contam_per_day"], "contam/day 1: %.2f vs 3: %.2f" % [one["contam_per_day"], three["contam_per_day"]])
	assert_true(three["refined_per_day"] >= 2.0 * one["refined_per_day"])


func test_forecast_counts_running_machines() -> void:
	var r := _run(3)
	var sim: Simulation = r["sim"]
	assert_true(sim.contamination.machine_rate_per_day() > 0.0)
	var cfg: Dictionary = sim.defs.balance["contamination"]
	var plain := ForecastModel.estimate(sim.contamination.level, 0.0, cfg)
	var with := ForecastModel.estimate(sim.contamination.level, 0.0, cfg, 5.0)
	assert_true(with["days"] < plain["days"])
