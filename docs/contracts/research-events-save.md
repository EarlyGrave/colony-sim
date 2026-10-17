# Contract: research, events deck, journal, save/load (E18-E20)

Status: proposal by the architect agent. Does not change code. Keeps decisions D15
(storyteller fires only when the colony is "whole", one broken link at a time),
single seeded `sim.rng`, JSON data through `Defs`, `sim/` is RefCounted-only, and
all player commands go through `Simulation` methods (replays stay possible).

Current state this builds on: `Storyteller.tick()` rolls `chance` every
`checks_per_day`, `colony_is_whole()` gates it, `_pick_event()` does a weighted
pick, `fire(id)` has a hard-coded `match id` and `_say()` emits
`story_event(event_id, text)` with Russian text baked into code/JSON. This contract
replaces the `match` and the baked text with data + `tr()` keys.

## 1. Research (`data/research.json`, E18)

### Schema
```json
{
  "<node_id>": {
    "name_key": "RESEARCH_<ID>",
    "branch": "metallurgy|mechanics|power|logistics|weapons|medicine|agriculture",
    "tier": 1,
    "cost": { "research_points": 40, "items": { "refined_essence": 0 } },
    "requires": ["<node_id>"],
    "unlocks": { "buildings": [], "recipes": [], "weapons": [] }
  }
}
```
Rules (validated by `Defs` on load, a test fails on violation):
- `tier` is 1..5. `requires` ids must exist, be acyclic, and have lower tier.
- Tier >= 3 MUST have `cost.items.refined_essence > 0` (the core dilemma: progress
  needs refined output, refining contaminates). Tiers 1-2 must not need it.
- `unlocks.buildings` / `recipes` / `weapons` reference ids in `buildings.json`,
  `recipes.json`, weapon defs. Locked defs are hidden from the build menu and
  rejected by `Simulation.can_place_building()` (returns a reason string).
- Balance numbers (points per work tick, table speed) go in `balance.json`
  under `"research"`, not in this file.

### Example (4 nodes)
```json
{
  "basic_smelting": { "name_key": "RESEARCH_BASIC_SMELTING", "branch": "metallurgy", "tier": 1,
    "cost": {"research_points": 30, "items": {}}, "requires": [],
    "unlocks": {"buildings": ["smelter"], "recipes": ["smelt_iron"], "weapons": []} },
  "gearing": { "name_key": "RESEARCH_GEARING", "branch": "mechanics", "tier": 2,
    "cost": {"research_points": 60, "items": {"iron": 10}}, "requires": ["basic_smelting"],
    "unlocks": {"buildings": ["conveyor"], "recipes": [], "weapons": []} },
  "essence_cells": { "name_key": "RESEARCH_ESSENCE_CELLS", "branch": "power", "tier": 3,
    "cost": {"research_points": 120, "items": {"refined_essence": 5}}, "requires": ["gearing"],
    "unlocks": {"buildings": ["essence_generator"], "recipes": [], "weapons": []} },
  "pulse_turret": { "name_key": "RESEARCH_PULSE_TURRET", "branch": "weapons", "tier": 3,
    "cost": {"research_points": 150, "items": {"refined_essence": 8}}, "requires": ["gearing"],
    "unlocks": {"buildings": ["pulse_turret"], "recipes": [], "weapons": ["pulse_rifle"]} }
}
```

### System and API
- New dir `sim/research/`: `ResearchSystem` (RefCounted) with `unlocked: Dictionary`
  (id -> true), `current: String`, `progress: float`, `items_paid: bool`.
- Work happens through a job: `ResearchJob` (work-giver style, like other `*Job`),
  performed at a new building `research_table` (def in `buildings.json`, flag
  `"research": true`). Each work tick adds `balance.research.points_per_work_tick`.
- When a node is selected, its `cost.items` are reserved/consumed from storage at
  start (hauled to the table like recipe inputs); if missing, the job waits (no
  silent failure; HUD shows the missing item).
- Player command: `Simulation.set_research(node_id: String) -> String` returns ""
  on success or a reason key (`RESEARCH_ERR_LOCKED`, `_UNKNOWN`, `_ALREADY_DONE`,
  `_NO_TABLE`). Passing "" clears the current research.
