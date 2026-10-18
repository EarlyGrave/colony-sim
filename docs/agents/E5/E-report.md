# E5 report (threats bench + hard waves)

## Perf (perf_threat --n=300 --size=250, best-of-6 steady avg, machine load 7-10 on 4 cores)
| | steady ms |
|---|---|
| before | 2.14 (runs 2.14-2.48) |
| after  | 2.08 (runs 2.08-2.33) |
Changes (no behavior change, goldens untouched): `ThreatSystem.tick` walks `enemies` by index instead of `enemies.duplicate()`
(only `_tick_leaving` erases; order identical); `FlowField.next_step_from(c, cur, walk)` avoids a second `dist_at` in `Enemy.move_flow`.
Target <=2.0 NOT clearly reached under load (gain ~3-5%); remaining cost is per-enemy flow_cached LRU touch + move_flow.
Skipping the touch would alter flow eviction order (golden risk), so not done. Re-measure on a quiet machine.

## Hard preset (b1_preset_table --days=21, 5 seeds)
Lever: `hard_time.audit_interval_days` 5 -> 4.2 (calm_after_hit / wave_interval_mult had zero effect: waves are audit-driven).
| preset | before | after |
|---|---|---|
| short_stay | 4.8 | 4.8 |
| standard_term | 6.6 | 6.6 |
| hard_time | 7.2 | 7.8 (4.0 gives 7.4, non-monotonic) |

## Pillar (kx_pillar_table d21, 5 seeds)
| preset | baseline | throttle | mining |
|---|---|---|---|
| standard_term | 6.6 | 4.2 (gap 2.4 OK) | 4.0 |
| hard_time | 7.8 | 6.2 (gap 1.6) | 6.0 |
Hard deaths 0 at d21.

## Tests
Sharded suite: 718 passed, 0 failed. Goldens needed NO regen (hard_time not covered; perf change identical).
