# Contract: combat, weapons, armor, drafting, turrets with ammo (stage E17)

Status: proposal by the architect agent. Numbers marked **(start)** are starting points for `tools/balance_report.gd`, not final balance.
Aligned with `docs/contracts/colonists-needs-jobs.md` (injuries via `sim.colonists.injure`, signal `colonist_injured`) and `docs/contracts/items-inventory.md` (items have `category`/`slot` `weapon|armor`, equipment lives in `Colonist.inventory.equipment`).

## 0. Kept decisions (unchanged)
- Wave strength = f(wave#, refined total, contamination) via `ThreatSystem.wave_strength()` and `data/balance.json` "threat". Waves end on a timer (`wave_duration_ticks`); survivors set `leaving` and retreat.
- Enemies pick targets by `threat_priority` (`priority_weight`, `turret_target_bonus`), re-target every `retarget_ticks`.
- Alarm: colonists hide in shelter (flee override in JobSystem). One-engineer rule is unchanged.
- All randomness through `sim.rng`. All data in JSON through `Defs`. Sim code has no Node/rendering.
- Tick order stays: colonists -> threats -> contamination -> storyteller. Colonist combat resolves inside the colonists step, turret combat inside threats (as today).

## 1. `data/weapons.json`
Loaded by `Defs.weapons` (Dictionary id -> def). Schema:

| field | type | meaning |
|---|---|---|
| `id` | string | key (also the dictionary key) |
| `name` | string | display name |
| `kind` | `"melee"` / `"ranged"` | melee needs adjacency (range 1.5) |
| `damage` | float | base damage per hit before armor |
| `range` | float (cells) | max distance; melee = 1.5 |
| `cooldown_ticks` | int | ticks between attacks |
| `accuracy` | float 0..1 | base hit chance at point blank, skill 0 |
| `stun_ticks` | int | target (enemy) cannot move/attack for N ticks on hit; 0 = none |
| `aoe` | float (cells) | splash radius; 0 = single target; shotgun uses cone/radius 1.0 around target |
| `materials` | `{item_id: n}` | crafting cost |
| `skill` | `"melee"` / `"shooting"` | colonist skill that scales it |
| `sprite` | string | sprite key under `assets/sprites/` |

Starting set **(start)**:

| id | kind | damage | range | cooldown | accuracy | stun | aoe | materials | skill |
|---|---|---|---|---|---|---|---|---|---|
| `knife` | melee | 5 | 1.5 | 8 | 0.80 | 0 | 0 | `{"scrap": 2}` | melee |
| `pipe_club` | melee | 9 | 1.5 | 12 | 0.70 | 0 | 0 | `{"scrap": 4}` | melee |
| `iron_spear` | melee | 12 | 2.0 | 12 | 0.75 | 0 | 0 | `{"iron": 4, "scrap": 2}` | melee |
| `sledgehammer` | melee | 22 | 1.5 | 22 | 0.60 | 12 | 0 | `{"iron": 10}` | melee |
| `makeshift_pistol` | ranged | 8 | 6.0 | 14 | 0.60 | 0 | 0 | `{"scrap": 6, "iron": 2}` | shooting |
| `rifle` | ranged | 14 | 10.0 | 20 | 0.75 | 0 | 0 | `{"iron": 10, "refined_essence": 2}` | shooting |
| `shotgun` | ranged | 18 | 4.5 | 26 | 0.65 | 0 | 1.0 | `{"iron": 8, "refined_essence": 2}` | shooting |

Item ids in `materials` must exist in `data/items.json`; the implementer maps names to the real ids (`scrap`/`iron` are placeholders). Weapons are items (`ItemSystem` stacks of 1, "weapon" category) crafted at a workbench recipe (recipe in `data/buildings.json` or recipes data, one per weapon), stored in zones, and equipped by a hauling-like `EquipJob`. A colonist without a weapon uses fists: damage 2, melee, accuracy 0.7 **(start)**.

## 2. Armor (`data/armor.json`, `Defs.armor`)
Fields: `id`, `name`, `damage_reduction` (flat fraction 0..0.9 applied to incoming damage), `weight` (move-speed penalty, see below), `materials`, `sprite`. One armor slot per colonist.

| id | damage_reduction | weight | materials **(start)** |
|---|---|---|---|
| `cloth_vest` | 0.10 | 0.0 | `{"cloth": 4}` |
| `iron_armor` | 0.30 | 0.15 | `{"iron": 12}` |
| `steel_armor` | 0.50 | 0.25 | `{"steel": 12, "refined_essence": 3}` |

`weight` is a fraction added to the colonist's move ticks (`move_ticks * (1 + weight)`), rounded to int ticks.
Enemy armor (Section 6) uses the same `damage_reduction` semantics.

## 3. Hit and damage formula
All in a pure static helper `sim/combat/combat_math.gd` (`class_name CombatMath`, no state) so it is unit-testable. A new system dir `sim/combat/` holds it plus `CombatSystem` only if needed; otherwise keep inside `colonists` and `threats`.

```
hit_chance = clamp(accuracy_weapon
                   * (0.6 + 0.04 * skill_level)          # skill 0..10 -> 0.6..1.0
                   * range_factor(dist, weapon.range)    # 1.0 at dist<=2, linearly down to 0.5 at dist==range
                   * (1.0 - cover),                      # cover 0 / 0.25 (half cover) / 0.5 (full cover, wall or building between)
                   0.05, 0.95)
roll  = sim.rng.randf()            # only randomness source
hit   = roll < hit_chance
damage = weapon.damage * (0.8 + 0.04 * skill_level)      # damage scales a little with skill
final  = max(1.0, damage * (1.0 - target.damage_reduction))
```
- Melee: `range_factor = 1.0`, no cover.
- Cover: a solid building/wall cell on the Bresenham line between shooter and target (excluding both endpoints) gives 0.5; a cell adjacent to the target with a building gives 0.25. Cheap check, no new data structure.
- Shotgun `aoe`: after a hit roll on the primary target, every enemy/colonist within `aoe` cells of the target takes `final * 0.5` with no second roll. Friendly fire applies to colonists (design risk, see open questions).
- `stun_ticks`: on a hit, enemy `stun_until = tick + stun_ticks`; a stunned enemy skips move and attack.
- Turrets use the same formula with `skill = 5`, `cover = 0`, so turret numbers still live in the building def (`turret` block) and accuracy defaults to 0.85 **(start)** (`accuracy` optional field in the turret block; absent = current behavior of always hitting is kept for old saves/tests via `accuracy: 1.0`).

### Injuries -> health contract
Uses the contract from `docs/contracts/colonists-needs-jobs.md` section 2; no second health model.
- Enemy hit on a colonist: `ThreatSystem` computes `final` (formula above), then calls `sim.colonists.injure(c, type, severity)` (the only entry point). Mapping **(start)**: `final < 8` -> `bruise`, otherwise `bleeding`, `severity = final`; the colonist also loses `final` hp immediately (`Colonist.hp` stays the single truth). The system emits `colonist_injured`; `hp <= 0` -> `ColonistSystem.kill` -> `colonist_died`.
- Downed state is out of scope for E17: hp <= 0 = death, as today.
- A drafted colonist hit by an enemy does not auto-flee; an undrafted one follows the existing `flee` rule.
- Weapon/armor item ids come from `Colonist.inventory.equipment.weapon` / `.armor` (items-inventory contract); `Colonist.weapon_id`/`armor_id` below are accessors, not new storage.

## 4. Drafting
New `Colonist` fields: `drafted: bool`, `order: {kind: "none"/"move"/"attack", cell: Vector2i, target_kind: int, target_id: int}`, `attack_cd: int`; weapon and armor are read from `inventory.equipment`.

Player commands (on `Simulation`, per hard rule "commands go through Simulation"):
```gdscript
func draft(colonist_id: int, on: bool) -> bool                  # false if colonist missing/dead
func order_move(colonist_id: int, cell: Vector2i) -> bool       # false if not drafted or cell unreachable (MapGrid component check)
func order_attack(colonist_id: int, target_kind: int, target_id: int) -> bool   # target_kind = Enemy.Target-style enum; enemy id from ThreatSystem.enemies
func equip(colonist_id: int, item_id_or_weapon_id: String) -> bool              # weapon/armor, takes it from a stockpile (queued EquipJob) 
```
(The task text says `order_attack(colonist_id, target)`; `target` is the enemy id `int` — the system only attacks enemies in E17. Keep the signature `order_attack(colonist_id: int, enemy_id: int)` to stay simple.) Final signature: `order_attack(colonist_id: int, enemy_id: int) -> bool`.

Rules:
0. Priority: `draft` sits above `flee` (100) in the work-giver order; a drafted colonist never reaches the job selector.
1. Drafting cancels the current job (release its reservations through JobSystem) and sets `drafted = true`. Un-drafting returns the colonist to normal job selection.
2. Drafted colonists are skipped by the job work-giver; they never haul, mine or build.
3. Idle drafted colonist: auto-attacks the nearest enemy inside `weapon.range` (ranged) or adjacent (melee) without moving. With an `attack` order it paths to range and then attacks until target dead/gone, then reverts to `none`.
4. `move` order uses `Pathfinder`; arrival clears the order.
5. Flee interaction: alarm flee override does NOT apply to drafted colonists (the player is in control). Alarm and drafted are independent flags; `set_alarm(true)` while some colonists are drafted leaves them drafted. Undrafted colonists hide as today. If the colonist is drafted at the moment of `colonist_died`, the order is dropped with the colonist.
6. Needs (food, sleep) from the needs contract still tick while drafted; a drafted colonist does not eat or sleep by itself. Auto-undraft is **not** done in E17 (open question).
7. Wave end with drafted colonists: nothing special.

## 5. Turrets with ammo
Building def extension (`data/buildings.json`, `turret` block gets ammo fields; building-level keys, next to `turret`):
```json
"turret": {
  "name": "Турель", "size": [1,1], "color": "#5f9ea0", "max_hp": 120,
  "cost": {"refined_essence": 10}, "buildable": true,
  "turret": {"range": 6.5, "damage": 9, "cooldown_ticks": 8, "accuracy": 0.85,
             "ammo_item": "ammo_basic", "ammo_capacity": 40, "ammo_per_shot": 1},
  "wear_per_shot": 1.2, "threat_priority": 1
},
"heavy_turret": {
  "name": "Тяжёлая турель", "size": [2,2], "color": "#2f6f7f", "max_hp": 260,
  "cost": {"refined_essence": 25, "iron": 20}, "buildable": true,
  "turret": {"range": 8.5, "damage": 24, "cooldown_ticks": 16, "accuracy": 0.8,
             "ammo_item": "ammo_heavy", "ammo_capacity": 30, "ammo_per_shot": 2},
  "wear_per_shot": 2.0, "threat_priority": 2
}
```
(all numbers **(start)**). Items to add to `data/items.json`: `ammo_basic`, `ammo_heavy`, craftable at a workbench from `iron` (+ `refined_essence` for heavy).

Building runtime state: `Building.ammo: int` (starts 0 when built, so a new turret is useless until fed — creates a logistics cost for the "refining is dangerous" loop). `Building.buffers` already spill on destroy; ammo spills as `ammo_item` stacks (`ItemSystem.drop`).

Firing: in `_tick_turrets()`, a turret with `ammo < ammo_per_shot` does not fire; on the tick it first runs dry it emits `turret_out_of_ammo(building_id)` once (flag `out_of_ammo_notified`, reset on reload).

Reload, two paths (no new magic):
1. **Hauling job:** new `ReloadTurretJob` (work-giver in `sim/jobs`): finds a turret with `ammo <= ammo_capacity / 2` and a reachable stack of its `ammo_item` in a zone; reserves both by string key (`"turret:<id>"`, `"item:<cell>"`), carries up to the missing amount, adds to `Building.ammo`. Priority below `flee`/`repair` of the one-engineer rule, above general hauling during a wave; defined in `data/job_priorities` like the other jobs.
2. **Automation:** a conveyor/inserter delivering `ammo_item` into a turret adds to `Building.ammo` through the same `Building.accept_item()` path other machines use for buffers. If the automation stage is not in yet, only path 1 exists.

Colonist firearms do **not** consume ammo in E17 (recorded decision: avoids a second logistics loop; revisit in a later stage). Only turrets are ammo-fed.

## 6. Enemies (`data/enemies.json`)
Existing fields stay: `name, color, max_hp, move_ticks, damage, attack_cooldown_ticks, attack_range, threat_cost, min_wave`.
New optional fields (absent = default in parentheses): `armor` (0.0, same meaning as `damage_reduction`), `speed` (alias kept for the view; `move_ticks` remains the sim value — **do not add a second speed field**, see open questions), `attack_damage` (falls back to existing `damage`), `prefers_buildings` (false), `spawn_weight` (1.0), `stun_resist` (0.0 .. 1.0, scales `stun_ticks`).

`prefers_buildings: true` makes `_choose_target` add `+building_bonus` (balance key, 500 **(start)**) to every building candidate and ignore colonists unless one is within 2 cells; it still respects `threat_priority` among buildings. Damage to buildings goes through the existing building damage/destroy path.

New types **(start)**:
```json
"skitter":   {"name": "Шуршун",   "color": "#e0b040", "max_hp": 14,  "move_ticks": 2, "damage": 3,  "attack_cooldown_ticks": 8,  "attack_range": 1.5, "threat_cost": 0.6, "armor": 0.0,  "spawn_weight": 3.0},
"carapace":  {"name": "Панцирник", "color": "#6b5a7a", "max_hp": 160, "move_ticks": 9, "damage": 14, "attack_cooldown_ticks": 16, "attack_range": 1.5, "threat_cost": 4.0, "armor": 0.45, "stun_resist": 0.5, "min_wave": 4, "spawn_weight": 1.0},
"gnawer":    {"name": "Грызун",   "color": "#8a6a2a", "max_hp": 60,  "move_ticks": 5, "damage": 5,  "attack_cooldown_ticks": 8,  "attack_range": 1.5, "attack_damage": 5, "prefers_buildings": true, "building_damage_mult": 3.0, "threat_cost": 2.5, "armor": 0.1, "min_wave": 5, "spawn_weight": 1.0}
```
Existing `crawler` (weight 2.0) and `brute` (weight 1.0) get `spawn_weight` too. Roles: skitter = fast weak swarm, carapace = slow armored (low-damage weapons like pistol/knife are almost useless: `final = max(1, ...)`), gnawer = building destroyer.

Wave composition: `start_wave()` spends the wave strength budget as today (`threat_cost`), but picks the next type by weighted roll over defs with `min_wave <= wave_index` and `threat_cost <= remaining budget`, probability `spawn_weight / sum`. All rolls via `sim.rng`; iterate def ids in **sorted order** for determinism. Optional per-wave bias in `balance.json` threat: `"type_bias_per_wave": {"gnawer": 0.1}` is deferred.

Enemy damage to colonists uses the armor formula in Section 3 (`target.armor` = equipped armor's `damage_reduction`). Player damage on enemies applies enemy `armor` the same way. `ThreatSystem.damage_enemy(e, amount)` currently takes an already-final number: keep it as the post-armor sink, add `ThreatSystem.hit_enemy(e, raw_damage, source)` that applies armor, stun, emits `enemy_damaged`, then calls `damage_enemy`.

## 7. Bus signals to add (`autoload/event_bus.gd`)
Existing and reused: `wave_started, wave_ended, enemy_killed, colonist_died, building_destroyed, alarm_changed`.
```gdscript
signal colonist_drafted(colonist_id: int, drafted: bool)
signal turret_out_of_ammo(building_id: int)
signal shot_fired(shooter_kind: int, shooter_id: int, from_cell: Vector2i, to_cell: Vector2i, hit: bool, weapon_id: String)
signal enemy_damaged(enemy_id: int, amount: float, hp_after: float)
```
Optional (view convenience, low priority): `turret_reloaded(building_id: int)`. `ThreatSystem.shots` (existing array for the view) can be derived from `shot_fired` later; do not remove it in E17.

## 8. Tests required (acceptance)
- `test_combat_math`: hit chance clamps, cover and distance monotonic, damage armor floor of 1, shotgun aoe.
- `test_drafting`: draft cancels job and releases reservations; drafted ignores jobs; order_move/attack return codes; alarm does not undraft.
- `test_turret_ammo`: new turret has 0 ammo and does not fire; reload job fills it; out_of_ammo emitted once; destroy spills ammo.
- `test_enemy_types`: carapace takes reduced damage; gnawer prefers buildings; weighted composition deterministic for the same seed (use `sim.rng`).
- Existing threat tests keep passing: use `peaceful_defs()` where creatures are not the point; old `turret` tests need `ammo` seeded in `tests/scenario.gd`.

## 9. Open questions
1. Friendly fire from shotgun aoe on colonists: keep (risk, interesting) or off in E17?
2. Auto-undraft when the wave ends or when needs hit critical (starving drafted colonist)?
3. `speed` vs `move_ticks`: we keep `move_ticks` as sim truth; confirm the view does not need a separate `speed`.
4. Weapon crafting: one workbench recipe per weapon, or a single "armory" building? Depends on the buildings/recipes stage.
5. Downed state and bleeding: needs the colonists-needs-jobs contract to define it; E17 assumes hp <= 0 = death.
6. Should colonist firearms use ammo in a later stage (then `ammo_item` field on weapons)?
7. Are the item ids `scrap`, `iron`, `steel`, `cloth` real? Materials tables above use placeholders.
8. Turret accuracy < 1.0 changes existing balance_report outcomes; re-run `tools/balance_report.gd` after the change.
