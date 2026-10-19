extends TestCase
## D4 smoke: the per-seed JSON line printer works on a short bot run.
const Report := preload("res://tools/factory_bot_report.gd")
const FactoryBot := preload("res://tools/factory_bot.gd")


func test_json_line() -> void:
	var r: Dictionary = FactoryBot.play(1, 1)
	var line: String = Report.json_line(r)
	assert_true(line.begins_with("EVALJSON "), "prefix")
	var d: Variant = JSON.parse_string(line.substr(9))
	assert_true(d is Dictionary and d.has("refined") and d.has("waste"), "keys")
