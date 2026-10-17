class_name LetterLog
extends RefCounted
## Bus-driven log of important events ("letters"). Pure view-side state.
## Entries: {"text", "tick", "level": "info"|"warn"|"bad", "cell": Vector2i (optional)}.

signal letter_added(entry: Dictionary)

const MAX_ENTRIES := 60

var entries: Array[Dictionary] = []
var unread := 0
var sim: Simulation
var _bus: Object
var _conns: Array = []  # [signal name, callable]


func bind(p_sim: Simulation, bus: Object) -> void:
	unbind()
	sim = p_sim
	_bus = bus
	entries.clear()
	unread = 0
	_listen("wave_started", func(i: int = 0, strength: float = 0.0) -> void:
		add("Волна %d началась (сила ~%.0f)." % [i, strength], "bad"))
	_listen("wave_incoming", func(a: Variant = null, b: Variant = null) -> void:
		add("Приближается волна тварей.", "warn"))
	_listen("wave_ended", func(i: int = 0) -> void: add("Волна %d отбита." % i, "info"))
	_listen("threat_awakened", func() -> void: add("Твари пробудились.", "warn"))
	_listen("building_broken", func(id: int = 0) -> void: add("Сломано: %s." % _building_name(id), "warn"))
	_listen("building_destroyed", func(id: int = 0) -> void: add("Разрушено: %s." % _building_name(id), "bad"))
	_listen("colonist_died", func(id: int = 0) -> void: add("Погиб колонист: %s." % _colonist_name(id), "bad"))
	_listen("story_event", func(_id: String = "", text: String = "") -> void: add(text, "warn"))
	_listen("raid_started", func(raid_id: String = "", _p: float = 0.0, n: int = 0) -> void:
		var rd: Dictionary = sim.defs.raids.get(raid_id, {}) if sim.get("defs") and sim.defs.get("raids") != null else {}
		add("Налёт: %s (%d тварей)." % [str(rd.get("name", raid_id)), n], "bad"))
	_listen("raid_tremor", func(cell: Vector2i = Vector2i.ZERO, _t: int = 0, text: String = "") -> void:
		add(text if text != "" else "Земля дрожит…", "warn", cell))
	_listen("raid_burrowed", func(cell: Vector2i = Vector2i.ZERO, n: int = 0) -> void:
		add("Твари вылезли из-под земли (%d)." % n, "bad", cell))
	_listen("raid_retreat", func(_r: String = "") -> void: add("Твари отступают.", "info"))
	_listen("colonist_downed", func(id: int = 0) -> void:
		add("Колонист без сознания: %s." % _colonist_name(id), "bad", _colonist_cell(id)))
	_listen("colonist_joined", func(id: int = 0) -> void:
		add("К колонии присоединился %s." % _colonist_name(id), "info", _colonist_cell(id)))
	_listen("event_choice_posted", func(_u: int = 0, text: String = "") -> void:
		add("ВАЖНО: %s (панель «События»)" % text, "bad"))
	_listen("mood_break_started", func(id: int = 0, kind: String = "") -> void:
		add("Срыв у %s: %s." % [_colonist_name(id), kind], "bad", _colonist_cell(id)))
	_listen("colonist_starving", func(id: int = 0) -> void:
		add("Голодает: %s." % _colonist_name(id), "warn", _colonist_cell(id)))
	_listen("forecast_revealed", func() -> void: add("Открыт прогноз конца планеты.", "info"))


func unbind() -> void:
	if _bus != null and is_instance_valid(_bus):
		for c: Array in _conns:
			if _bus.is_connected(c[0], c[1]):
				_bus.disconnect(c[0], c[1])
	_conns.clear()
	_bus = null
	sim = null


func add(text: String, level := "info", cell: Variant = null) -> void:
	if text == "":
		return
	var entry := {"text": text, "tick": sim.tick if sim else 0, "level": level}
	if cell is Vector2i:
		entry["cell"] = cell
	entries.push_front(entry)
	if entries.size() > MAX_ENTRIES:
		entries.pop_back()
	unread += 1
	letter_added.emit(entry)


func mark_read() -> void:
	unread = 0


func _listen(signal_name: String, callable: Callable) -> void:
	if _bus == null or not _bus.has_signal(signal_name):
		return
	_bus.connect(signal_name, callable)
	_conns.append([signal_name, callable])


func _building_name(id: int) -> String:
	var b: Building = sim.buildings.get_by_id(id) if sim else null
	return str(b.def["name"]) if b else "постройка"


func _colonist_name(id: int) -> String:
	if sim:
		for c in sim.colonists.list:
			if c.id == id:
				return c.display_name
	return "?"


func _colonist_cell(id: int) -> Variant:
	if sim:
		for c in sim.colonists.list:
			if c.id == id:
				return c.cell
	return null
