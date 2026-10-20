# Tools and ship checks

## Ship checks before every merge to `main` (CLAUDE.md 6-9; owner bar 2026-10-20)
1. `tools/run_tests_quick.sh` after each worker merge; full `tools/run_tests_sharded.sh 4` before main.
2. `PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers python3 tools/web_smoke.py` PASS (real web build, phone size).
3. Bot sanity: `tools/factory_eval.sh` 10 seeds / 60 d -> alive>=8 >= 6/10, no mass deaths; new content
   (map / biome / creature / machine) merges only with bot numbers.
4. Balance tuned from a model/table, never by eye. Goldens regenerated only for an intended sim change.
5. Append `docs/rollback_points.md` (date | main SHA | batch | tests). Never push red (`set -o pipefail`).

## Bots and evaluation
| tool | what it measures |
|---|---|
| `tools/factory_bot.gd` + `factory_eval.sh` + `factory_eval_summary.py` | the real bot (public commands only): alive, audit tier, P1/P3/P4, launch, path, suspicion peak, metro raids, ending/day, gear equipped, flee deaths, hidden starve, objective met; `--ov={"balance":{...}}` overrides; knobs path / sell_every / equip / branch_pick / use_alt / la_hoard_day |
| `tools/kx_pillar_table.gd` | pillar gap: waves by d21 baseline vs throttle vs mining-only, per preset |
| `tools/balance_report.gd`, `qa_r3.gd` | waves per seed, repelled, objective met, days survived |
| `tools/shuttle_bot.gd`, `petition_bot.gd`, `review_bot.gd`, `tutorial_report.gd` | scripted-supply bots for the quota spine and the tutorial |
| `tools/petition_pace.gd`, `la_diag.gd`, `rp_diag.gd`, `rf_diag.gd`, `pl_diag.gd`, `fc_diag.gd` | diagnosis of the launch chain (plates, copper, refinery duty cycle) |
| `tools/contraband_scenario.gd`, `contraband_report.gd`, `block_report.gd`, `ng_chain_report.gd` | society and NG+ numbers |
| `tools/gear_loot_eval.gd`, `gear_budget.gd`, `affix_report.gd`, `equip_bench.gd` | gear sources, gear cost vs quota, affix distribution, combat perf |

## Models (analytic tables)
`tools/combat_model.gd` (DPS/TTK, roles, armour), `debt_model.gd` (payoff curve), `skill_model.gd` (days to
L3/L6/L10 per branch), `power_model.gd`, `b1_preset_table.gd`, `b2_table.gd`, `progression_report.gd`.

## Perf and memory
`tools/perf_bench.gd --late=1` (F10: late-game scenario, table vs `late` budget; test `tests/test_f10_perf_late.gd`), `tools/perf_bench.gd` (+ `perf_scenario`, `perf_threat`, `perf_threat_belts`, `belt_bench`), `mem_probe.gd
--size=250`, `view_bench`, `w2a_bench`; `tests/test_perf_budget.gd` + `tests/perf_budget.json`.

## Visual checks
`tools/screenshot.tscn` under xvfb, `*_shot.tscn` per batch, `tools/gen_art.py` for all sprites/icons.

## Test suite
208 test files, 1186 tests green (sharded ~2 min). Runner fails on any engine/script error. Contract doc test
keeps `docs/sim_contract.md` in sync; golden replays; phone layout overlap scan; text-length tests.

Late-game perf (F10, 250 map, 12 inmates fully geared, drone raid + 70 enemies, desktop shared host): avg 1.15 ms / p95 2.4 ms per tick vs 10 ms contract; threats ~57 %, colonists next; web est. avg 2.3-3.5 / p95 5-7 ms.
