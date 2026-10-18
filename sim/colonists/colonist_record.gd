class_name ColonistRecord
extends RefCounted
## Display helpers for the per-colonist career counters (F3). The counters
## themselves are plain Dictionaries in `ColonistSystem.records` (flavor only, excluded from
## state_hash, rebuilt by replay). This script is view/test side ONLY: the sim must
## not load it, because a new script resource shifts instance ids that golden
## part dumps print for pending colonists.

const NICK_BANK := {"belts_repaired": "haul", "repairs": "haul", "ore_mined": "haul", "refined": "refine"}


static func total_kills(r: Dictionary) -> int:
	var n := 0
	for k: String in r["kills"]:
		n += int(r["kills"][k])
	return n


static func favourite_prey(r: Dictionary) -> String:
	var best := ""
	var best_n := 0
	var keys: Array = r["kills"].keys()
	keys.sort()
	for k: String in keys:
		if int(r["kills"][k]) > best_n:
			best_n = int(r["kills"][k])
			best = k
	return best


## Stable mix of colonist id + salt, independent of engine hash().
static func mix(id: int, salt: int) -> int:
	var x := (id * 2654435761 + salt * 40503 + 12345) & 0x7fffffff
	x = (((x >> 13) ^ x) * 1274126177) & 0x7fffffff
	return (x >> 7) ^ x


## Rap sheet lines seeded by colonist id (stable across reloads).
static func rap_sheet(id: int, names: Dictionary, bank: FlavorPicker = null) -> Dictionary:
	var rs: Dictionary = names.get("rapsheet", {})
	var out := {}
	var salt := 1
	for key: String in ["crime", "sentence", "complaint", "last_words"]:
		var arr: Array = rs.get(key, [])
		if bank != null and bank.has_key("rapsheet." + key):
			arr = Array(bank.lines_of("rapsheet." + key))
		out[key] = "" if arr.is_empty() else str(arr[mix(id, salt) % arr.size()])
		salt += 1
	return out


## Nickname text for a colonist, "" if not earned yet.
static func nickname(c: Colonist, r: Dictionary, names: Dictionary, bank: FlavorPicker = null) -> String:
	if r["nick_stat"] == "":
		return ""
	var arr: Array = names.get("nicknames", {}).get(r["nick_stat"], [])
	if bank != null:
		var k := "nicknames." + str(NICK_BANK.get(r["nick_stat"], r["nick_stat"]))
		if bank.has_key(k):
			arr = Array(bank.lines_of(k))
	return "" if arr.is_empty() else str(arr[mix(c.id, 9) % arr.size()])
