# Contract: items, inventory, storage (stage E10)

Status: proposal by the architect agent (E9). Not implemented. Keeps all existing
decisions: data in JSON loaded by `Defs`; one stack per cell; every create/destroy
goes through `Ledger`; all randomness via `sim.rng`; sim classes are `RefCounted`
(no `Node`, no scene tree, no autoload lookups).

## 1. Item definition schema (`data/items.json`)

Key = item id. Fields:

| field | type | required | meaning |
|---|---|---|---|
| `name` | string | yes | display name |
| `category` | enum | yes | `raw`, `processed`, `component`, `advanced`, `food`, `medicine`, `ammo`, `weapon`, `armor`, `tool`, `waste` |
| `weight` | float | yes | weight of ONE unit (carry limit, hauling cost) |
| `stack` | int | yes | max units per cell / per inventory slot |
| `tags` | array[string] | yes (may be `[]`) | free tags: `food`, `fuel`, `material`, `weapon`, `armor`, `tool`, `ammo`, `medicine` ... Recipes and rules may match by tag |
| `icon` | string | yes | sprite name in `assets/sprites/` |
| `color` | string | no | kept from current file (fallback tint when no sprite) |
| `contaminates` | bool | no | default false; true = leaking/loss of this item pollutes the map (as `waste` does today) |
| `slot` | enum | no | only for equipables: `weapon`, `armor`, `tool` |

Example:

```json
{
	"essence_ore":     {"name": "Руда эссенции", "category": "raw", "weight": 1.0, "stack": 50, "tags": ["material"], "icon": "essence_ore", "color": "#7a5cc2"},
	"refined_essence": {"name": "Очищенная эссенция", "category": "processed", "weight": 0.5, "stack": 50, "tags": ["material", "fuel"], "icon": "refined_essence", "color": "#d36bff"},
	"waste":           {"name": "Отходы", "category": "waste", "weight": 2.0, "stack": 50, "tags": [], "icon": "waste", "color": "#7fbf3f", "contaminates": true}
}
```

Validation in `Defs.load_from`: unknown `category`, missing `weight/stack/icon`, `stack < 1`,
`weight < 0`, `slot` on a non-equipable category -> `push_error` (tests fail on engine errors).

### Migration note

Keep the existing ids `essence_ore`, `refined_essence`, `waste`. The original prompt used
`essence_refined` / `toxic_waste`; renaming would touch recipes, buildings, zones,
balance, events, tests and sprites for no gameplay gain. **Decision (recommended):
keep existing ids**, record in `DECISIONS.md`. Existing entries get the new fields
(`category`, `weight`, `tags`, `icon`) added; `stack`, `color`, `contaminates` unchanged.
`Defs.item_stack()` keeps working. Missing new fields on old data = load error, so
migrate `items.json` in the same commit as the validator.

## 2. Stack model: where items live

A stack is `{item_id: String, count: int}` (plain Dictionary, as now). Never more than
`stack` units, never mixed ids in one stack. Every location below has ONE owner class;
nobody else mutates its storage directly.

| location | owner | shape | notes |
|---|---|---|---|
| ground stack | `ItemSystem.stacks` | `Vector2i -> stack`, one per cell | `drop()` spills to nearest free cell, records "lost" when no room (existing) |
| storage zone cell | `ItemSystem.stacks` + `zone_cells` | same as ground; cell belongs to a zone | a ground stack inside a zone is "stored" (existing `is_stored`) |
| container (future building with storage) | `Building.storage` managed via `ItemSystem` API | `Array` of stacks, `capacity_slots` from building def | same filter/priority rules as zones |
| colonist inventory | `Colonist.inventory` (new small RefCounted `Inventory`) | `Array` of stacks + `equipment: {weapon, armor, tool}` | weight limit = `balance.json` colonist carry limit (today `carry_capacity: 10` units; E10 turns it into a weight limit, `carry_weight`). Equipment items do not count against the limit |
| building buffers | `Building.input_buf` / `output_buf` (`Dictionary item_id -> int`) | per recipe, capped by recipe/building def | existing; on destroy buffers spill via `ItemSystem.drop()` |

Rules:
- Moving between locations is always remove-from-A then add-to-B inside one
  `ItemSystem` call (`transfer(...)`), so count never changes and the ledger is not touched.
- `Inventory` API (pure, no sim refs): `add(item_id, n, defs) -> int` (returns accepted),
  `remove(item_id, n) -> int`, `count(item_id) -> int`, `weight(defs) -> float`,
  `equip(item_id, defs) -> bool`, `unequip(slot) -> String`.
- Deterministic iteration: stacks in arrays or sorted keys, never raw Dictionary order
  where it affects outcomes.