- Query helpers: `sim.research.is_unlocked(id)`, `sim.research.available()`
  (requires met, not done).
- Tick order: research is advanced by the job inside `colonists`/`jobs`; no new
  tick stage. Completion emits `research_completed(node_id)` and a journal entry.

## 2. Events deck (`data/events.json`, E19)

Existing keys `name`, `weight`, `min_day`, `duration_ticks`, `max_cells`, `text`
are migrated: `name`/`text` become `name_key` / `journal_text` (tr keys, no prose
in JSON). `min_day` is kept as sugar for a `min_day` predicate.

### Schema
```json
{
  "<event_id>": {
    "name_key": "EVENT_X_NAME",
    "weight": 3,
    "condition": ["min_day:2", "has_machine"],
    "effect": { "type": "<effect_type>", "...": "type-specific params" },
    "journal_text": "EVENT_X_TEXT",
    "alert": { "severity": "info|notice|warning|critical" }
  }
}
```
- `condition`: list of named predicates, ALL must hold (AND). Format
  `"name"` or `"name:arg"`. Named predicates are registered in
  `Storyteller.PREDICATES` (Callable table), implemented once, tested once. No
  free-form expression strings, so no eval and no parser in sim code. Predicates:
  `min_day:N`, `has_machine`, `healthy_colonists_ge:N`, `has_designated_deposit`,
  `has_free_zone_cell`, `contamination_lt:F`, `contamination_ge:F`,
  `prisoners_lt:N`, `research_unlocked:id`.
- `weight`: float > 0, may be modified by `balance.storyteller` multipliers.
- `effect.type` (typed, validated by `Defs`): `break_building`, `sicken_colonist`,
  `collapse_deposit`, `spawn_deposit`, `add_colonist`, `spawn_items`,
  `damage_building`. Unknown type = load error.
- `alert`: `true` is sugar for `{severity: "warning"}`; `false`/absent = `info`.
- `_eligible()` becomes: all `condition` predicates true AND the effect's own
  `can_apply(sim)` true (replaces the hard-coded `match`).
- One event = one broken link (D15). Rule enforced by `colony_is_whole()` AND by
  schema: every event has at most ONE `effect`. "Good" events (rich vein, supply
  capsule, new prisoner) are also gated by `colony_is_whole()` for simplicity and
  count as `last_event`, so good and bad events do not stack in the same check.
- All randomness inside `effect.apply(sim)` uses `sim.rng`, in a fixed order
  (sorted ids, no unordered iteration).

### Starting events
```json
{
  "machine_breakdown": { "name_key": "EVENT_BREAKDOWN_NAME", "weight": 3,
    "condition": ["min_day:2", "has_machine"],
    "effect": {"type": "break_building", "target": "random_machine"},
    "journal_text": "EVENT_BREAKDOWN_TEXT", "alert": {"severity": "warning"} },
  "rich_vein": { "name_key": "EVENT_RICH_VEIN_NAME", "weight": 2,
    "condition": ["min_day:3"],
    "effect": {"type": "spawn_deposit", "item": "iron", "cells": 4, "max_dist_from_center": 14},
    "journal_text": "EVENT_RICH_VEIN_TEXT", "alert": {"severity": "notice"} },
  "new_prisoner": { "name_key": "EVENT_PRISONER_NAME", "weight": 1.5,
    "condition": ["min_day:4", "prisoners_lt:8"],
    "effect": {"type": "add_colonist", "at": "landing_pod"},
    "journal_text": "EVENT_PRISONER_TEXT", "alert": {"severity": "notice"} },
  "sickness": { "name_key": "EVENT_SICKNESS_NAME", "weight": 3,
    "condition": ["min_day:2", "healthy_colonists_ge:2"],
    "effect": {"type": "sicken_colonist", "duration_ticks": 360},
    "journal_text": "EVENT_SICKNESS_TEXT", "alert": {"severity": "warning"} },
  "lightning": { "name_key": "EVENT_LIGHTNING_NAME", "weight": 3,
    "condition": ["min_day:2", "has_machine"],
    "effect": {"type": "damage_building", "target": "random_machine", "wear": 1000},
    "journal_text": "EVENT_LIGHTNING_TEXT", "alert": {"severity": "warning"} },
  "supply_capsule": { "name_key": "EVENT_CAPSULE_NAME", "weight": 2,
    "condition": ["min_day:3", "has_free_zone_cell"],
    "effect": {"type": "spawn_items", "items": {"food": 6, "iron": 8}, "at": "landing_pod"},
    "journal_text": "EVENT_CAPSULE_TEXT", "alert": {"severity": "notice"} }
}
```
`cave_in` stays as a bad event (effect `collapse_deposit`). `lightning` and
`machine_breakdown` are separate events: lightning = instant destruction-grade wear
with a cause; breakdown = ordinary wear failure. Journal args for text: `{target}`
(building/colonist display key or name), `{count}` etc.

