class_name WaveReportCard
extends PanelContainer
## B5: wave ETA marker + post-wave report card. Pure view: samples enemy targets while a wave is
## active, listens to existing bus signals, emits `wave_report` (a read of what it saw) when the
## wave ends. Shown in the HUD top stack only while something is worth saying.

signal focus_requested(cell: Vector2i)

const HOLD_SEC := 20.0

var sim: Simulation
var _bus: Node
var _label: Label
var _look: Button
var _close: Button
var _eta_ticks := -1  ## tick the incoming wave is due, -1 = no warning
var _origin := Vector2i(-1, -1)
var _active := false
var _lost: Array = []  ## [{name, by, why}]
var _hits: Dictionary = {}  ## "attacker>target" -> samples
var _by_building: Dictionary = {}  ## building id -> attacker name that last chose it
var _deaths := 0
var _kills := 0
var _report: Dictionary = {}
var _shown_for := 0.0


func _init() -> void:
	visible = false
	modulate = Color(1.0, 0.85, 0.7)
	var row := HBoxContainer.new()
	add_child(row)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.custom_minimum_size.x = 200
	row.add_child(_label)
	_look = Button.new()
	_look.text = "Look"
	_look.custom_minimum_size = Vector2(96, 64)
	_look.focus_mode = Control.FOCUS_NONE
	_look.pressed.connect(func() -> void:
		if sim != null and _origin.x >= 0:
			focus_requested.emit(_origin))
	row.add_child(_look)
	_close = Button.new()
	_close.text = "OK"
	_close.custom_minimum_size = Vector2(80, 64)
	_close.focus_mode = Control.FOCUS_NONE
	_close.pressed.connect(func() -> void:
		_report = {}
		refresh())
	row.add_child(_close)


func bind(p_sim: Simulation) -> void:
	sim = p_sim
	_bus = p_sim.bus
	_reset()
	_report = {}
	_eta_ticks = -1
	visible = false
	if _bus.wave_ended.is_connected(_on_ended):
		return
	_bus.wave_incoming.connect(_on_incoming)
	_bus.wave_started.connect(_on_started)
	_bus.building_destroyed.connect(_on_destroyed)
	_bus.enemy_killed.connect(_on_killed)
	_bus.colonist_died.connect(_on_died)
	_bus.wave_ended.connect(_on_ended)


func _on_incoming(origin: Vector2i, ticks_left: int) -> void:
	_origin = origin
	_eta_ticks = sim.tick + ticks_left


func _on_started(_i: int, _s: float) -> void:
	_reset()
	_active = true
	_eta_ticks = -1
	_report = {}


func _on_killed(_id: int) -> void:
	_kills += 1


func _on_died(_id: int) -> void:
	if _active:
		_deaths += 1


func _reset() -> void:
	_active = false
	_lost.clear()
	_hits.clear()
	_by_building.clear()
	_deaths = 0
	_kills = 0


func _on_destroyed(id: int) -> void:
	if not _active:
		return
	var b: Building = sim.buildings.get_by_id(id)
	var nm := str(b.def["name"]) if b != null else "building"
	var by := str(_by_building.get(id, ""))
	_lost.append({"name": nm, "by": by, "why": ("Targeted by %s" % by) if by != "" else "Collateral damage"})


## Called every HUD frame: records who is aiming at what (cheap, read-only).
func tick(delta: float) -> void:
	if sim == null:
		return
	if _active:
		for e in sim.threats.enemies:
			if e.leaving:
				continue
			var an := str(e.def.get("name", e.def_id))
			if e.target_kind == Enemy.Target.BUILDING and e.target_b != null:
				_by_building[e.target_b.id] = an
				var k := "%s>%s" % [an, str(e.target_b.def["name"])]
				_hits[k] = int(_hits.get(k, 0)) + 1
			elif e.target_kind == Enemy.Target.COLONIST and e.target_c != null:
				var k2 := "%s>%s" % [an, e.target_c.name]
				_hits[k2] = int(_hits.get(k2, 0)) + 1
	if not _report.is_empty():
		_shown_for += delta
		if _shown_for > HOLD_SEC:
			_report = {}
	refresh()


func _on_ended(i: int) -> void:
	var top := ""
	var best := 0
	var keys: Array = _hits.keys()
	keys.sort()
	for k: String in keys:
		if int(_hits[k]) > best:
			best = int(_hits[k])
			top = k
	_report = {
		"wave": i, "lost": _lost.duplicate(true), "main_attack": top.replace(">", " -> "),
		"colonist_deaths": _deaths, "kills": _kills,
	}
	_shown_for = 0.0
	_active = false
	_bus.wave_report.emit(_report)
	refresh()


func text_now() -> String:
	if not _report.is_empty():
		var r := _report
		var lost: Array = r["lost"]
		var t := "Wave %d over: %d kills, %d lost, %d inmates down." % [r["wave"], r["kills"], lost.size(), r["colonist_deaths"]]
		if str(r["main_attack"]) != "":
			t += "\nMain attack: %s." % r["main_attack"]
		for i in mini(lost.size(), 3):
			t += "\n- %s (%s)" % [lost[i]["name"], lost[i]["why"]]
		if lost.size() > 3:
			t += "\n- +%d more" % (lost.size() - 3)
		return t
	if _eta_ticks >= 0 and not _active and sim != null:
		var left := maxi(0, _eta_ticks - sim.tick)
		return "Wave from the %s in %.1f h" % [sim.threats.side_name(_origin), left * 24.0 / sim.ticks_per_day]
	return ""


func refresh() -> void:
	var t := text_now()
	visible = t != ""
	_label.text = t
	_close.visible = not _report.is_empty()
	_look.visible = _report.is_empty() and _origin.x >= 0
