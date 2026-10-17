# Contracts index and cross-check

Design contracts written by the architect agent before implementation. Code is not
changed by these files. Cross-check done by grep over the five files (see "(unverified)" marks).

## 1. Contracts

| file | stages | systems / dirs defined | new `Simulation` commands |
|---|---|---|---|
| `items-inventory.md` | E10 | `sim/items` (`ItemSystem`: item schema, stacks, storage filter/priority, per-colonist inventory/equipment), Ledger conservation | `set_storage_filter(zone_id, categories)`, `set_storage_priority(zone_id, prio 0..3)`, optional `equip_item(colonist_id, item_id)`, `drop_inventory(colonist_id)` |
| `recipes-buildings.md` | E12-E14 | `data/recipes.json`, `data/buildings.json` (`recipes` list), blueprints/construction, production orders, power/logistics stubs; `sim/buildings` | blueprint place/cancel and production-order commands (names in section 3-4, (unverified)) |
| `colonists-needs-jobs.md` | E15-E16 | `data/needs.json`, `data/skills.json`, health/injuries, sleep/food jobs, work priorities; `sim/colonists`, `sim/jobs` | `set_work_priority(colonist_id, job_type, prio) -> bool`, `get_work_priority(colonist_id, job_type) -> int` |
| `combat-weapons.md` (may be unfinished) | E17 | `data/weapons.json`, `data/armor.json`, hit/damage formula, drafting, ammo turrets, `data/enemies.json`; `sim/threats`, `sim/colonists` | `draft(colonist_id, on)`, `order_move(colonist_id, cell)`, `order_attack(colonist_id, enemy_id)`, `equip(colonist_id, id)` |
| `research-events-save.md` | E18-E20 | `sim/research/` (`ResearchSystem`, `data/research.json`), `data/events.json` deck, `sim/story/journal.gd`, `sim/save/save_system.gd` (`to_dict`/`from_dict` per system) | `set_research(node_id) -> String`; `can_place_building()` returns a reason string; save API is static: `SaveSystem.serialize/deserialize/state_hash` |

## 2. Bus signals proposed (existing ones in `autoload/event_bus.gd` are not repeated unless a contract touches them)

| signal | args | defined in | status |
|---|---|---|---|
| `item_moved` | item_id, count, from_cell, to_cell | items-inventory | new |
| `item_produced` | item_id, count, source: String | items-inventory | new |
| `item_consumed` | item_id, count, sink: String | items-inventory | new |
| `inventory_changed` | colonist_id | items-inventory | new |
| `equipment_changed` | colonist_id, slot, item_id | items-inventory | new; combat equip should reuse it (no own equip signal seen) |
| `storage_filter_changed` | zone_id, categories | items-inventory | new |
| `storage_priority_changed` | zone_id, priority | items-inventory | new |
| `building_buffer_changed` | building_id | items-inventory | new |
| `blueprint_placed` | blueprint_id | recipes-buildings | new |
| `blueprint_cancelled` | blueprint_id | recipes-buildings | new |
| `building_completed` | building_id | recipes-buildings | new; overlaps `building_placed` (open Q2) |
| `building_deconstructed` | building_id | recipes-buildings | new |
| `building_placed/destroyed/broken/repaired` | building_id | recipes-buildings (mentions) | already in event_bus.gd |
| `colonist_died` | colonist_id | colonists-needs-jobs | already in event_bus.gd, reuse unchanged (cause in `Colonist.death_cause`) |
| `colonist_injured` | colonist_id, injury_type, severity | colonists-needs-jobs | new; also referenced by combat-weapons |
| `colonist_treated` | colonist_id, injury_type, medic_id | colonists-needs-jobs | new |
| `colonist_drafted` | colonist_id, drafted | combat-weapons | new |
| `turret_out_of_ammo` | building_id | combat-weapons | new |
| `shot_fired` | shooter_kind, shooter_id, from_cell, to_cell, hit, weapon_id | combat-weapons | new |
| `enemy_damaged` | enemy_id, amount, hp_after | combat-weapons | new |
| `research_completed` | node_id | research-events-save | new |
| `journal_entry` | entry: Dictionary | research-events-save | new |
| `game_saved` / `game_loaded` | slot | research-events-save | new; emitted by view layer (I/O), not by `sim/` |
| `story_event` | event_id, text | research-events-save (mentions) | already in event_bus.gd; contract wants text out of code (Russian baked in today) |

No exact duplicates or name collisions between the contracts were found by grep. Real risks:
`building_placed` vs `building_completed` (semantic overlap), `equipment_changed` (items) vs
combat `equip` flow (must emit the same signal), `colonist_died` args unchanged.

## 3. Inconsistencies / things to resolve (max 10)

- `recipe` vs `recipes`: recipes-buildings migrates building def field `recipe` -> `recipes` (list). Any code, test or other contract still saying `recipe` is stale; Colonists/combat docs do not use it.
- Skill ids: colonists-needs-jobs `skills.json` has mining, construction, crafting, smelting, cooking, medicine, shooting, melee, plants. recipes-buildings `skill` enum lists mining/construction/crafting/smelting/cooking/medicine/none: no `plants`, `shooting`, `melee` (fine) but `none` is not a skill in skills.json. combat-weapons `skill` is melee/shooting (consistent).
- Storage priority: items-inventory uses int enum `low=0 normal=1 high=2 critical=3`; its own open Q7 asks "4 levels vs per-zone integer". Work priority in colonists is a separate scale (per colonist/job type); do not share the name `priority` in UI/save keys.
- Equipment: items-inventory puts equipment in `Colonist.inventory.equipment`; combat-weapons has its own `equip()` (queued EquipJob) and `equip_item` exists in items: two commands for one action. Pick one.
- Weapons/armor data: items-inventory says items have `category`/`slot` `weapon|armor`; combat adds separate `weapons.json` / `armor.json` keyed by id. Need a rule: item id == weapon id, or explicit link field.
- `order_attack`: combat text shows a signature change inside the doc itself (target_kind removed); final is `order_attack(colonist_id, enemy_id)`. The `shot_fired` signal still carries `shooter_kind: int`.
- Injury path: combat calls `sim.colonists.injure(...)` and signal `colonist_injured`; colonists contract owns the health model. Combat "downed state out of scope: hp <= 0 = death" conflicts with colonists' injury/treatment model unless hp is derived from injuries.
- Ledger reasons: recipes-buildings adds new destroy reason `construction`; items-inventory adds `item_produced/consumed` with free-form `source/sink` strings. Reason vocabularies are not unified.
- Save: research-events-save requires `to_dict/from_dict` per system and ids-only data; other contracts do not list their new state (inventories, storage zone settings, blueprints, production orders, injuries, work priorities, drafted flag, turret ammo). Each must be added to the save list.
- Events: `Storyteller.PREDICATES` and journal live in `sim/storyteller` + `sim/story`; colonists' Mood stub listens to `story_event`, which research-events-save wants to reshape (text moved to data). Keep signal args stable.

## 4. Reading order for a new agent

1. `CLAUDE.md`, `PROGRESS.md`, `DECISIONS.md`, `autoload/event_bus.gd`.
2. `items-inventory.md` (E10): foundation for items, storage, inventory, Ledger.
3. `recipes-buildings.md` (E12-E14): uses items; adds `recipes`, blueprints, orders.
4. `colonists-needs-jobs.md` (E15-E16): health, skills, work priorities.
5. `combat-weapons.md` (E17): depends on items (equipment) and colonists (injuries).
6. `research-events-save.md` (E18-E20): last, because save must cover state from all earlier contracts.
7. Then resolve the section 3 list with the orchestrator before coding the stage.
