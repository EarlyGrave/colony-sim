extends TestCase
## Automation data: items, recipes, machines, ports.


func test_defs_validate_clean() -> void:
	var errs := Defs.get_default().validate()
	assert_true(errs.is_empty(), "defs errors: " + str(errs))


func test_refining_recipes_have_waste() -> void:
	var d := Defs.get_default()
	var n := 0
	for rid: String in d.recipes:
		var st: Array = d.recipes[rid].get("station", [])
		if "smelter" in st or "refinery" in st:
			n += 1
			assert_true(int(d.recipes[rid]["outputs"].get("waste", 0)) > 0, rid + " has no waste")
	assert_true(n >= 3, "expected refining recipes")


func test_machines_have_ports() -> void:
	var d := Defs.get_default()
	for bid: String in ["miner", "smelter", "assembler"]:
		var ports: Array = d.buildings[bid]["ports"]
		var outs := 0
		var ins := 0
		for p: Dictionary in ports:
			if p["kind"] == "out":
				outs += 1
			else:
				ins += 1
		assert_true(outs >= 1, bid + " needs out port")
		if bid != "miner":
			assert_true(ins >= 1, bid + " needs in port")


func test_validate_catches_errors() -> void:
	var d := Defs.get_default().duplicate_defs()
	d.recipes["smelt_iron"]["outputs"].erase("waste")
	d.buildings["smelter"]["ports"] = [{"dx": 2, "dy": 0, "dir": "E", "kind": "out"}]
	d.recipes["make_plate"]["station"] = ["nope"]
	assert_true(d.validate().size() >= 3, "validate should flag 3 errors")
