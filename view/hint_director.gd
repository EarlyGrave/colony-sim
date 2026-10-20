class_name HintDirector
extends RefCounted
## F10W1: one-shot contextual hints for newer systems. Read-only: polls public sim state, never mutates it.
## Texts: data/hints.json (id -> text). Each id fires once per profile (SeenFlags).
## Density (MetaStore): "Off" = nothing, "New" = only NEW_ONLY ids, "Full" = all.
## Suppressed while a tutorial step is active. At most one hint per MIN_GAP seconds; queue entries older than STALE are dropped.

const MIN_GAP := 10.0
const STALE := 120.0
const NEW_ONLY: Array = ["gear_first", "drone_raid"]
const PATH_QUEST := "q14_three_forms"
const TEXTS_PATH := "res://data/hints.json"

var texts: Dictionary = {}
var density := ""  # tests may force "Full" | "New" | "Off"; empty = read MetaStore
var clock := 0.0  # last poll time, used to stamp bus-triggered entries
var _queue: Array = []  # [{id, t}]
var _last_shown := -1000.0
var _bus: Object = null


func _init() -> void:
	var f := FileAccess.open(TEXTS_PATH, FileAccess.READ)
	if f != null:
		var d: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		if d is Dictionary:
			texts = d


## Connect the event-driven triggers (call once; disconnect_bus before dropping).
func connect_bus(bus: Object) -> void:
	disconnect_bus()
	_bus = bus
	bus.quest_choice_posted.connect(_on_choice)
	bus.metro_raid_started.connect(_on_raid)


func disconnect_bus() -> void:
	if _bus != null and is_instance_valid(_bus):
		_bus.quest_choice_posted.disconnect(_on_choice)
		_bus.metro_raid_started.disconnect(_on_raid)
	_bus = null


func _on_choice(_uid: int, quest_id: String, _opts: Array) -> void:
	if quest_id == PATH_QUEST:
		_enqueue("path_choice", clock)


func _on_raid(_id: String, _points: float) -> void:
	_enqueue("drone_raid", clock)


func _enqueue(id: String, now: float) -> void:
	if SeenFlags.seen(id) or not texts.has(id):
		return
	for q: Dictionary in _queue:
		if q["id"] == id:
			return
	_queue.append({"id": id, "t": now})


func _allowed(id: String, d: String) -> bool:
	return d == "Full" or (d == "New" and NEW_ONLY.has(id))


## Poll once (~1 s). `show` receives the hint text. Returns the id shown or "".
func poll(sim: Simulation, now: float, show: Callable) -> String:
	clock = now
	if sim == null:
		return ""
	var d := density if density != "" else MetaStore.load_hint_density()
	if d == "Off":
		_queue.clear()
		return ""
	if TutorialCard.current_step(sim) >= 0:
		return ""
	_queue = _queue.filter(func(q: Dictionary) -> bool: return now - float(q["t"]) <= STALE and not SeenFlags.seen(str(q["id"])))
	_scan(sim, now)
	if now - _last_shown < MIN_GAP:
		return ""
	for i in _queue.size():
		var id := str(_queue[i]["id"])
		if not _allowed(id, d):
			continue
		_queue.remove_at(i)
		SeenFlags.mark(id)
		_last_shown = now
		show.call(str(texts[id]))
		return id
	return ""


func _scan(sim: Simulation, now: float) -> void:
	var eq: EquipmentSystem = sim.equipment
	if eq != null and not eq.instances.is_empty():
		_enqueue("gear_first", now)
		if not SeenFlags.seen("gear_damaged"):
			for id: int in eq.instances:
				var g: GearItem = eq.instances[id]
				if g.durability < g.max_durability * 0.5:
					_enqueue("gear_damaged", now)
					break
	if sim.petition != null and not SeenFlags.seen("alt_available"):
		var p: int = sim.petition.next_phase()
		if p > 0 and sim.petition.alt_available(p):
			_enqueue("alt_available", now)
