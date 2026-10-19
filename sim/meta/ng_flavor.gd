class_name NgFlavor
extends RefCounted
## Next Sentence flavor: Warden letters for sentence >= 2 from data/flavor.json "sentence" (English, data-driven).


static func key_for(n: int) -> String:
	return str(n) if n < 4 else "4+"


## Letters [{title, text}] to post at the start of sentence n (empty for n < 2).
static func letters(n: int, veteran: Dictionary = {}) -> Array:
	var out: Array = []
	if n < 2:
		return out
	var j: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/flavor.json"))
	var cfg: Dictionary = (j as Dictionary)["sentence"]
	var quota := 10 * (n - 1)
	var lt: Dictionary = cfg["letters"][key_for(n)]
	out.append({"title": str(lt["title"]), "text": _fill(str(lt["text"]), n, quota, "")})
	if not veteran.is_empty():
		var v: Dictionary = cfg["veteran"]
		out.append({"title": str(v["title"]), "text": _fill(str(v["text"]), n, quota, str(veteran["name"]))})
	return out


static func _fill(t: String, n: int, quota: int, vet: String) -> String:
	return t.replace("{n}", str(n)).replace("{quota}", str(quota)).replace("{vet}", vet)
