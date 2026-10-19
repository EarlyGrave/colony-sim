# Design: threats, pacing and player agency (Fable lead, 2026-10-19)

Scope: creature waves, raids, remote miners, storyteller. Pillar: mining safe, refining dangerous
(`kx_pillar_table` baseline vs throttle gap >= 2 waves by d21; today 6.2 vs 4.0).

## 1. Diagnosis (from code + SR/OS reports, bot 60 d)
- Waves are **attrition, not decisions**: cadence = pollution clock + audit patrols + nest hunger bank
  (`pacing`, `ecology.json`), all invisible to the player except the 200-tick warning. Refining is a
  slider the player sets once; nothing says "refine NOW, stop at X".
- Raids are **binary and global**: `start_wave()` calls `set_alarm(true)` for the whole colony; every
  inmate runs to the nearest shelter, remote miners cross the map through the raid (deaths "reaching"
  rock-bound miners, burrower bias `miner 1.5`) and the shelter ration only patches starvation (s9).
- A raid has **no goal**: it ends on timeout/retreat_fraction. The player cannot buy it off, lure it,
  or trade stock for lives, so the only lever is turret count (a wealth race).
- Storyteller events are unrelated to the threat state; they break a link while a wave may be coming.
- Pillar risk: anything that makes refining safer *in general* shrinks the gap. All ideas below make
  the risk *legible and timed*, never smaller on average.

## 2. Mechanics (our twist, hooks, cost)
A. **Raid objectives** (M) — every raid picks a goal from `data/raids.json` `objective`: `gorge`
   (eat N waste/essence_ore from the ground or a stockpile, then leave), `wreck` (break the highest-
   threat building, then leave), `nest` (burrower: dig into a miner cell, disabling it until cleared),
   `hunt` (classic). Goal met => `retreating=true` early. The player chooses: defend, or let them
   gorge on the waste pile (lose stock, keep inmates), or lure the `wreck` target with a decoy.
   Hooks: `ThreatSystem.raid_objective: Dictionary`, `_check_objective()` beside `_check_morale()`,
   bus `raid_objective_met(raid_id, kind)`, `Ledger "raid_lost:<item>"`. Warning text names the goal.
B. **Scent clock + dormancy window** (M) — refining adds `scent` (balance `scent.per_refine`,
   decays `scent.decay_per_day`); the pollution-wave countdown is scaled by scent (`1/(1+scent/s0)`),
   so a refining *burst* pulls the wave in visibly within a day. After a **repelled** wave nests sleep
   `dormant_days` (clean 3 / polluted 1, scaled by pollution frac): no pollution wave can start, audits
   still can. Hud ticker: "Nests dormant: 1.4 d" / "Scent high: wave in ~0.6 d". Decision: refine hard
   in the window, stop before it closes. Pillar guard: dormancy is shorter the dirtier the planet, and
   `per_refine` scent is applied *on top of* pollution, so baseline (refines always) gets >= today's
   wave count. Hooks: `ThreatSystem` region SC (`_k1_pollution_mult()` factor, `dormant_until`),
   `sim.bus.item_refined` listener, `balance.json "scent"`.
