class_name RaidObjective
extends RefCounted
## What a raid wants (data/raids.json "objective" weights + "objective_params").
## gorge: eat waste/ore lying on the map, then leave. wreck: break the top-priority building, then leave.
## hunt: classic (no objective logic). Active only when balance threat.raid_objectives is true.

var kind := "hunt"
var met := false
var progress := 0
var need := 0
var bite := 3
var items: Array = []
var target_id := -1
var cell := Vector2i(-1, -1)
var _recheck := 0


## Weighted pick on `rng` (called after composition so hunt-only data never consumes rng).
static func roll(raid: Dictionary, rng: RandomNumberGenerator) -> String:
	var w: Variant = raid.get("objective", "hunt")
	if w is String:
		return str(w)
	var total := 0.0
	for k: String in w:
		total += float(w[k])
	if total <= 0.0:
		return "hunt"
	var r := rng.randf() * total
	for k: String in w:
		r -= float(w[k])
		if r <= 0.0:
			return k
	return "hunt"


## Builds the objective for `k`; falls back to hunt when it cannot be pursued (nothing to eat / break).
static func make(sim: Simulation, raid: Dictionary, k: String) -> RaidObjective:
	var o := RaidObjective.new()
	var p: Dictionary = raid.get("objective_params", {}).get(k, {})
	if k == "gorge":
		o.items = p.get("items", ["waste", "essence_ore"])
		o.need = int(p.get("need", 10))
		o.bite = int(p.get("bite", 3))
		o.cell = o.nearest_item(sim, Vector2i(sim.map.width / 2, sim.map.height / 2))
		if o.cell.x < 0:
			return o
		o.kind = k
	elif k == "wreck":
		var best: Building = null
		for b in sim.buildings.list:
			if best == null or int(b.def.get("threat_priority", 0)) > int(best.def.get("threat_priority", 0)):
				best = b
		if best != null:
			o.kind = k
			o.target_id = best.id
	return o


func nearest_item(sim: Simulation, from: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var bd := INF
	for c: Vector2i in sim.items.stacks:
		if sim.items.stacks[c]["item"] in items:
			var d := Vector2(c).distance_squared_to(Vector2(from))
			if d < bd:
				bd = d
				best = c
	return best


func text() -> String:
	match kind:
		"gorge":
			return "They are hungry: they will gorge on waste and ore left lying about."
		"wreck":
			return "They are after our best machine."
	return ""


## One enemy's turn of a gorge raid. Returns true when it consumed the turn.
func gorge_step(sim: Simulation, e: Enemy) -> bool:
	if kind != "gorge" or met:
		return false
	if sim.items.count_at(cell) == 0 or not (sim.items.item_at(cell) in items):
		cell = nearest_item(sim, e.cell)
		if cell.x < 0:
			met = progress > 0
			return false
	if Vector2(e.cell).distance_to(Vector2(cell)) <= 1.5:
		if e.attack_cd == 0:
			e.attack_cd = 8
			var it := sim.items.item_at(cell)
			var k := sim.items.take_at(cell, bite)
			if k > 0:
				sim.ledger.record_consumed(it, k, "raid_lost")
				progress += k
				if progress >= need:
					met = true
		return true
	if sim.threats._approach_cell(e, cell) == GridMover.Move.FAILED:
		cell = nearest_item(sim, e.cell)
		return false
	return true