## 3. Journal and alerts (`sim/story/journal.gd`, E19)

- `class_name Journal extends RefCounted`; owned as `sim.journal` (new field in
  `Simulation`, created in `_init_systems()`). New dir `sim/story/` (journal only;
  storyteller stays in `sim/storyteller/`).
- `var entries: Array[Dictionary]` — append-only, never edited or removed
  (a cap for memory: keep last `balance.journal.max_entries`, default 500, drop
  oldest only at the front; save stores what is kept).
- Entry: `{ "tick": int, "kind": String, "text_key": String, "args": Dictionary,
  "severity": int }`. `kind` examples: `event`, `research`, `wave`, `building`,
  `colonist`, `contamination`, `system`. Severity constants:
  `INFO=0, NOTICE=1, WARNING=2, CRITICAL=3`.
- API: `add(kind, text_key, args := {}, severity := INFO) -> Dictionary`
  (stamps `sim.tick`, appends, emits `bus.journal_entry(entry)`);
  `alerts(since_tick := 0) -> Array[Dictionary]` = entries with severity >= WARNING.
- Text is NEVER stored as prose: `text_key` + `args`; the HUD renders
  `tr(entry.text_key).format(entry.args)`. Args must be primitives (int, float,
  String, names as strings), so the entry is JSON-safe for saves.
- HUD reads `sim.journal.entries` and listens to `EventBus.journal_entry` for new
  rows / alert toasts. The view never writes to the journal.
- Sources: Storyteller (events), ResearchSystem (completion), ThreatSystem
  (waves), BuildingSystem (broken). The existing `story_event` signal and the
  `_say()` helper are replaced by `journal.add(...)` (keep `story_event` emitting
  `(event_id, text_key)` for one release to avoid breaking the HUD, then remove).
- Journal does not touch `rng` and does not affect sim state (pure log), so it is
  excluded from the state hash used in determinism tests (it is still saved).

## 4. Save / load (`sim/save/save_system.gd`, E20)

### API
```gdscript
class_name SaveSystem extends RefCounted
const FORMAT_VERSION := 1
static func serialize(sim: Simulation) -> Dictionary
static func deserialize(data: Dictionary, bus: Object, defs: Defs = null) -> Simulation
static func state_hash(sim: Simulation) -> int   # for tests, excludes journal
```
Slot I/O lives in the VIEW layer (`view/save_store.gd`: `user://saves/slot_N.json`,
write via temp file + rename, `FileAccess`), because sim must not touch the file
system. `GameController` calls it and emits `game_saved(slot)` / `game_loaded(slot)`.
On web `user://` is IndexedDB: writes are async-flushed, so call save only between
frames and show "saved" after the bus signal.

### Envelope
```json
{ "format_version": 1, "game_version": "0.x", "saved_at_tick": 12345,
  "seed": 42, "rng_state": "<string>", "tick": 12345, "game_over_reason": "",
  "alarm": false, "rules": {}, "ledger": {}, "map": {}, "items": {},
  "colonists": {}, "jobs": {}, "buildings": {}, "contamination": {},
  "threats": {}, "storyteller": {}, "research": {}, "journal": [] }
```
- `rng_state`: `RandomNumberGenerator.state` is a 64-bit int; JSON numbers lose
  precision above 2^53, so store as a STRING and restore with `int()`; also store
  `seed` and set `rng.seed` first, then `rng.state` (Godot requires this order).
- Defs (`data/*.json`) are NOT saved; only ids. On load, unknown ids fail the load
  with an error (no silent drop). `format_version` mismatch: run `migrate_vN_to_vN+1`
  step functions in order; newer-than-supported version = refuse with a message.

