extends TestCase
## L5: Logistics 2 / power data (fuels, buildings, techs, resources, biomes) and the power-model balance gates.

const PowerModel := preload("res://tools/power_model.gd")


func test_defs_validate_clean() -> void:
	var errs := Defs.get_default().validate()
	assert_true(errs.is_empty(), "defs errors: " + str(errs))


func test_validate_catches_power_errors() -> void:
	var d := Defs.get_default().duplicate_defs()
	d.buildings["power_pole"]["power_range"] = 2
	d.buildings["coal_generator"]["power_gen"] = 0
	d.buildings["smelter"]["power_use"] = -1
	d.research["splitting"]["unlocks"]["belt_nodes"] = ["bogus"]
	assert_true(d.validate().size() >= 4, "validate should flag 4 power errors: " + str(d.validate()))


func test_consumer_power_use() -> void:
	var b: Dictionary = Defs.get_default().buildings
	assert_eq(int(b["miner"]["power_use"]), 20)
	assert_eq(int(b["smelter"]["power_use"]), 40)
	assert_eq(int(b["assembler"]["power_use"]), 50)
	assert_eq(int(b["research_bench"]["power_use"]), 20)
	assert_true(int(b["power_pole"]["power_range"]) >= 3)


func test_fuels_match_generators() -> void:
	var d := Defs.get_default()
	var tps := float(Simulation.TICKS_PER_SECOND)
	for fid: String in d.fuels["fuels"]:
		var fd: Dictionary = d.fuels["fuels"][fid]
		var g: Dictionary = d.buildings[fd["generator"]]
		assert_eq(str(g["fuel"]["item"]), fid)
		assert_eq(float(g["power_gen"]) * float(g["fuel"]["burn_ticks"]) / tps, float(fd["energy_per_unit"]), fid + " energy")
		assert_eq(float(g["fuel"]["waste_per_burn"]), float(fd["waste_per_unit"]), fid + " waste")
		assert_eq(float(g["threat"]), float(fd["threat"]), fid + " threat")
		assert_false(str(g["fuel"]["item"]) == "essence_ore", "essence is never fuel")
	assert_true(d.buildings["solar_array"]["fuel"] == null)


func test_fuel_tiers_get_cleaner_and_stronger() -> void:
	var f: Dictionary = Defs.get_default().fuels["fuels"]
	var wpe := func(id: String) -> float: return float(f[id]["waste_per_unit"]) / float(f[id]["energy_per_unit"])
	assert_gt(float(wpe.call("coal")), float(wpe.call("nitrogen")))
	assert_gt(float(wpe.call("nitrogen")), float(wpe.call("uranium")))
	assert_gt(float(f["nitrogen"]["energy_per_unit"]), float(f["coal"]["energy_per_unit"]))
	assert_gt(float(f["uranium"]["energy_per_unit"]), float(f["nitrogen"]["energy_per_unit"]))


func test_uranium_spent_fuel_needs_waste_dump() -> void:
	var d := Defs.get_default()
	assert_true(d.fuels["fuels"]["uranium"].has("meltdown"))
	assert_true(bool(d.items["spent_fuel"].get("contaminates", false)))
	assert_true(d.zone_accepts("waste_dump", "spent_fuel"))
	assert_false(d.zone_accepts("stockpile", "spent_fuel"))
	assert_true(d.zone_accepts("stockpile", "coal"))


func test_resources_and_biomes() -> void:
	# legacy and R4a bytes never shift; fuel resources come after them
	assert_eq(NodeData.res_index("copper_ore"), 1)
	assert_eq(NodeData.res_index("essence_ore"), 2)
	assert_eq(NodeData.res_index("iron_ore"), 3)
	assert_eq(NodeData.res_index("bog_resin"), 4)
	assert_eq(NodeData.res_index("cinder_ore"), 5)
	assert_eq(NodeData.res_index("prism_ore"), 6)
	assert_eq(NodeData.res_index("coal"), 7)
	assert_eq(NodeData.res_index("nitrogen"), 8)
	assert_eq(NodeData.res_index("uranium"), 9)
	assert_true(NodeData.biome("vents")["resources"].has("nitrogen"))
	assert_true(NodeData.biome("irradiated")["resources"].has("uranium"))
	assert_false(NodeData.biome("start")["resources"].has("coal"))  # start weights untouched
	assert_true(NodeData.biome("start")["extra_resources"].has("coal"))


func test_techs_unlock_new_content() -> void:
	var r: Dictionary = Defs.get_default().research
	for t in ["splitting", "smart_logic", "electrification", "clean_power", "nuclear"]:
		assert_true(r.has(t), t)
	assert_true("coal_generator" in r["electrification"]["unlocks"]["buildings"])
	assert_true("nitrogen_turbine" in r["clean_power"]["unlocks"]["buildings"])
	assert_true("nuclear_reactor" in r["nuclear"]["unlocks"]["buildings"])
	assert_true("splitter_basic" in r["splitting"]["unlocks"]["belt_nodes"])
	assert_true("splitter_smart" in r["smart_logic"]["unlocks"]["belt_nodes"])
	# not free at start (tier > free_tiers), so old research hashes stay identical
	assert_gt(int(r["electrification"]["tier"]), int(Defs.get_default().balance["research"]["free_tiers"]))
	assert_gt(int(r["splitting"]["tier"]), int(Defs.get_default().balance["research"]["free_tiers"]))


func test_power_model_gates() -> void:
	var d := Defs.get_default()
	var g := PowerModel.line(d, 3, {"coal_generator": 1})
	assert_true(float(g["ratio"]) >= 1.6 and float(g["ratio"]) <= 2.0, "ratio %f" % float(g["ratio"]))
	assert_true(float(g["waste_powered"]) >= 1.3 * float(g["waste_unpowered"]), "waste ratio")
	for mix: Dictionary in [{"coal_generator": 2}, {"nitrogen_turbine": 1}, {"nuclear_reactor": 1}]:
		var r := PowerModel.line(d, 3, mix)
		assert_true(float(r["ratio"]) <= 2.0001 and float(r["waste_powered"]) >= 1.3 * float(r["waste_unpowered"]))
	assert_true(4.0 * PowerModel.essence_cost(d, "solar_array") >= 2.0 * PowerModel.essence_cost(d, "coal_generator"))
	var s := PowerModel.line(d, 1, {"solar_array": 1})
	assert_eq(float(s["gen_waste"]), 0.0)


func _gen(seed_value: int, share: float) -> MapGrid:
	var cfg: Dictionary = Defs.get_default().balance["map"].duplicate(true)
	cfg["extra_share"] = share
	cfg["deposit_rings"] = false  # PG: ring carving follows the converted resources, this test is about the conversion only
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var map := MapGrid.new(int(cfg["width"]), int(cfg["height"]), make_bus())
	MapGenerator.generate(map, rng, cfg)
	return map


func test_coal_conversion_keeps_tiles_and_is_deterministic() -> void:
	var coal := NodeData.res_index("coal")
	var any_coal := false
	for s in range(1, 6):
		var off := _gen(s, 0.0)
		var on := _gen(s, 0.6)
		assert_eq(on.tiles, off.tiles, "tiles identical seed %d" % s)
		assert_eq(on.deposit_amount, off.deposit_amount)
		assert_eq(on.node_purity, off.node_purity)
		assert_eq(_gen(s, 0.6).node_res, on.node_res, "deterministic")
		assert_eq(off.node_res.find(coal), -1, "share 0 = no coal")
		any_coal = any_coal or on.node_res.find(coal) >= 0
	assert_true(any_coal, "coal appears on the start biome when enabled")
