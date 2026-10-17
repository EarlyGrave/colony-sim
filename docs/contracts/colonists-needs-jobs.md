# Contract: colonists, needs, health, skills, work priorities (E15-E16)

Status: design contract, no code yet. Architecture rules from `CLAUDE.md` apply: `sim/` is `RefCounted` only,
all randomness via `sim.rng`, all numbers in `data/*.json` loaded by `Defs`, player commands only through
`Simulation` methods, cross-system events through `autoload/event_bus.gd`.

Current state (checked in code): `Colonist` has `hp`, `max_hp`, `alive`, `hidden`, `sick_until`, `engineer`, `job`,
`carry_item/carry_count`. `ColonistSystem.kill()` exists and emits `colonist_died(colonist_id)`. `JobSystem`
asks providers (`_find_repair/_operate/_haul/_mine`) sorted by the global number in `data/jobs.json`
(`flee` 100, `repair` 60, `operate` 50, `haul` 40, `mine` 30); reservations are string keys in `JobSystem.reserved`.
Sickness (`sick_until`) is set by the storyteller and stays as is.

## 1. Needs (`data/needs.json`)

New file, loaded by `Defs` as `defs.needs`. Needs are stored on the colonist as
`Colonist.needs: Dictionary` (`need_id -> float`, value in `0..max`, `max` = fully satisfied).
`ColonistSystem.tick()` decays them (before `jobs.tick_colonist`). Decay is deterministic (no rng).

```json
{
  "hunger": {
    "max": 100.0,
    "decay_per_tick": 0.0042,
    "thresholds": [
      {"name": "fed",      "below": 100.0, "work_speed_mult": 1.0},
      {"name": "hungry",   "below": 40.0,  "seek_job": "eat", "work_speed_mult": 0.9, "mood": -5},
      {"name": "starving", "below": 15.0,  "critical": true, "work_speed_mult": 0.6, "mood": -20},
      {"name": "famished", "below": 0.01,  "damage_per_tick": 0.02, "death": true}
    ]
  },
  "rest": {
    "max": 100.0,
    "decay_per_tick": 0.0025,
    "thresholds": [
      {"name": "rested",    "below": 100.0, "work_speed_mult": 1.0},
      {"name": "tired",     "below": 35.0,  "seek_job": "sleep", "work_speed_mult": 0.85, "mood": -5},
      {"name": "exhausted", "below": 12.0,  "critical": true, "work_speed_mult": 0.5, "mood": -15},
      {"name": "collapse",  "below": 0.01,  "faint": {"ticks": 120}}
    ]
  },
  "health": {
    "max": 100.0,
    "derived": true,
    "thresholds": [
      {"name": "healthy", "below": 100.0, "work_speed_mult": 1.0},
      {"name": "hurt",    "below": 60.0,  "work_speed_mult": 0.8, "mood": -5},
      {"name": "crippled","below": 25.0,  "critical": true, "work_speed_mult": 0.5, "seek_help": true},
      {"name": "dead",    "below": 0.01,  "death": true}
    ]
  }
}
```

Rules:
- Thresholds are listed from "best" to "worst"; the active level is the LAST one whose `below` is greater than the
  current value (i.e. the worst matching). Effects (`work_speed_mult`, `mood`) of the active level of each need are
  combined: `work_speed_mult` multiplies, `mood` adds.
- `seek_job`: job type the colonist asks for when this level is active (see section 3). `critical: true` makes that job
  override all work priorities (section 5). `faint: {ticks}`: colonist gets a forced idle job for N ticks (`Colonist.faint_until`),
  like `sick_until`. `death: true` calls `ColonistSystem.kill(c)`. `damage_per_tick` reduces `hp` (starvation).
- `health` is derived: `health = hp / max_hp * 100` (not decayed, no `decay_per_tick`). Keeps `Colonist.hp` as the single truth.
- All thresholds/numbers are placeholders for balance; the 4.2e-3 hunger decay is about 100 -> 0 in 24000 ticks (40 days at 600 ticks/day,
  tune in `balance_report`).

