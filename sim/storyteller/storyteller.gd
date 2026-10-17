class_name Storyteller
extends RefCounted
## AI director (stub). Later it will pick events that break exactly one link
## of the colony (lightning in a substation, a sick engineer, a jammed
## conveyor...). For now it only narrates key moments through the bus.

var sim: Simulation


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	sim.listen(sim.bus.first_refine_done, func() -> void:
		_say("first_refine", "Первая партия очищена. Отходы отравляют планету — запущен прогноз конца."))
	sim.listen(sim.bus.threat_awakened, func() -> void:
		_say("awakened", "Из-под земли доносится скрежет. Твари проснулись."))
	sim.listen(sim.bus.wave_started, func(i: int, _s: float) -> void:
		_say("wave", "Волна %d! Колонисты бегут в капсулу." % i))
	sim.listen(sim.bus.building_broken, func(id: int) -> void:
		var b := sim.buildings.get_by_id(id)
		if b:
			_say("broken", "%s сломалась — нужен ремонт." % b.def["name"]))


func tick() -> void:
	pass


func _say(event_id: String, text: String) -> void:
	sim.bus.story_event.emit(event_id, text)
