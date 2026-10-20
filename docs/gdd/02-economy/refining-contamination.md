# Refining, waste and contamination (pillar 1)

## Contamination `[BUILT]` — `sim/contamination/contamination_system.gd`, `data/balance.json contamination`
- Global level 0..100: +`per_batch` 0.7 per polluting batch (x tech `waste_mult`, x preset `waste_mult`
  0.45/1.0/1.15), +`per_waste_per_day` 0.02 per waste unit on the ground (dump zone emits less:
  `zones.json waste_emission_factor`), idle decay 0.25/day below 90 % (x8 with the Taint cap rule, B2).
- Planet death at 100 (`planet_dead`). Forecast (`ForecastModel`) shows days-to-end with an error bar once
  the first refine happens (`forecast_revealed`); the HUD ticker is the pillar's gauge.
- Only recipes flagged `pollutes` add contamination (owner rule 2026-10-19; `refine_essence`, `fuel_cell_dirty`).
  Smelting/plates/parts are clean and uncapped.

## Spatial field (mutation) `[BUILT]` — `sim/mutation/mutation_system.gd`, `data/mutation.json`
Per-cell contamination (diffusion 0.12, sources per waste/batch); tainted >= 0.35, mutated >= 0.8.
Effects: crop growth/yield penalties, colonist exposure illness (`toxic_fallout`), enemy hp/damage bonus on
mutated ground, `essence_bloom` drops. Player counters: `purify_cell` command (2 refined, r 1) and the
cleanup idle job (`scrub_job`, `data/idle_work.json cleanup`). Dump zone is tinted in the view (F7).

## Waste sinks `[BUILT]`
`waste_dump` zone (lower emission), `waste_compactor` (1x1, 10 ore, 6 waste/day, +0.01 pollution/unit;
flag `waste_sink_early` ON), penance beacons burn waste (`ash_beacon`). Design intent (owner): the dilemma
is *when* and *how much* to refine, never "a machine that makes refining clean".

## Player rules `[BUILT]` — `data/rules.json`, `Simulation.set_rule`
`refine_cap` (no new polluting batches above X %), `ore_reserve` (refinery never drains below 20),
`auto_throttle_above`, `raid_engineer`, `repair_priority` (modes), `turret_target_mode` (modes),
`militia_rally`, `evacuate_low_hq`, `expeditions`. Shown as HUD toggles; meta unlocks can pre-enable some.

## How refining drives threat (summary; detail in [05-threats-combat/](../05-threats-combat/README.md))
- Wave points: `per_refined` 0.02 x refined total, `per_contamination` 0.07, `per_wave` 0.7, preset mult.
- Wave cadence: pollution clock (`pacing.pollution_interval` lo 0.45 / hi 0.7, clean x10 slower, dirty x0.28),
  audit patrols every 8/6/4.2 d by preset (floor a clean colony still meets), nest hunger banks fed by
  local pollution (`data/ecology.json`), scent (per refine, decays) + dormancy after a repelled wave.
- Pillar check today: standard_term d21 baseline ~6.2 waves vs throttle/mining ~4.0 (gap 2.2 >= 2).

## Contradictions found
- `docs/design/economy_endgame.md` and `GDD.md §5` describe "refined/batch 3"; the data is 6.
- `pacing.pollution_interval.dirty_mult` is 0.28 (BL pass), old docs say 0.35.
- `docs/story/revelation.md §2` wants the first wave from the dump side: needs per-area pollution; the flag
  `threat.spawn_at_pollution_peak` exists but is OFF (uses the mutation field's max cell).
