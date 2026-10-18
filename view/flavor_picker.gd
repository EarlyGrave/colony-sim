class_name FlavorPicker
extends RefCounted
## View-side flavor text picker (F1). Cosmetic only: never touches sim.rng,
## never read by the sim, never in state_hash. Own seeded RNG per pick from
## hash([tick, key, id]); a no-repeat ring (last N lines per key) is picker
## state and is not saved.

const PATH := "res://data/flavor.json"
const RING := 4
const PLACEHOLDERS: PackedStringArray = ["who", "victim", "enemy", "n", "cause"]

# Key constants (dotted paths into data/flavor.json). Other view code uses these.
const K_FEED_GENERIC := "feed.generic"
const K_FEED_COLONIST_DOWNED := "feed.colonist.downed"
const K_FEED_COLONIST_GENERIC := "feed.colonist.generic"
const K_FEED_BUILDING_DESTROYED := "feed.building.destroyed"
const K_PA_WAVE_INCOMING := "pa.wave_incoming"
const K_PA_WAVE_STARTED := "pa.wave_started"
const K_PA_WAVE_REPELLED := "pa.wave_repelled"
const K_PA_CRISIS_STARTED := "pa.crisis_started"
const K_PA_RESEARCH_COMPLETED := "pa.research_completed"
const K_PA_COLONIST_DOWNED := "pa.colonist_downed"
const K_PA_COLONIST_DIED := "pa.colonist_died"
const K_PA_OUTPOST_LOST := "pa.outpost_lost"
const K_PA_QUIET_DAY := "pa.quiet_day"
const K_BARK_WORKING := "barks.working"
const K_BARK_FLEEING := "barks.fleeing"
const K_BARK_IDLE := "barks.idle"
const K_BARK_HUNGRY := "barks.hungry"
const K_BARK_LOW_MOOD := "barks.low_mood"
const K_BARK_REFINING := "barks.refining"
const K_BARK_WAVE_WON := "barks.wave_won"
const K_NICK_KILLS := "nicknames.kills"
const K_NICK_DOWNS := "nicknames.downs"
const K_NICK_HAUL := "nicknames.haul"
const K_NICK_REFINE := "nicknames.refine"
const K_RAP_CRIME := "rapsheet.crime"
const K_RAP_SENTENCE := "rapsheet.sentence"
const K_RAP_COMPLAINT := "rapsheet.complaint"
const K_RAP_LAST_WORDS := "rapsheet.last_words"
const K_EPITAPH_GENERIC := "epitaph.generic"
const K_EPITAPH_BLEED_OUT := "epitaph.bleed_out"
const K_EPITAPH_STARVATION := "epitaph.starvation"
const K_EPITAPH_KILLED := "epitaph.killed"
const K_TIPS := "tips"
const K_GAMEOVER_POD_LOST := "gameover.pod_lost"
const K_GAMEOVER_ALL_DEAD := "gameover.all_dead"
const K_SPLAT_AUDITED := "splat.audited"
const K_SPLAT_OOF := "splat.oof"

var _lines: Dictionary = {}  # key -> PackedStringArray
var _ring: Dictionary = {}  # key -> Array[int] of recent line indices


## Load the bank (default data/flavor.json). Never null; empty bank on error.
static func load_bank(path: String = PATH) -> FlavorPicker:
	var p := FlavorPicker.new()
	if not FileAccess.file_exists(path):
		return p
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		p._flatten(parsed, "")
	return p


## Plan alias: FlavorPicker.load_default() == load_bank().
static func load_default() -> FlavorPicker:
	return load_bank()


func _flatten(node: Dictionary, prefix: String) -> void:
	var names: Array = node.keys()
	names.sort()
	for k in names:
		var name: String = str(k)
		if name.begins_with("_"):
			continue
		var v: Variant = node[k]
		var full: String = name if prefix == "" else prefix + "." + name
		if v is Dictionary:
			_flatten(v, full)
		elif v is Array:
			var arr := PackedStringArray()
			for s in v:
				arr.append(str(s))
			_lines[full] = arr


func has_key(key: String) -> bool:
	return _lines.has(key) and (_lines[key] as PackedStringArray).size() > 0


func all_keys() -> Array[String]:
	var out: Array[String] = []
	for k in _lines.keys():
		out.append(str(k))
	out.sort()
	return out


## Raw (unresolved) lines of a key, for data checks.
func lines_of(key: String) -> PackedStringArray:
	return _lines.get(key, PackedStringArray())


## Pick a line. ctx may hold: tick (int), id (any), and placeholder values
## who/victim/enemy/n/cause. Unknown key -> "". Missing placeholder -> "".
func pick(key: String, ctx: Dictionary = {}) -> String:
	if not has_key(key):
		return ""
	var lines: PackedStringArray = _lines[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(ctx.get("tick", 0)), key, str(ctx.get("id", ""))])
	var ring: Array = _ring.get(key, [])
	var keep: int = mini(RING, lines.size() - 1)
	while ring.size() > keep:
		ring.pop_front()
	var idx := rng.randi_range(0, lines.size() - 1)
	if lines.size() > 1:
		var guard := 0
		while ring.has(idx) and guard < lines.size():
			idx = (idx + 1) % lines.size()
			guard += 1
	if keep > 0:
		ring.append(idx)
		while ring.size() > keep:
			ring.pop_front()
	_ring[key] = ring
	return resolve(lines[idx], ctx)


## Pick the first existing key from a fallback chain.
func pick_first(keys: Array, ctx: Dictionary = {}) -> String:
	for k in keys:
		if has_key(str(k)):
			return pick(str(k), ctx)
	return ""


func reset_ring() -> void:
	_ring.clear()


static func resolve(line: String, ctx: Dictionary) -> String:
	if line.find("{") < 0:
		return line
	var out := line
	for ph in PLACEHOLDERS:
		out = out.replace("{" + ph + "}", str(ctx.get(ph, "")))
	return out


## Placeholder names used in a raw line that are not supported (data check).
static func unknown_placeholders(line: String) -> PackedStringArray:
	var bad := PackedStringArray()
	var re := RegEx.new()
	re.compile("\\{([^}]*)\\}")
	for m in re.search_all(line):
		var n: String = m.get_string(1)
		if not PLACEHOLDERS.has(n):
			bad.append(n)
	return bad
