extends TestCase
## Keeps docs/sim_contract.md in sync with the code: every recorded command and every data/*.json is listed.

const DOC := "res://docs/sim_contract.md"


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


func _recorded_commands() -> Array[String]:
	var out: Array[String] = []
	var re := RegEx.new()
	re.compile("_record\\(\"([a-z_]+)\"")
	for m in re.search_all(_read("res://sim/core/simulation.gd")):
		var n := m.get_string(1)
		if n != "method_name" and not out.has(n):  # "method_name" appears in the contract comment
			out.append(n)
	return out


func _data_files() -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at("res://data"):
		if f.ends_with(".json"):
			out.append(f)
	return out


func test_doc_exists_and_short() -> void:
	var doc := _read(DOC)
	assert_true(doc != "", "docs/sim_contract.md missing")
	assert_true(doc.count("\n") <= 250, "sim_contract.md must stay <= 250 lines")


func test_every_recorded_command_is_listed() -> void:
	var doc := _read(DOC)
	var cmds := _recorded_commands()
	assert_true(cmds.size() >= 30, "expected many recorded commands, got %d" % cmds.size())
	for c in cmds:
		assert_true(doc.contains("| `%s` |" % c), "command not in sim_contract.md table: %s" % c)


func test_every_data_file_is_listed() -> void:
	var doc := _read(DOC)
	var files := _data_files()
	assert_true(files.size() >= 30, "expected many data files, got %d" % files.size())
	for f in files:
		assert_true(doc.contains("| `%s` |" % f), "data file not in sim_contract.md table: %s" % f)


func test_doc_lists_no_unknown_commands() -> void:
	var cmds := _recorded_commands()
	var re := RegEx.new()
	re.compile("(?m)^\\| `([a-z_]+)` \\| ")
	var doc := _read(DOC)
	var a := doc.find("## 4.")
	var in_cmds := doc.substr(a, doc.find("## 5.") - a)
	for m in re.search_all(in_cmds):
		assert_true(cmds.has(m.get_string(1)), "doc lists a command that is not recorded: %s" % m.get_string(1))
