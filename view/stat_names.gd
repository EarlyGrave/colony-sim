class_name StatNames
extends RefCounted
## F8: human-readable stat names/values for gear UI. Data in data/stat_names.json (no raw ids in text).

const PATH := "res://data/stat_names.json"
static var _cache: Dictionary = {}


static func _data() -> Dictionary:
	if _cache.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_cache = parsed
		if _cache.is_empty():
			_cache = {"_": true}
	return _cache


static func label(key: String) -> String:
	var d: Variant = _data().get(key)
	if d is Dictionary and (d as Dictionary).has("name"):
		return str((d as Dictionary)["name"])
	return key.replace("_", " ").capitalize()


static func is_pct(key: String) -> bool:
	var d: Variant = _data().get(key)
	return d is Dictionary and bool((d as Dictionary).get("pct", false))


## "+12% Damage", "+40 Armour", "-5% Accuracy".
static func fmt(key: String, value: float) -> String:
	var sign_s := "+" if value >= 0.0 else "-"
	var a := absf(value)
	if is_pct(key):
		return "%s%d%% %s" % [sign_s, roundi(a * 100.0), label(key)]
	var num := str(roundi(a)) if is_equal_approx(a, roundf(a)) else str(snappedf(a, 0.1))
	return "%s%s %s" % [sign_s, num, label(key)]
