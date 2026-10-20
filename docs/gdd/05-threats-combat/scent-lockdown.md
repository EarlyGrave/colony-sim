# Scent clock, dormancy, lockdown, raid objectives

Design intent (threats_pacing.md): every wave asks a question with a visible answer — *what do they want*,
*when does the window close*, *who stays at work*, *what did the scout see*. Nothing here may make refining
safer on average; it makes the risk legible and timed.

## Scent clock + dormancy window `[BUILT]` — `threat_system.gd` region SC, `balance.json scent` (enabled **true**)
- Each refine adds `per_refine` 0.15 scent; decays 1.5/day. Pollution-wave countdown is multiplied by
  `1/(1 + scent/s0)` (s0 3.0): a refining *burst* pulls the wave in within a day.
- After a **repelled** wave nests sleep `dormant_clean_days` 2.0 .. `dormant_polluted_days` 0.25 (lerp by
  contamination fraction): no pollution wave can start; audit patrols still can. Molt event extends it.
- HUD ticker: "Nests dormant: 1.4 d" / "Scent high: wave in ~0.6 d" (`scent_ticker()`); no HUD surface
  beyond the ticker yet (A10). Decision: refine hard in the window, stop before it closes.
- Old docs say scent shipped OFF after the night sprint; **data now has `scent.enabled: true`** (F2 era).

## District lockdown `[BUILT]` — `threat_system.gd in_lockdown()`, `job_system.gd` flee region LD, `data/threat.json lockdown_radius` 36
Alarm has a radius around the raid origin/objective: inmates inside flee to a shelter; outside they keep
working unless an enemy is within `colonist_aggro_range`. Manual `set_alarm(true)` still hides everyone.
Radius 24 (design) broke wave balance -> 36 (owner question 12). Ledger `died:flee` for deaths while fleeing
far from shelter; `factory_eval_summary.py` columns `flee_deaths`, `hidden_starve`.

## Mine hut `[BUILT]` — `data/buildings.json mine_hut`
1x1 shelter for 2, placed by remote miners; `find_shelter()` picks the nearest, so miners hide locally.

## Raid objectives `[BUILT, flag OFF: balance.threat.raid_objectives]` — `sim/threats/raid_objective.gd`, `data/raids.json objective`
`gorge` (eat N waste/ore from the ground or stockpiles, then leave), `wreck` (break the top-threat
building, then leave), `hunt` (classic). `nest` (burrower digs into a miner) `[PLANNED]`, not built. Warning
text names the goal; `scout_sighting` reveals it a day early; bus `raid_objective_met`, ledger
`raid_lost:<item>`. OFF because ON dropped alive>=8 from 7/10 to 5/10 (F1c). Owner question 14.

## Storyteller hooks `[BUILT]` — `events.json requires`, `storyteller.gd` region TS
`scout_sighting` only while a wave is pending; `molt` (dormancy +1 d, next raid mutant band; accept/ignore);
harmful events never fire inside the warning window or dormancy end.

## Fog / creature haze `[IDEA, backlog]`
See [99-backlog/ideas.md](../99-backlog/ideas.md): sensors + scent ghosts, pollution shrinks sight. Owner put
it in the backlog (2026-10-20). No `sim/fog` exists.

## Pillar guard
Dormancy is shorter the dirtier the planet, scent is applied on top of pollution, so a colony that always
refines gets >= today's wave count. `kx_pillar_table` must stay >= 2.0 after any change here.