### Mood (stub only)
`Colonist.mood: float` (0..100, start 50), moved only by `mood` fields of active need levels (towards a target
`50 + sum(mood)` with smoothing) and by `mood_delta` payloads of storyteller events (new optional field in `data/events.json`).
It has NO gameplay effect yet: no breakdowns, no work-speed link. Out of scope per `CLAUDE.md`.
Plug-in point for later: a new `sim/mood/MoodSystem` (RefCounted, `sim.mood`) that owns `mood` and "thoughts", reads
`colonist.needs` and listens to bus signals (`colonist_injured`, `colonist_died`, `story_event`, `batch_refined`...),
and ticks AFTER colonists in the tick order (colonists -> mood -> threats -> contamination -> storyteller).
Breakdowns would then be a job type injected through `JobSystem` (like `flee`), not a change to `Colonist`.

## 2. Health: injuries, treatment, death

`Colonist.injuries: Array[Dictionary]`, each:
```json
{"id": 7, "type": "bleeding", "severity": 12.0, "tick": 4210, "treated": false}
```
`id` is allocated by `ColonistSystem._next_injury_id` (deterministic counter). `Colonist.hp` stays the single hit-point value;
injury `severity` is the damage "still owed" by that wound.

`data/injuries.json` (new, `defs.injuries`):
```json
{
  "bleeding": {"damage_per_tick": 0.03, "stops_when_treated": true, "treat_with": ["bandage"], "treat_ticks": 60, "heal_hp": 4},
  "bruise":   {"damage_per_tick": 0.0,  "natural_heal_ticks": 1800, "treat_with": ["herbal_medicine"], "treat_ticks": 40, "heal_hp": 2}
}
```
- `bleeding`: each tick `hp -= damage_per_tick` until treated; untreated bleeding can kill (via `hp <= 0` -> `kill`).
- `bruise`: no tick damage, lowers `work_speed_mult` (via the `health` need level), disappears after `natural_heal_ticks`
  or faster when treated.
- Treatment: the `tend` job (section 3) is done by a colonist with medicine skill (any colonist if priority > 0). It consumes 1 `bandage`
  (bleeding) or 1 `herbal_medicine` (bruise) from storage/inventory, takes `treat_ticks / skill_speed_mult`, sets `treated = true`,
  removes the wound's ongoing damage and adds `heal_hp`. Medicine skill raises `success_chance` (see section 4); a failed roll
  (`sim.rng`) wastes the consumable and retries.
- Sources of injuries: `ThreatSystem` (enemy hits) calls `sim.colonists.injure(c, type, severity)`; that is the only entry point.
  Death: when `hp <= 0` or a need's `death: true` level is active -> `ColonistSystem.kill(c)` (existing).
- Items `bandage` and `herbal_medicine` are new entries in `data/items.json` (also see economy/crafting contracts; `herbal_medicine` comes from the `plants` skill chain).

### Bus signals (`autoload/event_bus.gd`)
| signal | status | args |
|---|---|---|
| `colonist_died` | EXISTS, reuse | `(colonist_id: int)`; add no args to keep compatibility, cause is stored in `Colonist.death_cause` |
| `colonist_injured` | NEW | `(colonist_id: int, injury_type: String, severity: float)` |
| `colonist_treated` | NEW | `(colonist_id: int, injury_type: String, medic_id: int)` |

## 3. Sleep, food and new job types

