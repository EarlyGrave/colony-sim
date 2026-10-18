class_name CampaignView
extends RefCounted
## Thin read adapter over the Campaign API (sim/campaign/campaign.gd, built in
## parallel). Every access is guarded so the UI also works with a stub or with
## no campaign at all.

const CFG_PATH := "res://data/expedition.json"


static func campaign_script() -> GDScript:
	if ResourceLoader.exists("res://sim/campaign/campaign.gd"):
		return load("res://sim/campaign/campaign.gd") as GDScript
	return null


static func maps(c: Object) -> Array:
	if c == null:
		return []
	var m: Variant = c.get("maps")
	return m if m is Array else []


static func active_id(c: Object) -> int:
	if c == null:
		return 0
	var a: Variant = c.get("active")
	return int(a) if a != null else 0


static func info(c: Object, id: int) -> Dictionary:
	if c != null and c.has_method("map_info"):
		var d: Variant = c.call("map_info", id)
		if d is Dictionary:
			return d
	for m: Dictionary in maps(c):
		if int(m.get("id", -1)) == id:
			return m
	return {}


static func in_flight(c: Object) -> Array:
	if c == null:
		return []
	var f: Variant = c.get("in_flight")
	return f if f is Array else []


## Crates in flight heading to (or leaving) map `id`.
static func flight_count(c: Object, id: int) -> int:
	var n := 0
	for cr: Variant in in_flight(c):
		if cr is Dictionary and (int(cr.get("to", -1)) == id or int(cr.get("from", -1)) == id):
			n += 1
	return n


static func is_alarm(c: Object, id: int) -> bool:
	var i := info(c, id)
	return bool(i.get("alarm", false)) or bool(i.get("lost", false))


static func label(c: Object, id: int) -> String:
	var i := info(c, id)
	if str(i.get("kind", "")) == "home" or id == 0:
		return "Home"
	return "%s %d" % [str(i.get("biome", "Outpost")).capitalize(), id]


static func config() -> Dictionary:
	if not FileAccess.file_exists(CFG_PATH):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(CFG_PATH))
	return v if v is Dictionary else {}


static func ticks_text(ticks: int, ticks_per_day: int) -> String:
	if ticks_per_day <= 0:
		return "%d ticks" % ticks
	return "%.1f days" % (float(ticks) / float(ticks_per_day))
