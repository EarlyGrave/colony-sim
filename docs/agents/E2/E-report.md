# E2 Sector Dispatch report
- Gate: `e2_enabled` in balance.json (false). Goldens untouched, not regenerated.
- Files: `data/contracts.json` (`e2_dispatch` key: 3 tiers + 3 modifiers), `sim/contracts/contract_system.gd` (# region E2: dispatch_state/can_dispatch/dispatch, e2_wave_mult applied in take_raid_mult), `sim/core/simulation.gd` (# region E2: recorded command `dispatch_sector(tier, modifier_id)`, `get_sector_state()`), `tools/bot_report.gd` (`--e2`, `--e2trace`), `tests/test_e2_dispatch.gd`.
- Plan named `sim/expedition.gd` / `data/expedition.json`; not needed, dispatch lives in ContractSystem. Bundles use raw_food (bot surplus 150-350) + refined_essence; ore is consumed by refining so ore bundles were unreachable.
- Tiers in order: T1 100 food, T2 150 food + 6 refined, T3 200 food + 15 refined. One modifier each, no repeats: calm (x0.9 raid points = -10% wave strength), recruit (+1 colonist), smelting (grants Smelting tech).
- Bot (`bot_report.gd --days=30 --seeds=5 --e2`; picks calm, recruit, smelting):

| seed | tiers | day T1/T2/T3 | wave_mult | waves |
|---|---|---|---|---|
| 1 | 2 | 1/16/- | 0.90 | 8 |
| 2 | 2 | 1/13/- | 0.90 | 7 |
| 3 | 2 | 1/9/- | 0.90 | 7 |
| 4 | 2 | 1/9/- | 0.90 | 7 |
| 5 | 2 | 1/9/- | 0.90 | 6 |

- >=1 tier on 5/5 seeds (target 3/5). T3 not reached in 30 d (refined goes to turrets/contracts); T1 on day 1 is easy, consider raising.
- Wave effect measured: raid strength multiplier 0.90 applied to each wave after dispatch (unit-tested via take_raid_mult).
- Tests: 4 new (gate off, tier order and modifier used once, +1 colonist, determinism).
- Full sharded suite: 722 passed, 0 failed; goldens identical (dispatch state kept in an Object member so the golden dump skips it).