Sleeping zone / beds: new building `bed` in `data/buildings.json` (1 cell, `sleep_spot: true`, reservation key `"bed:<building_id>"`);
optionally a zone type `sleeping` in `data/zones.json` where colonists may sleep on the floor (rest recovery x0.5 rather than bed x1.0).
Sleep recovery per tick lives in `data/needs.json -> rest.recovery_per_tick` (bed) and `floor_recovery_mult`.
Eating: colonist takes a food item from storage, walks to it, eats at the spot (or at a `table` later); food values in
`data/items.json` field `"nutrition"`: `berries` 15, `meal_simple` 40, `meal_good` 60 (one stack unit per eat). Prefers
the highest nutrition at or below the missing amount, then nearest.

Job types to add to `data/jobs.json` (global tiebreak number, higher wins within the same colonist priority; need-driven jobs sit above):
```json
{
  "flee": 100, "eat": 95, "sleep": 90, "tend": 70,
  "repair": 60, "operate": 50, "cook": 48, "haul": 40,
  "harvest": 38, "sow": 36, "mine": 30
}
```
| job | provider | reservation key | skill | notes |
|---|---|---|---|---|
| `eat` | `_find_eat` | `food:<cell>` | - | active when hunger level has `seek_job == "eat"`; no food -> `idle_until` retry, mood penalty only |
| `sleep` | `_find_sleep` | `bed:<id>` or `sleep:<cell>` | - | active when rest level has `seek_job == "sleep"`; interrupted only by flee/alarm |
| `tend` | `_find_tend` | `injury:<colonist_id>:<injury_id>` | medicine | patient may be self only if nobody else; needs consumable |
| `sow` | `_find_sow` | `plot:<cell>` | plants | on a `farm` zone cell (new zone type), consumes seed item |
| `harvest` | `_find_harvest` | `plot:<cell>` | plants | grown plant -> `berries`/ingredients, hauled by normal `haul` |
| `cook` | `_find_cook` | `building:<id>` (like `operate`) | cooking | a building with `recipes` in `data/recipes.json` category `food` (reuse recipe/building machinery, do not write a second one) |

New job classes follow the pattern of `mine_job.gd`/`operate_job.gd` (`extends Job`, `tick(c, sim) -> Status`). Plant growth is a separate
small module later (`sim/plants`) or part of `BuildingSystem`; open question 3.

## 4. Skills (`data/skills.json`)

`Colonist.skills: Dictionary` = `skill_id -> {"level": int, "xp": float}` (all 0 at start, a few random starting levels
chosen with `sim.rng` in `ColonistSystem.spawn`).

```json
{
  "_comment": "xp needed to reach level N+1 is xp_curve[N]; max level = xp_curve.size()",
  "xp_curve": [100, 250, 450, 700, 1000, 1400, 1900, 2500, 3200, 4000],
  "speed_mult_per_level": 0.06,
  "success_bonus_per_level": 0.03,
  "skills": {
    "mining":       {"jobs": ["mine"],             "xp_per_work_tick": 1.0},
    "construction": {"jobs": ["build", "repair"],  "xp_per_work_tick": 1.0},
    "crafting":     {"jobs": ["craft"],            "xp_per_work_tick": 1.0},
    "smelting":     {"jobs": ["operate"],          "xp_per_work_tick": 1.0},
    "shooting":     {"jobs": [],                   "xp_per_work_tick": 0.5, "xp_per_shot": 4.0},
    "melee":        {"jobs": [],                   "xp_per_work_tick": 0.5, "xp_per_hit": 6.0},
    "medicine":     {"jobs": ["tend"],             "xp_per_work_tick": 1.5},
    "cooking":      {"jobs": ["cook"],             "xp_per_work_tick": 1.0},
    "plants":       {"jobs": ["sow", "harvest"],   "xp_per_work_tick": 1.0}
  }
}
```
- Speed: `effective_work_ticks = base_work_ticks / (1 + level * speed_mult_per_level) / need_work_speed_mult`. Applied where
  jobs count work ticks (`mining.work_ticks`, `repair.work_ticks`, recipe `ticks`).
