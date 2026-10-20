extends TestCase
## F8: every stat key / affix id has a human name; formatting.


func test_covers_all_keys_and_affixes() -> void:
	var defs: Defs = make_sim(3, false, 20, 20, peaceful_defs()).defs
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/stat_names.json"))
	for k in StatBlock.KEYS:
		assert_true(data.has(k), "stat_names has " + k)
	for a: String in defs.affixes["affixes"]:
		assert_true(data.has(a), "stat_names has affix " + a)
	for k: String in data:
		if not k.begins_with("_"):
			assert_false(StatNames.label(k).contains("_"), "no raw id in name of " + k)


func test_fmt_and_fallback() -> void:
	assert_eq(StatNames.fmt("dmg_pct", 0.12), "+12% Damage")
	assert_eq(StatNames.fmt("armor_phys", 40.0), "+40 Armour")
	assert_eq(StatNames.fmt("accuracy", -0.05), "-5% Accuracy")
	assert_eq(StatNames.label("some_new_stat"), "Some New Stat")
