class_name AmmoSystem
extends RefCounted
## Ammunition as a logistics link: turret buffers, rifle pouches, refill hauling.
## Numbers: data/ammo.json. Ledger: rounds that leave the world (stack -> turret
## buffer / pouch) are recorded as consumed "loaded"; initial loads are free;
## spilled rounds are produced again. `fired` counts shots for stats/tests.

var fired := 0

var sim: Simulation
var cfg: Dictionary
var item: String


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	cfg = sim.defs.ammo
	item = str(cfg["item"])


## Gives a fresh turret its starting rounds (called when a building is placed).
func init_building(b: Building) -> void:
	if not b.def.has("turret"):
		return
	var n := int(cfg["turret"]["initial"])
	b.ammo = n
	b.ammo_policy = str(cfg["default_policy"])


func turret_capacity() -> int:
	return int(cfg["turret"]["capacity"])


## Rounds a hauler may still bring to turret `b`.
func turret_missing(b: Building) -> int:
	return maxi(0, turret_capacity() - b.ammo)


func turret_wants_refill(b: Building) -> bool:
	return b.def.has("turret") and not b.broken and \
		float(b.ammo) < float(turret_capacity()) * float(cfg["turret"]["refill_below"])


## Turret shot gate. Returns true and spends rounds if the turret may fire at distance `d`.
func turret_try_fire(b: Building, d: float) -> bool:
	if b.ammo_policy == "conserve" and d > float(cfg["turret"]["conserve_range"]):
		return false
	var use := int(cfg["turret"]["per_shot"])
	if b.ammo < use:
		if not b.ammo_empty_flagged:
			b.ammo_empty_flagged = true
			sim.bus.ammo_depleted.emit("turret", b.id)
		return false
	b.ammo -= use
	fired += use
	return true


func load_turret(b: Building, n: int) -> int:
	var k := mini(n, turret_missing(b))
	if k <= 0:
		return 0
	b.ammo += k
	sim.ledger.record_consumed(item, k, "loaded")
	b.ammo_empty_flagged = false
	return k


# --- Rifles ---------------------------------------------------------------------

func _pouch_init(c: Colonist) -> void:
	if c.combat.pouch >= 0:
		return
	var n := int(cfg["pouch"]["initial"])
	c.combat.pouch = n


## Spends rounds for one rifle shot (refilling the pouch from a nearby
## stockpile when short). Returns false when the colonist cannot shoot.
func rifle_try_fire(c: Colonist) -> bool:
	_pouch_init(c)
	var st: CombatState = c.combat
	var use := float(cfg["pouch"]["per_shot"]) * maxf(0.0, 1.0 + sim.perks.mod(c, "ammo_use"))
	var need := int(floor(st.ammo_debt + use))
	if st.pouch < need:
		_refill_pouch(c)
	if st.pouch < need:
		if not st.ammo_empty_flagged:
			st.ammo_empty_flagged = true
			sim.bus.ammo_depleted.emit("colonist", c.id)
		return false
	st.ammo_debt = st.ammo_debt + use - need
	if need > 0:
		st.pouch -= need
		fired += need
	return true


func _refill_pouch(c: Colonist) -> void:
	var st: CombatState = c.combat
	var r := float(cfg["pouch"]["refill_range"])
	var best := Vector2i(-1, -1)
	var best_d := INF
	for cell: Vector2i in sim.items.stacks:
		if sim.items.item_at(cell) != item or not sim.items.is_stored(cell):
			continue
		var d := Vector2(c.cell).distance_to(Vector2(cell))
		if d <= r and d < best_d:
			best_d = d
			best = cell
	if best.x < 0:
		return
	var want := int(cfg["pouch"]["capacity"]) - st.pouch
	var got := sim.items.take_at(best, want)
	if got > 0:
		st.pouch += got
		sim.ledger.record_consumed(item, got, "loaded")
		st.ammo_empty_flagged = false


# --- Command (through Simulation) ---------------------------------------------------

func set_policy(building_id: int, policy: String) -> bool:
	var b := sim.buildings.get_by_id(building_id)
	if b == null or not b.def.has("turret") or not (policy in cfg["policies"]):
		return false
	b.ammo_policy = policy
	return true


## A destroyed/deconstructed turret spills its rounds.
func spill(b: Building) -> void:
	if b.ammo > 0:
		sim.ledger.record_produced(item, b.ammo, "spilled")
		sim.items.drop(b.cell, item, b.ammo)
		b.ammo = 0