- XP: every tick a job spends actually working (not walking) adds `xp_per_work_tick` to the job's skill; level up when xp >= `xp_curve[level]`.
- `success_chance` (note): jobs with a failure outcome (`tend`, later `cook` quality, `sow`) use
  `clamp(base_success + level * success_bonus_per_level, 0.05, 0.98)`, `base_success` in the job's own data (`data/balance.json` or
  the recipe), rolled with `sim.rng`. Mining/hauling have no failure roll.
- `engineer` flag is kept for the raid rule; later it can be derived from `construction >= N`.

## 5. Work priorities

`ColonistSystem.work_priority: Dictionary` = `colonist_id -> {job_type: int}` where `0` = never, `1` = highest ... `4` = lowest
(default `3` for every job type except `flee`, `eat`, `sleep`, which are not configurable). Defaults per job in `data/jobs.json`
(new optional field `default_priority`; fallback 3). Dead colonists' entries are dropped.

Command (the only write path; view never pokes the table):
```gdscript
func set_work_priority(colonist_id: int, job_type: String, prio: int) -> bool  # in Simulation; false if invalid id/type/prio
func get_work_priority(colonist_id: int, job_type: String) -> int
```
It forwards to `sim.colonists`. Emits `EventBus.work_priority_changed(colonist_id, job_type, prio)` (NEW) for the UI.

How `JobSystem.assign(c)` consults it (replaces the single sorted provider list):
1. `flee` on alarm: unchanged, evaluated first in `tick_colonist`, always wins (also over critical needs, like now; hidden colonists stay hidden).
2. Sick / fainted: unchanged (`sick_until`, `faint_until` => no new job).
3. Critical needs: if any need's active level has `critical: true` and a `seek_job`, that provider is asked first, ignoring the table
   (including `0 = never` and an active job is interrupted at the next job boundary; a non-critical `hungry` level does NOT interrupt, only
   makes `eat` a normal-priority candidate with priority 1).
4. Carried item delivery: unchanged (`_deliver_carried`).
5. Work givers: group providers by colonist priority `1..4` (skip `0`), ask groups in ascending number; inside a group order by the
   global number from `data/jobs.json` (descending), then nearest candidate wins (existing behaviour). Reservations stay string keys, one
   `reserved` dictionary; the `_free(c, key)` check is unchanged.
6. `eat` / `sleep` (non-critical `seek_job`) enter the table as virtual job types with fixed priority 1 for that colonist.
Determinism: iterate colonists in `list` order, job types in sorted order of the data file keys (sort explicitly, JSON dictionary order is not a contract).

## 6. Inventory hook
Carry weight limit and equipment slots (`weapon`, `armor`, ...) are specified in `docs/contracts/items-inventory.md`. This contract
only assumes `Colonist.carry_item/carry_count` stay valid until that contract is implemented; medic jobs take their consumable
from storage via `ItemSystem`, not from the colonist inventory, in the first version.

## 7. Open questions for the orchestrator
1. Hunger/rest numbers: are 40 days to starve and ~17 days awake acceptable, or should survival pressure be much faster (days, not weeks)?
2. Should prisoners be allowed to starve to death at all, or does the planet's "supply drop" always keep a minimum food income (affects the core dilemma)?
3. Who owns plants/farming: new `sim/plants` module (my recommendation) or a building type `farm_plot` in `BuildingSystem`?
4. Is `colonist_died` allowed to get an extra `cause: String` arg (breaks existing listeners/tests) or do we keep the cause on the colonist?
5. Should `flee` also beat a critical need (current proposal: yes) so that colonists can starve in a shelter during long raids?
6. Do we want skill decay or a per-colonist passion/interest multiplier on xp (RimWorld style)? Not specified, left out.
7. Are work priorities 1-4 with default 3 acceptable on a touch UI, or do we want a simple on/off toggle first (0 vs 3)?
8. Order of implementation: E15 = needs + beds + eat/sleep + mood stub; E16 = skills + injuries/tend + priorities table + farming/cook? Confirm the split.
