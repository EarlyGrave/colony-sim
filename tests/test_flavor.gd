extends TestCase

const FULL_CTX := {"who": "Wilhelmina X", "victim": "Wilhelmina X", "enemy": "Burrower", "n": "99", "cause": "starvation"}


func _ctx(tick: int, id: int) -> Dictionary:
	var c := FULL_CTX.duplicate()
	c["tick"] = tick
	c["id"] = id
	return c


func test_bank_loads_with_all_top_keys() -> void:
	var p := FlavorPicker.load_bank()
	for top in ["feed", "pa", "barks", "nicknames", "rapsheet", "epitaph", "tips", "splat"]:
		var found := false
		for k in p.all_keys():
			if k == top or k.begins_with(top + "."):
				found = true
		assert_true(found, "top key missing: " + top)


func test_every_line_fits_and_resolves() -> void:
	var p := FlavorPicker.load_bank()
	var total := 0
	for k in p.all_keys():
		for raw in p.lines_of(k):
			total += 1
			assert_eq(FlavorPicker.unknown_placeholders(raw).size(), 0, "unknown placeholder: %s" % raw)
			var s := FlavorPicker.resolve(raw, FULL_CTX)
			assert_true(s.find("{") < 0 and s.find("}") < 0, "unresolved: " + raw)
			assert_true(s.length() <= 70, "too long (%d): %s" % [s.length(), s])
			assert_true(s.length() > 0, "empty line in " + k)
	assert_true(total > 300, "bank too small: %d" % total)


func test_missing_placeholder_resolves_to_empty() -> void:
	assert_eq(FlavorPicker.resolve("{who} left", {}), " left")
	assert_eq(FlavorPicker.resolve("x {n} y", {"n": 3}), "x 3 y")


func test_same_seed_same_sequence() -> void:
	var seqs: Array = []
	for r in 2:
		var p := FlavorPicker.load_bank()
		var seq: Array = []
		for i in 200:
			var key: String = ["pa.wave_started", "feed.generic", "barks.working"][i % 3]
			seq.append(p.pick(key, _ctx(i * 7, i % 5)))
		seqs.append(seq)
	assert_eq(seqs[0], seqs[1])


func test_no_repeat_within_window() -> void:
	var p := FlavorPicker.load_bank()
	var checked := 0
	for k in p.all_keys():
		var n := p.lines_of(k).size()
		if n < 5:
			continue
		var win: Array = []
		for i in 1000:
			var s := p.pick(k, _ctx(i, 1))
			var raw_dupes := 0
			for w in win:
				if w == s:
					raw_dupes += 1
			assert_eq(raw_dupes, 0, "repeat in window for " + k)
			win.append(s)
			if win.size() > 4:
				win.pop_front()
		checked += 1
	assert_true(checked > 10)


func test_single_pick_repeated_same_context_still_no_repeat() -> void:
	var p := FlavorPicker.load_bank()
	var prev := ""
	for i in 50:
		var s := p.pick("pa.quiet_day", _ctx(5, 2))
		assert_true(s != prev, "immediate repeat")
		prev = s


func test_unknown_key_is_empty() -> void:
	var p := FlavorPicker.load_bank()
	assert_false(p.has_key("nope.nothing"))
	assert_eq(p.pick("nope.nothing", {}), "")


func test_referenced_key_constants_exist() -> void:
	var p := FlavorPicker.load_bank()
	var script: Script = load("res://view/flavor_picker.gd")
	var consts: Dictionary = script.get_script_constant_map()
	var n := 0
	for name in consts.keys():
		if str(name).begins_with("K_"):
			n += 1
			assert_true(p.has_key(str(consts[name])), "K const without bank key: %s" % name)
	assert_true(n > 20)
	# every FlavorPicker.K_* used in view/ must be a real constant
	var re := RegEx.new()
	re.compile("FlavorPicker\\.(K_[A-Z0-9_]+)")
	var dirs: Array[String] = ["res://view"]
	while not dirs.is_empty():
		var d: String = dirs.pop_back()
		for sub in DirAccess.get_directories_at(d):
			dirs.append(d + "/" + sub)
		for f in DirAccess.get_files_at(d):
			if not f.ends_with(".gd"):
				continue
			for m in re.search_all(FileAccess.get_file_as_string(d + "/" + f)):
				assert_true(consts.has(m.get_string(1)), "%s/%s uses unknown %s" % [d, f, m.get_string(1)])
