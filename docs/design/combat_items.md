# Combat & equipment design (Fable lead, 2026-10-19; numbers = direction only)
Source: `docs/design/owner_notes_2026-10-19.md`. Base: `sim/combat/combat_system.gd`, `sim/health/health_system.gd`, `data/weapons.json`, `data/quality.json`.
Everything below stays deterministic (`sim.rng` only, affix rolls use a child RNG seeded from `sim.rng.randi()`) and data-driven.

## 1. Hit roll — decision: keep accuracy, drop evasion as a stat
Owner asked "is accuracy vs evasion really needed?". Answer: **no separate evasion stat.** Enemies already dodge by position (C3 telegraphs), inmates by cover-free skill-based accuracy. Two opposing stats double the tuning surface and are invisible on a phone. Keep ONE number per attacker:
`p_hit = clamp(hit_base + hit_per_skill*lvl + acc_weapon + acc_affix - range_penalty*max(0,dist-1), hit_min, hit_max)`, then `* manipulation` (exists). Enemies keep auto-hit (telegraph dodge). Evasion returns later only as a *utility affix* `dodge` (flat p subtraction, cap 0.25) — slot reserved in the schema, not implemented in wave 1.

## 2. Damage pipeline (one function, `CombatSystem.resolve_hit`, ~15 ops, no loops)
Input: attacker `AttackStats` (cached), defender `DefenseStats` (cached), `kind` = "phys"|"energy".
```
raw   = dmg_base * crit_mult(if rng < crit_chance)            # crit_mult default 1.5
armor = max(0, def.armor[kind] * (1 - att.pen_pct[kind]))      # pen = % of rating ignored
after_flat = max(0, raw - max(0, def.flat[kind] - att.flat_pen[kind]))  # flat BEFORE percent
dealt = max(1, after_flat * 100 / (100 + armor))               # LoL curve: 100 -> -50%, 200 -> -66%
```
Decisions: **penetration is % of rating** (owner's choice; stacks sanely with the curve). **No true damage**: it bypasses both the curve and flat plates and makes armor affixes worthless at high tiers. Instead "armour-piercing rounds" give `pen_pct` and, for the flat plate counter, `flat_pen` (reduces the enemy's/defender's flat reduction, min 0). Min 1 damage on every hit (owner). Enemies get the same two rating pairs in `data/enemies.json` (`armor: {phys, energy}`, `flat: {...}`, default 0) so the formula is one code path for both sides. Weapon `damage_kind` ("phys"/"energy") picks the armour pair; health `kind` ("cut", "bullet", "burn"…) stays separate (injury type only).

## 3. Equipment slots (data-driven, `data/equipment.json`)
```json
{"slots": {"head": {"name":"Head"}, "hands": {"name":"Hands"}, "legs": {"name":"Legs"},
           "torso_outer": {"name":"Armour"}, "torso_inner": {"name":"Underlay"}, "weapon": {"name":"Weapon"}},
 "rarity": {"common":{"affixes":0,"color":"#c0c0c8"}, "uncommon":{"affixes":1,"color":"#5fd36b"},
            "rare":{"affixes":2,"color":"#4a90ff"}, "epic":{"affixes":3,"color":"#b35cff"}, "legendary":{"affixes":4,"color":"#ffb347"}},
 "rarity_weights": {"common":70,"uncommon":20,"rare":7,"epic":2.5,"legendary":0.5},
 "upgrade_slots": {"common":0,"uncommon":1,"rare":1,"epic":2,"legendary":2},
 "durability": {"default_max":100, "loss_per_hit_taken":0.2, "loss_per_attack":0.1, "zero_stat_mult":0.5, "value_mult_at_zero":0.1}}
```
A new slot = one JSON entry + a base item with `"slot": "<id>"`; code never names slots. Weapon is a slot too, so one module handles everything. Durability: 0 never destroys, only multiplies the item's *stat contribution* by `zero_stat_mult` (linear from 50% dur) and its trade value — repair is a future crafting job.
Base gear `data/gear.json` (bases; affixless):
```json
{"kevlar_vest": {"name":"Kevlar Vest","slot":"torso_outer","armor":{"phys":40,"energy":5},"flat":{"phys":2,"energy":0},"tags":["armor","body"],"value":30},
 "plasma_blade": {"name":"Plasma Blade","slot":"weapon","kind":"melee","damage":11,"damage_kind":"energy","cooldown_ticks":9,"range":1.5,"skill":"melee","crit_chance":0.08,"crit_mult":1.6,"accuracy":0.05,"tags":["weapon","melee","energy"]},
 "smg": {"name":"SMG","slot":"weapon","kind":"ranged","damage":5,"damage_kind":"phys","cooldown_ticks":4,"range":6,"burst":{"shots":3,"gap_ticks":1},"reload_ticks":30,"magazine":24,"skill":"shooting","accuracy":-0.05,"tags":["weapon","ranged"]}}
```
Melee params: damage, cooldown_ticks, crit_chance, crit_mult, accuracy, damage_kind. Ranged adds range, burst{shots,gap_ticks}, magazine, reload_ticks. New params are added by (a) a JSON key, (b) one line in the stat-sum table (`StatBlock.KEYS`) — nothing else. Existing `weapons.json` entries migrate 1:1 into `gear.json` with `slot:"weapon"` (`weapons.json` keeps `combat`/`abilities` blocks).

## 4. Affixes (`data/affixes.json`), PoE-style, grouped
```json
{"groups": {"offense": ["dmg_pct","crit_chance","pen_pct_phys","pen_pct_energy","accuracy","attack_speed"],
            "defense": ["armor_phys","armor_energy","flat_phys","flat_energy","max_hp"],
            "utility": ["move_speed","dodge","ammo_eff","durability_max"]},
 "affixes": {
  "dmg_pct":   {"name":"%s of Ruin","pos":"suffix","tiers":[[0.05,0.10],[0.10,0.18],[0.18,0.30]],"tags_any":["weapon"]},
  "armor_phys":{"name":"Plated %s","pos":"prefix","tiers":[[5,12],[12,25],[25,45]],"tags_any":["armor"]},
  "flat_phys": {"name":"Padded %s","pos":"prefix","tiers":[[1,1],[2,2],[3,3]],"tags_any":["armor"]}},
 "rules": {"max_prefix":2,"max_suffix":2,"max_per_group":{"offense":2,"defense":2,"utility":1},"tier_by_ilvl":[0,5,10]}}
```
Generation (`AffixRoller.roll(base, rarity, ilvl, rng)`): n = rarity.affixes; candidate list = affixes whose `tags_any` matches the base and whose group/pos caps are not full (iterate keys in sorted order, pick with weighted `rng`); tier = highest tier ≤ ilvl bracket, value uniform in tier range; one affix id per item max. Name = prefix name + base + suffix. Upgrade slots hold `data/upgrades.json` ids (`kevlar_plate: {flat_phys: 3}`, `ap_rounds: {pen_pct_phys: 0.25}`) — same stat keys, same summation.

## 5. Performance: 200+ fully equipped units on a phone (owner's main question)
Verdict: fine, **provided affixes are never iterated per hit.** Design:
- `GearItem` (RefCounted): `id:int, base:String, rarity, ilvl, affixes:Array[[id,value]], upgrades:Array[String], durability:float`, plus a `stats:Dictionary` summed once at creation/upgrade/durability-band change (≤ 6 affixes + 2 upgrades ≈ 10 adds).
- `Colonist.combat.att: PackedFloat64Array(ATT_N)` and `.def: PackedFloat64Array(DEF_N)` (fixed index per stat key, `StatBlock.IDX`): re-summed only on `equip/unequip/upgrade/durability band/skill level/perk change` (events already on the bus) — 6 slots × ~12 keys ≈ 70 adds, happens maybe once a minute per unit.
- Per hit: `resolve_hit` reads ~8 floats from two packed arrays, 1 `rng.randf()` for crit (plus existing hit roll). Cost ≈ 0.3–0.5 µs on desktop, ~3–5 µs in web single-thread on a mid phone (GDScript ≈ 10× slower there). 200 units attacking every ~8 ticks = 25 hits/tick → ≈ 0.1 ms/tick worst case. Per tick with no hits: 0 (no equipment work in `step()`; durability is decremented inside the hit path, band check is an int compare).
- Enemies: same `PackedFloat64Array def` filled at spawn from `def` (+variant). No per-enemy affixes in wave 1.
- Memory: 200 units × 6 GearItems ≈ 1200 RefCounted + 1200 small dicts ≈ < 1 MB. Fine.
- Forbidden: Dictionary stat lookups by string in `resolve_hit`, iterating `affixes` outside the resummer, `perks.mod()` inside the hit path (it loops over learned perks — wave 1 folds `hit_chance/melee_damage/attack_speed/damage_taken` into the cached `att/def` via a `perk_changed` resum; `aimed_shot` flag stays).
Acceptance benchmark (`tools/equip_bench.gd`, asserted by `tests/test_equip_perf.gd`): 250 map, 220 inmates each with 6 legendary items (4 affixes + 2 upgrades), 300 enemies in melee contact, 300 ticks after 100 warm-up, median of 3: `sim.profiling` bucket `combat` avg ≤ 0.6 ms, p95 ≤ 1.5 ms (desktop headless; add to `tests/perf_budget.json` as `"combat"`), and `resum_count` ≤ 220×(1+levelups) over the run. Determinism: two runs same seed → equal `state_hash` and equal `resum_count`.

## 6. Migration from the current system
1. `CombatState.weapon:String` stays as the equipped weapon *base* for one wave; `equipped: Dictionary[slot -> GearItem]` added; `weapon_def(c)` returns `equipped["weapon"].base_def` if present else `weapons.json` entry (both paths green; goldens unchanged because start gear = `prison_shiv` common, 0 affixes → identical numbers).
2. `try_attack`: damage line → `resolve_hit(c.combat.att, target.def, kind)`; `hit_chance` adds `att[ACC]`. Enemy attack (`threat_system.gd:567/941`) → `health.apply_damage(c, resolve_hit(e.att, c.combat.def, e_kind), "", health_kind)`. With all-zero armour the result equals old damage exactly (`max(1, x*100/100)`), so goldens shift only where damage < 1 (none at current numbers).
3. `role_mult`/perk `damage_taken` move into the `def` resum (same product, same order → same floats).
4. Items on the ground: gear instances are NOT item stacks. `ItemSystem` stores a stack `gear` count 1 with `carry_quality = str(instance_id)` (existing quality string field, no schema change); `EquipmentSystem.instances` owns the objects. Save/replay: instances are recreated from commands (`give_gear`, `equip`) + rng, no new save format.
5. `state_hash` includes equipment only when any instance exists (same rule as squads) → all goldens byte-identical.

## 7. Worker breakdown (wave 1, tonight ≈ 2.5 h, 4 Sonnet workers, disjoint files)
Merge order E1 → E2 → E3 → E4. Shared files only in `# region E<n>`. Reports `docs/agents/<agent>/E-report.md`.
**E1 stat core + resolver** — owns `sim/equipment/stat_block.gd` (KEYS/IDX, `sum_into(packed, dict)`), `sim/combat/combat_system.gd` (region E1: `resolve_hit`, hit_chance `+acc`), `sim/combat/combat_state.gd` (region E1: `att`, `def`, `resum_tick`), `sim/threats/enemy.gd` (region E1: `att/def` from def + `armor`/`flat` keys), `sim/threats/threat_system.gd` (region E1: two attack lines), `sim/health/health_system.gd` (region E1: role/perk mults sourced from cached def), `data/enemies.json` (`armor`, `flat` keys = 0), `tools/combat_model.gd` (static `resolve` using same formula), `tests/test_damage_formula.gd`.
Accept: table test (raw 20, armor 100 → 10; armor 200 → 6.67; flat 3 then armor 100 → 8.5; pen 0.5 vs armor 100 → 13.3; min 1); enemy with armor 0 → old numbers; all goldens unchanged; `combat_model` section 1 TTK equals the old values for shiv/rifle.
**E2 equipment module** — owns `sim/equipment/equipment_system.gd`, `sim/equipment/gear_item.gd`, `data/equipment.json`, `data/gear.json` (migrated shiv/rifle + 4 new bases: kevlar_vest, helmet, plasma_blade, smg), `data/upgrades.json`, `sim/core/simulation.gd` (region E2: `give_gear(cid, base, rarity, ilvl)`, `equip(cid, item_id)`, `unequip(cid, slot)`, `socket(item_id, upgrade_id)`, `state_hash` part), `sim/colonists/colonist_system.gd` (region E2: start gear), `docs/sim_contract.md` rows, `tests/test_equipment.gd`.
Accept: equip into wrong slot rejected; equip replaces and resums `att/def` exactly once (resum_count); 2 vests' armour sums; durability 0 keeps the item, halves its contribution; unknown slot id in JSON = new slot works without code change (test adds a "back" slot via `defs` override); same commands twice = same `state_hash`; goldens unchanged.
**E3 affixes + rarity** — owns `sim/equipment/affix_roller.gd`, `data/affixes.json` (≥ 12 affixes across the 3 groups), `sim/equipment/gear_item.gd` (region E3: `stats` resum from affixes), `tools/affix_report.gd` (1000 rolls per rarity: group distribution, duplicates), `tests/test_affixes.gd`.
Accept: rarity n affixes exactly; never >2 prefix/>2 suffix/`max_per_group`; no duplicate affix id; tags respected (no `dmg_pct` on a vest); same seed → same item; report shows offense/defense split on legendary within 40–60% over 1000 rolls; tier obeys ilvl brackets.
**E4 bench + ranged params + UI stub** — owns `tools/equip_bench.gd`, `tests/test_equip_perf.gd`, `tests/perf_budget.json` (`combat` entry), `sim/combat/combat_system.gd` (region E4: burst/magazine/reload for ranged bases; melee crit), `view/panels/gear_panel.gd` (read-only list of 6 slots + stats on the inmate card, ≥ 64 px rows, no drag), `view/hud.gd` (region E4), `tests/test_gear_panel.gd`.
Accept: perf test from section 5 passes at budget; SMG burst = 3 shots `gap_ticks` apart then `cooldown`; magazine empty → `reload_ticks` pause (ammo pouch rule unchanged); crit uses exactly one `sim.rng.randf()` per hit (rng call count test); panel shows slot names from `equipment.json`, HUD rect scan at 844×390 no overlap.
Out of scope wave 1: loot drops, crafting gear, repair, dodge affix, enemy affixes, trade value, skill-branch effects. Wave 2 candidates: loot from creatures (rarity by contamination level — the prison-planet twist: tainted gear has stronger offence affixes and a contamination puff on crit), gear crafting at the workbench with `quality.json` → ilvl.