C. **District lockdown instead of global alarm** (M) — alarm has a **radius** around the raid's spawn
   origin / objective (`threat.lockdown_radius`, default 24 cells): inmates inside flee to a shelter;
   inmates outside keep working unless an enemy comes within `colonist_aggro_range`. Player override
   stays: `set_alarm(true)` = everyone hides (today's behaviour), `set_alarm(false)` releases.
   Hooks: `JobSystem` flee region (line 35 `if sim.alarm ...` becomes `sim.threats.in_lockdown(cell)`),
   `Simulation.alarm` keeps meaning "manual all-hands". Deterministic: pure distance checks.
D. **Mine hut** (S) — 1x1 `mine_hut` building (`shelter: true`, 2 occupants, 120 hp, cost 4 plate),
   placed next to remote miners; `find_shelter()` already picks the nearest shelter, so miners hide
   locally instead of crossing the map. Burrower `nest` objective targets the hut's miner => the player
   must come out and fight for remote ore (decision: fortify remote spur or accept idle miner).
E. **Storyteller reads the threat state** (S) — `events.json` gains `requires: {dormant|scent_high|
   wave_pending}` and two events: `scout_sighting` (reveals next raid objective + origin a day early;
   only while `wave_pending`), `molt` (nests dormant +1 d but next raid gets the mutant band; a choice
   event: accept/ignore). Harmful events are suppressed while `wave_pending` (`quiet_before_wave_ticks`
   already exists; extend it to dormancy end). Hook: `Storyteller._eligible()`.
F. (later, L) Essence hoard clock from scout/pacing.md — not this wave.

## 2b. Second track: Metropolis raids (owner notes 2026-10-19; cost L, after this wave)
Lore: creatures are poisoned former people/animals; refining *tempo* raises their hostility — the
scent clock (B) is exactly that and gets the lore text ("the ones who were here before smell it").
The Metropolis (orbital Collector sending drone shuttles) is a separate **tech track**, keyed not by
pollution but by *defiance*: essence kept from the shuttle quota, refused audits, petition stage.
- `data/raids.json` gains `faction: "creature"|"metropolis"`; metropolis raids (`drone_sweep`,
  `collector_drop`, `siege_platform`) use energy weapons/armor from `docs/design/combat_items.md`
  (combat lead owns the math; we only reference `damage_kind: "energy"`). They `spawn: "drop"` near
  the HQ/refinery, ignore nests/dormancy, and have objective `seize` (carry off refined essence) or
  `wreck` (shuttle pad / turrets).
- Clock: `defiance` (balance `metro.defiance`): +per day the quota is unmet, +per declined audit,
  decays when essence is shipped. Metropolis wave points = `metro.base + metro.per_defiance *
  defiance`; interval `metro.interval_days` independent of pollution => a clean, defiant colony is still
  raided (tech track), a polluted, obedient one is hit by creatures (pillar track). The two never
  stack on one day: a metro raid defers the pollution timer by `metro.grace_days` (and vice versa).
- Endings interaction: **Submit** — shipping essence keeps defiance ~0; endgame = creature siege
  waves (existing `siege` crisis, scent at max: "madness peaks"). **Fight** — ignore the shuttle:
  defiance climbs, metro raids escalate to the final Collector assault (scripted raid like
  `tutorial_audit`, win = destroy the dropped `collector_relay` building); creatures meanwhile go
  dormant longer because the colony refines less. **Escape** — selling to outsiders raises defiance
  slowly (`metro.suspicion_per_sale`), so the grey ending races metro raids, not creatures.
- Acceptance (bot): `factory_eval` real bot (Submit path) sees 0 metro raids by d60; a `--ov` with
  quota refused sees >= 2 metro raids by d60 and still alive>=8 on >= 7/10; pillar gap unchanged
  (metro track must not touch `kx_pillar_table` profiles, which refine and ship).
- Hooks: `sim/threats/metro_track.gd` (new, ticks from ThreatSystem), `data/metro.json`,
  `balance.json "metro"`, bus `metro_raid_started`. Worker-ready once combat_items.md lands energy
  weapons; until then a `metro.enabled=false` skeleton (data + clock + tests) is an S task.

## 3. Bot-measurable acceptance (run before merge; numbers from tools, not by eye)
- `tools/kx_pillar_table.gd --days=21 --seeds=5`: baseline - throttle >= 2.0 waves; baseline >= 6.
- `tools/factory_eval.sh --days=60`: alive>=8 >= 9/10, audit >= 7, P1 >= 4, P3 >= 3, launch >= 1
  (not worse than today's 9/8/5/3/1).
- New column in `factory_eval_summary.py`: `flee_deaths` (ledger `died:flee`, inmate killed while in
  a flee job > 12 cells from shelter) must be 0/10; `hidden_starve` (ledger `starve:hidden`) 0/10.
- `tools/balance_report.gd` (extended): per seed `objective_met=%d repelled=%d`; with 0 turrets
  objective raids end early on >= 50% of waves (colony loses stock, not lives: died_on_wave >= 4).
- `tools/combat_model.gd` unchanged (no enemy stats touched). Goldens regenerate once (B changes tick
  order of waves); the regen diff must list only wave ticks.

## 4. Worker breakdown (one wave, 4 workers, disjoint files; shared files only in `# region`)
W1 **Raid objectives** (A) — owns `sim/threats/raid_objective.gd` (new RefCounted), `data/raids.json`,
   `threat_system.gd` region RO, `event_bus.gd` region RO, `tests/test_raid_objectives.gd`.
   Accept: each raid type has an objective; `gorge` consumes items via `ItemSystem` and ends the wave
   (test: 20 waste on ground, 0 turrets => wave ends with 0 inmate damage); `wreck` ends on the
   building_broken of its target; `hunt` unchanged (test_raids/test_waves green, goldens unchanged for
   hunt-only seeds: objective roll uses `wave_rng` *after* composition).
W2 **Scent + dormancy + ticker** (B) — owns `threat_system.gd` region SC, `balance.json "scent"`,
   `view/hud` ticker region SC, `tests/test_scent_pacing.gd`, `kx_pillar_table` run in report.
   Accept: 10 refines in one day pull next_wave_tick forward >= 30%; after a repelled wave no pollution
   wave starts for `dormant_days`; audit patrol still fires inside dormancy; pillar gap >= 2 (report).
W3 **District lockdown + mine hut** (C, D) — owns `job_system.gd` flee region LD, `threat_system.gd`
   `in_lockdown()` region LD (one function), `data/buildings.json` `mine_hut`, `data/threat.json`
   `lockdown_radius`, `tests/test_lockdown.gd`. Accept: inmate 40 cells from spawn keeps mining
   during a wave; manual alarm still hides all; a miner with a mine_hut 2 cells away hides there
   (flee path <= 3); ledger `died:flee` added in `HealthSystem` region LD (death cause while fleeing).
W4 **Storyteller hooks + tools** (E, §3) — owns `data/events.json` (new ids + `requires`),
   `storyteller.gd` region TS, `tools/balance_report.gd`, `tools/factory_eval_summary.py` columns,
   `tests/test_storyteller.gd` additions. Accept: `scout_sighting` never fires without a pending wave;
   harmful events never fire inside `warning_ticks`; summary prints `flee_deaths hidden_starve objmet`.
Merge order: W4 (tools first, so W1-W3 reports use them) -> W3 -> W1 -> W2 (goldens regen once, at
the end). DECISIONS entry: "waves have objectives; lockdown is local; dormancy after repelled waves
(decided without owner, review)". Reversible: `raids.json objective: "hunt"`, `lockdown_radius: 0`,
`scent.enabled=false` restore today's behaviour.

## 5. Why this is tension, not attrition
Every wave now asks a question with a visible answer: *what do they want* (A), *when does the window
close* (B), *who stays at work* (C/D), *what did the scout see* (E). The colony can lose stock, time or
a remote miner instead of inmates; the only way to lose inmates is to choose to fight for something.
