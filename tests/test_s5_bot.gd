extends TestCase
## S5: ending text exists (English, ~40 words) and the shuttle bot's balance targets are data.


func test_shuttle_ending_text() -> void:
	var f: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/flavor.json"))
	var lines: Array = f["shuttle_ending"]["text"]
	var words := 0
	for l: String in lines:
		words += l.split(" ", false).size()
	assert_true(words >= 30 and words <= 50, "ending ~40 words, got %d" % words)
	assert_true(" ".join(lines).contains("Somebody else will be sent to dig."), "ending closing line")


func test_s5_targets_in_balance() -> void:
	var b: Dictionary = Defs.get_default().balance["s5_shuttle_bot"]
	assert_eq(int(b["target_days"]), 60)
	assert_true(float(b["min_siege_win_rate"]) >= 0.5, "siege win-rate target")
