extends TestCase
## Q6 Auditor Visits: data shape + effect semantics. Uses a local stub interpreter
## (QuestLog from Q0 may not exist yet); assumed verbs are listed in the Q6 report.

const Q := "q6_auditor"


func _def() -> Dictionary:
	var f := FileAccess.open("res://data/quests_q6.json", FileAccess.READ)
	return JSON.parse_string(f.get_as_text())[Q]


func _opts() -> Dictionary:
	return _def()["beats"]["inspect"]["options"]


## Minimal stand-in for QuestLog: returns the effect list if affordable, else [].
func _pick(opt_id: String, plates: int, fired: Dictionary) -> Array:
	var o: Dictionary = _opts()[opt_id]
	var need: int = int(o.get("requires", {}).get("items", {}).get("plate", 0))
	if plates < need:
		return []
	fired[Q] = int(fired.get(Q, 0)) + 1
	return o["effects"]


func test_trigger_and_lines() -> void:
	var d := _def()
	assert_eq(int(d["trigger"]["tier_done"]), 2)
	assert_true(String(d["beats"]["inspect"]["text"]).contains("clean room"))
	assert_true(String(_opts()["show"]["text"]).contains("crop yield exceeds"))


func test_item_exists() -> void:
	assert_true(Defs.get_default().items.has("plate"))


func test_hide() -> void:
	var fx := _pick("hide", 30, {})
	assert_eq(int(fx[0]["count"]), -30)
	assert_eq(float(fx[1]["value"]), 1.2)
	assert_eq(int(fx[1]["days"]), 5)
	assert_eq(_pick("hide", 29, {}).size(), 0, "insufficient plates -> disabled")


func test_show() -> void:
	var fx := _pick("show", 0, {})
	assert_eq(float(fx[0]["value"]), 10.0)
	assert_eq(fx[1]["id"], "clue_manifest")


func test_tour() -> void:
	var fx := _pick("tour", 0, {})
	assert_eq(float(fx[0]["value"]), 0.95)
	assert_eq(float(fx[1]["value"]), 0.03)


func test_fires_once_and_deterministic() -> void:
	var fired := {}
	_pick("show", 0, fired)
	assert_eq(int(fired[Q]), 1)
	assert_eq(JSON.stringify(_pick("tour", 0, {})), JSON.stringify(_pick("tour", 0, {})))
