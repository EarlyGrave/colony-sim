# D4 report: factory_eval harness
- `tools/factory_eval.sh [--seeds=1-10] [--days=60] [--preset=standard] [--jobs=N] [--timeout=280] [--ov=JSON] [--nitrogen=1 --cap= --plate=]`
  one godot process per seed, N parallel (default nproc=4), mktemp -d + trap cleanup, kills only own PIDs, ordered table + PASS/FAIL vs acceptance.
- `tools/factory_eval_summary.py` (table), `--json` flag in factory_bot_report.gd (`json_line`, region D4), `waste_prod` added to play() result (region D4 in factory_bot.gd).
- `--preset` is accepted but ignored (bot has only standard). Wall time 10 seeds x 60 d: 4m03s with 4 jobs (timeout 280 s per seed).
- Test: tests/test_factory_eval.gd (smoke). Suite: 778 passed, 0 failed.

Baseline (branch 64795e7, real factory_bot, 60 d):
| seed | end | alive | pol% | debt% | refined | plates | waste |
|---|---|---|---|---|---|---|---|
| 1 | colonists_dead | 0 | 74 | 69 | 420 | 0 | 220 |
| 2 | planet_dead | 6 | 100 | 64 | 402 | 3 | 212 |
| 3 | colonists_dead | 0 | 93 | 64 | 420 | 2 | 221 |
| 4 | colonists_dead | 0 | 86 | 34 | 378 | 3 | 192 |
| 5 | hq_destroyed | 6 | 56 | 55 | 334 | 8 | 216 |
| 6 | colonists_dead | 0 | 51 | 69 | 438 | 1 | 234 |
| 7 | ok | 5 | 67 | 35 | 426 | 0 | 230 |
| 8 | colonists_dead | 0 | 66 | 33 | 396 | 8 | 204 |
| 9 | ok | 4 | 61 | 26 | 318 | 1 | 152 |
| 10 | planet_dead | 7 | 100 | 51 | 390 | 0 | 207 |

Audit2 0/10, P1 0/10, P3 0/10, launch 0/10 (all FAIL).
