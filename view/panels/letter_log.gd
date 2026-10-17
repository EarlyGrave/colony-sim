class_name LetterLog
extends RefCounted
## Bus-driven log of important events ("letters"). Pure view-side state.
## Entries: {"text": String, "tick": int, "level": "info"|"warn"|"bad"}.

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
	_listen("forecast_revealed", func() -> void: add("Открыт прогноз конца планеты.", "info"))


func unbind() -> void:
	if _bus != null and is_instance_valid(_bus):
		for c: Array in _conns:
			if _bus.is_connected(c[0], c[1]):
				_bus.disconnect(c[0], c[1])
	_conns.clear()
	_bus = null
	sim = null


func add(text: String, level := "info") -> void:
	if text == "":
		return
	var entry := {"text": text, "tick": sim.tick if sim else 0, "level": level}
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
