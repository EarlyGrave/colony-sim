class_name FeedDirector
extends RefCounted
## F2: turns bus facts into kill-feed lines and Warden PA announcements. View-side and cosmetic:
## never touches sim.rng or sim state. Text comes from F1's FlavorPicker when it exists
## (keys feed.<enemy>.<cause> -> feed.<enemy>.generic -> feed.generic, pa.<signal>), otherwise from
## the small local bank below. One signal -> exactly one line on exactly one surface:
##   feed: enemy_killed, colonist_downed, building_destroyed
##   PA:   wave_started, wave_incoming, crisis_started, research_completed, colonist_died,
##         map_switched, outpost_lost, every 5th day_started

const DAY_ASIDE_EVERY := 5
const MAX_LEN := 70
const PICKER_PATH := "res://view/flavor_picker.gd"

const FALLBACK := {
	"feed.crawler.turret": ["Crawler #{n} filed for retirement. Turret approved it."],
	"feed.brute.turret": ["Brute removed from the wave. Paperwork pending."],
	"feed.spitter.turret": ["Spitter returned to sender, with interest."],
	"feed.burrower.turret": ["Burrower went down. So did the property value."],
	"feed.generic": ["{enemy} #{n} has left the premises.", "{enemy} #{n} is no longer a scheduling issue."],
	"feed.downed": ["{who} is down. Please do not step on the paperwork."],
	"feed.building": ["A structure was reclassified as rubble."],
	"pa.wave_started": ["Unscheduled visitors. Please remain productive."],
	"pa.wave_incoming": ["Visitors expected. Please look busy."],
	"pa.crisis": ["Taint exceeds comfort. Comfort has been revised."],
	"pa.research_completed": ["Innovation granted. Your gratitude is mandatory."],
	"pa.colonist_died": ["{who} has left the program. Effects forwarded."],
	"pa.map_switched": ["Transfer noted. Carry your own paperwork."],
	"pa.outpost_lost": ["Outpost lost. The form for that is long."],
	"pa.day": ["Day {n}. Productivity noted. Enthusiasm optional."],
}

var sim: Simulation
var feed: FeedTicker
var pa: PaBanner
var _picker: Object = null
var _last: Dictionary = {}  # key -> last line, fallback no-repeat
var _rng := RandomNumberGenerator.new()
var _conns: Array = []  # [signal, Callable]


func _init(p_feed: FeedTicker, p_pa: PaBanner) -> void:
	feed = p_feed
	pa = p_pa
	if ResourceLoader.exists(PICKER_PATH):
		var scr: Script = load(PICKER_PATH)
		if scr != null and scr.can_instantiate():
			_picker = scr.new()
		elif scr != null and scr.has_method("load"):
			_picker = scr.call("load")
		if _picker != null and not (_picker.has_method("pick") and _picker.has_method("has_key")):
			_picker = null


func bind(p_sim: Simulation) -> void:
	unbind()
	sim = p_sim
	var b: Node = sim.bus
	_c(b.enemy_killed, _on_enemy_killed)
	_c(b.colonist_downed, _on_downed)
	_c(b.colonist_died, _on_died)
	_c(b.building_destroyed, _on_building)
	_c(b.wave_started, func(_i: int, _s: float) -> void: _pa("pa.wave_started", {}))
	_c(b.wave_incoming, func(_o: Vector2i, _t: int) -> void: _pa("pa.wave_incoming", {}))
	_c(b.crisis_started, func(_i: String, _t: String) -> void: _pa("pa.crisis", {}))
	_c(b.research_completed, func(_i: String) -> void: _pa("pa.research_completed", {}))
	_c(b.map_switched, func(_i: int) -> void: _pa("pa.map_switched", {}))
	if b.has_signal("outpost_lost"):
		_c(b.outpost_lost, func(_i: int) -> void: _pa("pa.outpost_lost", {}))
	_c(b.day_started, _on_day)


func unbind() -> void:
	for pair: Array in _conns:
		var s: Signal = pair[0]
		if s.is_connected(pair[1]):
			s.disconnect(pair[1])
	_conns.clear()


func _c(s: Signal, f: Callable) -> void:
	s.connect(f)
	_conns.append([s, f])


func _on_enemy_killed(id: int) -> void:
	var kind := sim.threats.last_kill_kind()
	var cause := sim.threats.last_kill_cause()
	var name_ := str(sim.defs.enemies.get(kind, {}).get("name", "Creature"))
	var ctx := {"enemy": name_, "n": id, "cause": cause}
	var keys: Array[String] = ["feed.%s.%s" % [kind, cause], "feed.%s.generic" % kind, "feed.generic"]
	feed.push(_line(keys, ctx, id))


func _on_downed(id: int) -> void:
	feed.push(_line(["feed.downed", "feed.generic"], {"who": _who(id), "victim": _who(id)}, id))


func _on_died(id: int) -> void:
	_pa("pa.colonist_died", {"who": _who(id), "victim": _who(id), "cause": death_cause(id)}, id)


func _on_building(id: int) -> void:
	feed.push(_line(["feed.building", "feed.generic"], {"n": id}, id))


func _on_day(day: int) -> void:
	if day > 0 and day % DAY_ASIDE_EVERY == 0:
		_pa("pa.day", {"n": day}, day)


func _pa(key: String, ctx: Dictionary, subject := 0) -> void:
	pa.announce(_line([key], ctx, subject))


func _who(id: int) -> String:
	var c: Colonist = sim.colonists.get_by_id(id)
	return c.display_name if c != null else "Inmate"


## Cosmetic cause of a colonist death from the body state; "generic" when unknown.
func death_cause(id: int) -> String:
	var c: Colonist = sim.colonists.get_by_id(id)
	if c == null or c.health == null:
		return "generic"
	var h: HealthState = c.health
	if h.injuries.is_empty():
		return "generic"
	var worst: Injury = h.injuries[0]
	for i in h.injuries:
		if i.severity > worst.severity:
			worst = i
	if worst.kind == "starvation" or worst.kind == "burn":
		return worst.kind
	return "bleed_out" if h.blood <= 0.0 else "generic"


func _line(keys: Array[String], ctx: Dictionary, subject: int) -> String:
	var tick: int = sim.tick if sim != null else 0
	for k in keys:
		var s := ""
		if _picker != null and _picker.has_key(k):
			var c := ctx.duplicate()
			c["tick"] = tick
			s = str(_picker.pick(k, c))
		elif FALLBACK.has(k):
			s = _fallback(k, ctx, tick, subject)
		if s != "":
			return _fit(s)
	return _fit(_fallback("feed.generic", ctx, tick, subject))


func _fallback(key: String, ctx: Dictionary, tick: int, subject: int) -> String:
	var bank: Array = FALLBACK[key]
	_rng.seed = hash([tick, key, subject])
	var s := ""
	for _t in 3:
		s = _fill(str(bank[_rng.randi() % bank.size()]), ctx)
		if bank.size() < 2 or s != str(_last.get(key, "")):
			break
	_last[key] = s
	return s


func _fill(s: String, ctx: Dictionary) -> String:
	for k: String in ["who", "victim", "enemy", "n", "cause"]:
		s = s.replace("{%s}" % k, str(ctx.get(k, "")))
	return s


func _fit(s: String) -> String:
	return s if s.length() <= MAX_LEN else s.left(MAX_LEN - 1) + "."
