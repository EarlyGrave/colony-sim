# 10 — Tech

| file | content |
|---|---|
| [architecture.md](architecture.md) | hard rules (sim/view split, fixed tick, determinism, data-driven), systems map, commands, links to the full docs |
| [tools-measurement.md](tools-measurement.md) | the bot/eval/model/bench tools and the ship checks every merge must pass |
| [history.md](history.md) | every batch plan and merge to main, one line each (docs/*_plan.md are history, not design) |

Full references (not duplicated here):
- [docs/ARCHITECTURE.md](../../ARCHITECTURE.md) — E9 audit of the early code (still the best map of core systems).
- [docs/sim_contract.md](../../sim_contract.md) — portable spec: tick order, RNG rules, every recorded command,
  data files, save format; kept in sync with code by `tests/test_contract_doc.gd` (<= 250 lines).
- [docs/contracts/](../../contracts/README.md) — E9 design contracts per domain (+ RECONCILIATION rulings D25).
- [docs/optimization_strategy.md](../../optimization_strategy.md), [docs/power_api.md](../../power_api.md), [docs/engine_choice.md](../../engine_choice.md).
- Process: `CLAUDE.md` (orchestrator / prompter / workers / scout / story writer, test cadence, ship checks),
  [docs/HANDOFF.md](../../HANDOFF.md), [docs/rollback_points.md](../../rollback_points.md).