### What must be saved (per system, each exposes `to_dict()` / `from_dict(d)`)
| system | state |
|---|---|
| core | `tick`, `seed`, `rng.state`, `alarm`, `rules`, `game_over_reason`, `ledger` |
| map | size, tile types, deposits (remaining amounts), designations (mine), zones; pathfinder/AStar is REBUILT, not saved |
| items | stacks per cell (id, count), "lost" records |
| colonists | id, name, pos, hp, needs, `sick_until`, alive, current job id, inventory/carried item |
| jobs | active jobs (type, target, progress, params), reservations (string key -> owner id), job id counter |
| buildings | id, def_id, cell, hp/wear, broken, recipe progress, input/output buffers, build progress |
| contamination | level, forecast state/revealed flag, per-cell values if any |
| threats | awakened, wave index, `next_wave_tick`, `wave_active`, enemies (id, type, pos, hp, target) |
| storyteller | `fired` counts, `last_event`, any cooldown timers |
| research | `unlocked`, `current`, `progress`, `items_paid` |
| journal | entries (JSON-safe by construction) |

Rules for `to_dict()`: only ints/floats/strings/bools/arrays/dicts; `Vector2i` as
`[x, y]`; dictionary keys as strings (JSON turns int keys into strings — convert
back in `from_dict`); arrays saved in their live order (order is part of
determinism); object references saved as integer ids and re-linked in a second
pass `from_dict` -> `relink()` (job -> colonist/building, enemy -> target).
Signal connections made by `sim.listen` are re-created by constructors, not saved.

### Autosave and slots
- Autosave once per in-game day: on `EventBus.day_started`, `GameController`
  serializes at the NEXT frame boundary (not inside `step()`), slot `auto`.
- Slots: `auto` (rolling 2: `auto_0`, `auto_1` alternating), `manual_1..manual_3`.
  Quota on web is small: target < 1 MB per save (journal capped, no defs).
- Never autosave when `game_over_reason != ""`. A loaded game starts paused.

### Determinism test (`tests/test_save.gd`)
1. Build sim A (seed S, scenario with colonists, a refinery, a wave pending), run T ticks.
2. `d := SaveSystem.serialize(A)`; round-trip through `JSON.stringify` / `JSON.parse_string`
   (to catch int/float/key-type bugs); `B := SaveSystem.deserialize(d, make_bus())`.
3. `assert state_hash(A) == state_hash(B)` immediately.
4. Run N ticks on both (N covers an event check, a research completion and a wave):
   `assert state_hash(A) == state_hash(B)` at several checkpoints.
5. Also: `rng.state` equal after N ticks; same `journal.entries` text keys.
`state_hash` = `hash()` of a canonical `JSON.stringify(serialize(sim) minus journal, "", true)`
(sorted keys). Add a test that every system's `to_dict(from_dict(x)) == x`.

## 5. Bus signals to add (`autoload/event_bus.gd`)
```gdscript
# --- Research / story / save ---
signal research_completed(node_id: String)
signal journal_entry(entry: Dictionary)
signal game_saved(slot: String)
signal game_loaded(slot: String)
```
Optional later: `research_started(node_id)`, `research_changed(node_id)`.
`game_saved`/`game_loaded` are emitted by the view layer (I/O), not by `sim/`.

## 6. Open questions
1. Should good events (rich vein, capsule, prisoner) also require `colony_is_whole()`,
   or may they fire during a broken link (as relief)? Proposed: gated (simple).
2. Prisoners: are they full colonists with a flag, or a separate role (no work
   until "accepted")? Affects `add_colonist` effect and the prisoners cap.
3. Is `essence_generator` / power a real system in E18, or only an unlock stub?
4. Research item cost: consumed at start (proposed) or gradually per point?
5. Existing `story_event(event_id, text)`: remove now or keep a deprecation window?
6. Localization: where do `tr()` keys live (`translations/*.csv`)? The current
   Russian strings in JSON/code must be moved there in E19.
7. Save size on web IndexedDB quota; need compression (`FileAccess.COMPRESSION_ZSTD`)?
8. Replays: store a command log in the save now (cheap, future-proof) or skip?
9. Cap and truncation policy for the journal vs. "append-only" promise.