## 3. Storage: filters and priority

A storage (zone or container) has:
- `categories: Array[String]` - allowed categories (empty = nothing; default from `zones.json`).
  `zones.json` `accepts` (list of item ids) stays valid as an additional whitelist;
  effective rule = item id in `accepts` (if non-empty) AND item category in `categories`
  (if set by the player).
- `priority`: `low=0, normal=1, high=2, critical=3` (default `normal`).
  The enum lives in `data/rules.json` or `balance.json`, not hard-coded.

Hauling: a stored or ground item is hauled when a storage with strictly higher priority
than its current one (ground = -1) can accept it. Ties never move items (no ping-pong).
Hauling jobs reserve both source and target cells by string key (existing convention).

API sketch on `ItemSystem`:

```gdscript
func can_accept(cell: Vector2i, item_id: String, count: int) -> bool
## Cell in a storage, filter passes, and (cell empty or same id with space_for >= count).

func find_storage_for(item_id: String, from_priority: int = -1, near: Vector2i = Vector2i.ZERO,
		is_blocked: Callable = Callable()) -> Vector2i
## Best cell: highest priority > from_priority, then nearest to `near` (tie-break by y, x).
## Returns Vector2i(-1, -1) when none. Replaces/extends find_storage_cell().

func storage_priority_at(cell: Vector2i) -> int      # -1 for non-storage cells
func get_zone_filter(zone_id: String) -> Array[String]
func get_zone_priority(zone_id: String) -> int
func transfer(from_cell: Vector2i, to_cell: Vector2i, n: int) -> int   # emits item_moved
```

## 4. Conservation law (Ledger)

For every item id:

```
world_count(id) == ledger.produced[id] - ledger.consumed[id]
world_count(id) = ground + stored + sum(colonist inventories + equipment)
                  + sum(building buffers) + sum(container contents)
```

Sources (`record_produced`, source string): `mining`, `recipe` (outputs), `event`
(storyteller drops), `start` (starting kit), `spawn` (enemy loot, if added).
Sinks (`record_consumed`, sink string): `recipe` (inputs), `consumption` (eating, medicine,
ammo, fuel), `destroyed` (building/fire/enemy destroys items), `lost` (no room to drop;
already tracked), `decay` (if ever added).
Moves (haul, pick up, equip, buffer fill, spill) NEVER touch the ledger.

Test invariant (extend `Ledger` with `check(item_system, colonists, buildings) -> Array[String]`
returning violations, empty = OK): call after N ticks in scenarios with mining, refining,
a wave that destroys a building, and a colonist dying (inventory must spill, not vanish).
Add `world_count_all(id)` to `ItemSystem` (or a helper in `tests/scenario.gd`) that sums all
locations above, and assert `world_count_all(id) == ledger.balance_of(id)` for every id.

## 5. Bus signals (`autoload/event_bus.gd`)

```gdscript
signal item_moved(item_id: String, count: int, from_cell: Vector2i, to_cell: Vector2i)
signal item_produced(item_id: String, count: int, source: String)
signal item_consumed(item_id: String, count: int, sink: String)
signal inventory_changed(colonist_id: int)
signal equipment_changed(colonist_id: int, slot: String, item_id: String)
signal storage_filter_changed(zone_id: String, categories: Array)
signal storage_priority_changed(zone_id: String, priority: int)
signal building_buffer_changed(building_id: int)
```

The view only listens; sim never depends on handlers. Tests use `TestCase.make_bus()`.

## 6. Player commands (on `Simulation`)

```gdscript
func set_storage_filter(zone_id: String, categories: Array) -> bool   # validates categories vs Defs
func set_storage_priority(zone_id: String, priority: int) -> bool     # 0..3
func equip_item(colonist_id: int, item_id: String) -> bool            # optional, E10b
func drop_inventory(colonist_id: int) -> void                         # optional
```

All forward to `ItemSystem`; the view never mutates storage. Zone settings are per
zone instance (not per type), stored in `ItemSystem` and included in future saves/replays.

## 7. Open questions for the orchestrator

1. Confirm: keep ids `essence_ore`, `refined_essence`, `waste` (not `essence_refined`/`toxic_waste`)?
2. Carry limit: switch from item count (`carry_capacity: 10`) to weight, or keep both?
3. Are zone settings per zone type (`stockpile`) or per painted zone instance? (Proposed: instance.)
4. Containers as buildings in E10, or only zones + buffers (containers in a later stage)?
5. Equipment in E10 or defer slots until weapons/armor exist as items?
6. Should `destroyed`/`lost` items of category `waste` contaminate immediately (matches core dilemma)?
7. Priority enum: 4 levels as proposed, or per-zone integer?
