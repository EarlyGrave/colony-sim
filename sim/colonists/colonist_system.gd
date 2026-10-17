class_name ColonistSystem
extends RefCounted
## Owns colonists and ticks them (decisions are delegated to JobSystem).

const NAMES: Array[String] = [
	"Вера", "Гром", "Лис", "Мирон", "Сиплый", "Тень", "Кнут", "Рыжая", "Дед", "Шило", "Ольха", "Фитиль",
]

var sim: Simulation
var list: Array[Colonist] = []
var _next_id := 1


func _init(p_sim: Simulation) -> void:
	sim = p_sim


func spawn(cell: Vector2i) -> Colonist:
	var nm := NAMES[sim.rng.randi_range(0, NAMES.size() - 1)]
	var c := Colonist.new(_next_id, nm, cell, sim.defs.balance["colonist"])
	_next_id += 1
	# region jobs-core
	c.skills = Skills.create(sim.defs, sim.rng)
	# endregion
	# region combat
	c.combat = CombatState.new()
	c.combat.weapon = str(sim.defs.weapons["combat"]["start_weapon"])
	# endregion
	list.append(c)
	return c


func tick() -> void:
	for c in list:
		if c.alive:
			sim.jobs.tick_colonist(c)


func alive_count() -> int:
	var n := 0
	for c in list:
		if c.alive:
			n += 1
	return n


func get_by_id(id: int) -> Colonist:
	for c in list:
		if c.id == id:
			return c
	return null


func kill(c: Colonist) -> void:
	if not c.alive:
		return
	sim.jobs.end_job(c, Job.Status.FAILED)
	if c.carry_count > 0:
		sim.items.drop(c.cell, c.carry_item, c.carry_count)
		c.carry_item = ""
		c.carry_count = 0
	c.alive = false
	c.hidden = false
	sim.bus.colonist_died.emit(c.id)
